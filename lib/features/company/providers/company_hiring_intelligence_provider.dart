import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/application_model.dart';
import '../../../models/company_model.dart';
import '../../../models/interview_model.dart';
import '../../../models/job_match_model.dart';
import '../../../models/job_model.dart';
import '../../../providers/application_provider.dart';
import '../../../providers/company_provider.dart';
import '../../../providers/firebase_providers.dart';
import '../../../providers/interview_provider.dart';
import '../../../providers/job_matching_provider.dart';
import '../../../providers/job_provider.dart';
import '../../../providers/user_provider.dart';

final companyHiringIntelligenceProvider =
    FutureProvider<CompanyHiringIntelligence>((ref) async {
      final user = await ref.watch(currentUserProvider.future);
      if (user == null) return CompanyHiringIntelligence.empty;

      final jobs = await ref.watch(companyJobsProvider.future);
      final applications = await ref.watch(companyApplicationsProvider.future);
      final interviews = await ref.watch(companyInterviewsProvider.future);
      final company = await ref.watch(companyProvider.future);
      final verificationStatus = await _readVerificationStatus(ref, user.uid);

      final rankingService = ref.watch(jobMatchingServiceProvider);
      final rankedCandidates = <CompanyCandidateSignal>[];
      final applicationsByJob = <String, List<ApplicationModel>>{};
      for (final application in applications) {
        applicationsByJob
            .putIfAbsent(application.jobId, () => <ApplicationModel>[])
            .add(application);
      }

      final rankableJobs =
          jobs
              .where(
                (job) => (applicationsByJob[job.id] ?? const []).isNotEmpty,
              )
              .toList()
            ..sort((a, b) {
              final activeCompare = (b.isActive ? 1 : 0).compareTo(
                a.isActive ? 1 : 0,
              );
              if (activeCompare != 0) return activeCompare;
              return b.updatedAt.compareTo(a.updatedAt);
            });

      for (final job in rankableJobs.take(8)) {
        try {
          final ranked = await rankingService.rankCandidatesForJob(job);
          for (final candidate in ranked.take(8)) {
            rankedCandidates.add(
              CompanyCandidateSignal(
                candidateId: candidate.application.applicantId,
                candidateName: candidate.applicant.fullName.isNotEmpty
                    ? candidate.applicant.fullName
                    : candidate.applicant.email,
                candidateEmail: candidate.applicant.email,
                candidateRole:
                    candidate.applicant.primaryRole ??
                    candidate.application.role,
                jobId: job.id,
                jobTitle: job.title,
                applicationId: candidate.application.id,
                applicationStatus:
                    candidate.application.normalizedPipelineStage,
                match: candidate.match,
              ),
            );
          }
        } catch (_) {
          // Ranking is intelligence-only; one failed job must not break the
          // entire company dashboard.
        }
      }

      rankedCandidates.sort(
        (a, b) => b.match.matchScore.compareTo(a.match.matchScore),
      );

      return CompanyHiringIntelligenceService().build(
        company: company,
        verificationStatus: verificationStatus,
        jobs: jobs,
        applications: applications,
        interviews: interviews,
        rankedCandidates: rankedCandidates,
      );
    });

Future<String> _readVerificationStatus(Ref ref, String companyId) async {
  try {
    final snapshot = await ref
        .read(firestoreProvider)
        .collection('companies')
        .doc(companyId)
        .get()
        .timeout(const Duration(seconds: 5));
    final value = snapshot.data()?['verificationStatus'];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim().toLowerCase();
    }
  } catch (_) {
    // Missing/offline verification data should not fail read-only intelligence.
  }
  return '';
}

class CompanyHiringIntelligenceService {
  CompanyHiringIntelligence build({
    required CompanyModel? company,
    required String verificationStatus,
    required List<JobModel> jobs,
    required List<ApplicationModel> applications,
    required List<InterviewModel> interviews,
    required List<CompanyCandidateSignal> rankedCandidates,
  }) {
    final jobSummary = _jobSummary(jobs, applications, rankedCandidates);
    final applicationSummary = _applicationSummary(applications);
    final candidateIntelligence = _candidateIntelligence(rankedCandidates);
    final interviewSummary = _interviewSummary(interviews, applications);
    final funnel = _funnel(applicationSummary);
    final jobHealth = _jobHealth(
      jobs: jobs,
      applications: applications,
      interviews: interviews,
      rankedCandidates: rankedCandidates,
    );
    final recommendations = _recommendations(
      company: company,
      verificationStatus: verificationStatus,
      jobSummary: jobSummary,
      applicationSummary: applicationSummary,
      candidateIntelligence: candidateIntelligence,
      interviewSummary: interviewSummary,
      jobHealth: jobHealth,
    );

    return CompanyHiringIntelligence(
      jobSummary: jobSummary,
      applicationSummary: applicationSummary,
      candidateIntelligence: candidateIntelligence,
      interviewSummary: interviewSummary,
      funnel: funnel,
      jobHealth: jobHealth,
      recommendations: recommendations,
      verificationStatus: verificationStatus,
    );
  }

  CompanyJobSummary _jobSummary(
    List<JobModel> jobs,
    List<ApplicationModel> applications,
    List<CompanyCandidateSignal> rankedCandidates,
  ) {
    final jobsWithApplicants = applications.map((item) => item.jobId).toSet();
    final highMatchJobs = rankedCandidates
        .where((candidate) => candidate.match.matchScore >= 75)
        .map((candidate) => candidate.jobId)
        .toSet();

    return CompanyJobSummary(
      totalJobs: jobs.length,
      activeJobs: jobs.where((job) => job.isActive).length,
      inactiveJobs: jobs.where((job) => !job.isActive).length,
      jobsWithZeroApplicants: jobs
          .where((job) => !jobsWithApplicants.contains(job.id))
          .length,
      jobsWithApplicants: jobs
          .where((job) => jobsWithApplicants.contains(job.id))
          .length,
      jobsWithHighMatchCandidates: jobs
          .where((job) => highMatchJobs.contains(job.id))
          .length,
    );
  }

  CompanyApplicationSummary _applicationSummary(
    List<ApplicationModel> applications,
  ) {
    int countStatus(String status) {
      return applications
          .where((item) => item.normalizedStatus == status)
          .length;
    }

    int countStage(String stage) {
      return applications
          .where((item) => item.normalizedPipelineStage == stage)
          .length;
    }

    return CompanyApplicationSummary(
      totalApplications: applications.length,
      applied: countStage('applied'),
      screening: countStage('screening'),
      shortlisted: countStage('shortlisted'),
      interviewScheduled: countStatus('interview_scheduled'),
      interviewCompleted: countStatus('interview_completed'),
      interview: countStage('interview'),
      offer: countStage('offer'),
      selected: countStatus('selected'),
      hired: countStage('hired'),
      rejected: countStage('rejected'),
      onHold: countStatus('on_hold'),
      talentPool: countStage('talentPool'),
      withdrawn: countStatus('withdrawn'),
    );
  }

  CompanyCandidateIntelligence _candidateIntelligence(
    List<CompanyCandidateSignal> rankedCandidates,
  ) {
    final uniqueCandidates = <String, CompanyCandidateSignal>{};
    for (final candidate in rankedCandidates) {
      final current = uniqueCandidates[candidate.candidateId];
      if (current == null ||
          candidate.match.matchScore > current.match.matchScore) {
        uniqueCandidates[candidate.candidateId] = candidate;
      }
    }

    final candidates = uniqueCandidates.values.toList()
      ..sort((a, b) => b.match.matchScore.compareTo(a.match.matchScore));
    final scores = candidates.map((candidate) => candidate.match.matchScore);

    return CompanyCandidateIntelligence(
      topCandidates: candidates.take(6).toList(),
      averageMatchScore: _average(scores),
      highMatchCandidateCount: candidates
          .where((candidate) => candidate.match.matchScore >= 75)
          .length,
      candidatesNeedingReview: rankedCandidates
          .where(
            (candidate) =>
                normalizePipelineStage(candidate.applicationStatus) ==
                    'applied' ||
                normalizePipelineStage(candidate.applicationStatus) ==
                    'screening',
          )
          .length,
      candidatesWithMissingRequiredSkills: candidates
          .where((candidate) => candidate.match.missingSkills.isNotEmpty)
          .length,
    );
  }

  CompanyInterviewSummary _interviewSummary(
    List<InterviewModel> interviews,
    List<ApplicationModel> applications,
  ) {
    final now = DateTime.now();
    final upcoming = interviews.where((interview) {
      return interview.isScheduled && interview.scheduledAt.isAfter(now);
    }).length;
    final pendingEvaluations = interviews.where((interview) {
      return interview.isScheduled && interview.scheduledAt.isBefore(now);
    }).length;
    final completed = interviews.where((interview) => interview.isCompleted);
    final scores = completed
        .map((interview) => interview.finalScore)
        .where((score) => score > 0);
    final selected = applications
        .where(
          (item) =>
              item.normalizedStatus == 'selected' ||
              item.normalizedPipelineStage == 'hired',
        )
        .length;
    final rejected = applications
        .where((item) => item.normalizedStatus == 'rejected')
        .length;
    final onHold = applications
        .where((item) => item.normalizedStatus == 'on_hold')
        .length;

    return CompanyInterviewSummary(
      upcomingInterviews: upcoming,
      pendingEvaluations: pendingEvaluations,
      completedInterviews: completed.length,
      averageInterviewScore: _average(scores),
      selectedCount: selected,
      rejectedCount: rejected,
      onHoldCount: onHold,
    );
  }

  CompanyHiringFunnel _funnel(CompanyApplicationSummary summary) {
    return CompanyHiringFunnel(
      applied: summary.applied,
      shortlisted: summary.shortlisted,
      interviewScheduled: summary.interview + summary.interviewScheduled,
      interviewCompleted: summary.interviewCompleted,
      selected: summary.hired + summary.selected,
    );
  }

  List<CompanyJobHealth> _jobHealth({
    required List<JobModel> jobs,
    required List<ApplicationModel> applications,
    required List<InterviewModel> interviews,
    required List<CompanyCandidateSignal> rankedCandidates,
  }) {
    final health = <CompanyJobHealth>[];
    for (final job in jobs) {
      final jobApplications = applications
          .where((item) => item.jobId == job.id)
          .toList();
      final jobInterviews = interviews
          .where((item) => item.jobId == job.id)
          .toList();
      final jobCandidates = rankedCandidates
          .where((item) => item.jobId == job.id)
          .toList();
      final topCandidate = jobCandidates.isEmpty ? null : jobCandidates.first;
      final averageMatch = _average(
        jobCandidates.map((candidate) => candidate.match.matchScore),
      );
      final pendingReview = jobApplications
          .where(
            (item) =>
                item.normalizedPipelineStage == 'applied' ||
                item.normalizedPipelineStage == 'screening',
          )
          .length;
      final selected = jobApplications
          .where(
            (item) =>
                item.normalizedStatus == 'selected' ||
                item.normalizedPipelineStage == 'hired',
          )
          .length;
      final score = _jobHealthScore(
        job: job,
        applicantCount: jobApplications.length,
        averageMatch: averageMatch,
        topMatch: topCandidate?.match.matchScore ?? 0,
        pendingReview: pendingReview,
        interviewCount: jobInterviews.length,
        selectedCount: selected,
      );
      health.add(
        CompanyJobHealth(
          jobId: job.id,
          jobTitle: job.title,
          applicantCount: jobApplications.length,
          averageMatchScore: averageMatch,
          topCandidate: topCandidate,
          pendingReviewCount: pendingReview,
          interviewCount: jobInterviews.length,
          selectedCount: selected,
          healthScore: score,
          healthStatus: CompanyJobHealthStatus.fromScore(score),
          reason: _jobHealthReason(
            job: job,
            applicantCount: jobApplications.length,
            averageMatch: averageMatch,
            topMatch: topCandidate?.match.matchScore ?? 0,
            pendingReview: pendingReview,
            interviewCount: jobInterviews.length,
            selectedCount: selected,
          ),
        ),
      );
    }

    health.sort((a, b) => a.healthScore.compareTo(b.healthScore));
    return health;
  }

  double _jobHealthScore({
    required JobModel job,
    required int applicantCount,
    required double averageMatch,
    required double topMatch,
    required int pendingReview,
    required int interviewCount,
    required int selectedCount,
  }) {
    if (!job.isActive) return selectedCount > 0 ? 70 : 45;
    if (applicantCount == 0) return 20;

    final applicantScore = (applicantCount / 10).clamp(0, 1) * 20;
    final matchScore = averageMatch * 0.35;
    final topMatchScore = topMatch * 0.20;
    final interviewScore = (interviewCount / applicantCount).clamp(0, 1) * 15;
    final selectionScore = selectedCount > 0 ? 10 : 0;
    final pendingPenalty = pendingReview > 5
        ? 10
        : pendingReview > 0
        ? 4
        : 0;

    return (applicantScore +
            matchScore +
            topMatchScore +
            interviewScore +
            selectionScore -
            pendingPenalty)
        .clamp(0, 100)
        .toDouble();
  }

  String _jobHealthReason({
    required JobModel job,
    required int applicantCount,
    required double averageMatch,
    required double topMatch,
    required int pendingReview,
    required int interviewCount,
    required int selectedCount,
  }) {
    if (!job.isActive) return 'This role is inactive or closed.';
    if (applicantCount == 0) {
      return 'No applications yet. Review title, requirements, and visibility.';
    }
    if (pendingReview > 0) {
      return '$pendingReview applicants are waiting for review.';
    }
    if (topMatch >= 75) {
      return 'Strong candidate match available for this role.';
    }
    if (averageMatch < 50) {
      return 'Average candidate match is low. Revisit requirements or target roles.';
    }
    if (interviewCount == 0) {
      return 'Applicants exist, but no interview has been scheduled yet.';
    }
    if (selectedCount > 0) return 'This role has selected candidates.';
    return 'Role is progressing through the hiring funnel.';
  }

  List<String> _recommendations({
    required CompanyModel? company,
    required String verificationStatus,
    required CompanyJobSummary jobSummary,
    required CompanyApplicationSummary applicationSummary,
    required CompanyCandidateIntelligence candidateIntelligence,
    required CompanyInterviewSummary interviewSummary,
    required List<CompanyJobHealth> jobHealth,
  }) {
    final recommendations = <String>[];

    if (verificationStatus.isNotEmpty && verificationStatus != 'approved') {
      recommendations.add(
        'Company verification is ${verificationStatus.replaceAll('_', ' ')}. Complete verification to build candidate trust.',
      );
    }
    if ((company?.companyName ?? '').trim().isEmpty) {
      recommendations.add(
        'Complete your company profile before scaling hiring activity.',
      );
    }
    if (applicationSummary.applied > 0) {
      recommendations.add(
        '${applicationSummary.applied} applicants are waiting for initial review.',
      );
    }
    if (interviewSummary.pendingEvaluations > 0) {
      recommendations.add(
        '${interviewSummary.pendingEvaluations} interviews need evaluation.',
      );
    }
    if (jobSummary.jobsWithZeroApplicants > 0) {
      final zeroJob = jobHealth.firstWhere(
        (job) => job.applicantCount == 0,
        orElse: () =>
            jobHealth.isEmpty ? CompanyJobHealth.empty : jobHealth.first,
      );
      final title = zeroJob.jobTitle.isEmpty ? 'A role' : zeroJob.jobTitle;
      recommendations.add(
        '$title has no applicants yet. Improve requirements, skills, or visibility.',
      );
    }
    if (candidateIntelligence.topCandidates.isNotEmpty) {
      final candidate = candidateIntelligence.topCandidates.first;
      recommendations.add(
        '${candidate.candidateName} is a ${candidate.match.matchScore.toStringAsFixed(0)}% match for ${candidate.jobTitle}.',
      );
    }
    if (candidateIntelligence.candidatesWithMissingRequiredSkills > 0) {
      recommendations.add(
        '${candidateIntelligence.candidatesWithMissingRequiredSkills} candidates are missing required skills. Review fit before advancing.',
      );
    }
    if (jobSummary.activeJobs == 0 && jobSummary.totalJobs == 0) {
      recommendations.add('Post your first job to start receiving candidates.');
    }
    if (recommendations.isEmpty) {
      recommendations.add(
        'No urgent hiring signals right now. Keep reviewing applicants and scheduling interviews.',
      );
    }

    final unique = <String>[];
    for (final recommendation in recommendations) {
      if (recommendation.trim().isEmpty || unique.contains(recommendation)) {
        continue;
      }
      unique.add(recommendation);
    }
    return unique.take(8).toList();
  }

  double _average(Iterable<num> values) {
    final list = values.map((value) => value.toDouble()).toList();
    if (list.isEmpty) return 0;
    return (list.reduce((a, b) => a + b) / list.length)
        .clamp(0, 100)
        .toDouble();
  }
}

class CompanyHiringIntelligence {
  const CompanyHiringIntelligence({
    required this.jobSummary,
    required this.applicationSummary,
    required this.candidateIntelligence,
    required this.interviewSummary,
    required this.funnel,
    required this.jobHealth,
    required this.recommendations,
    required this.verificationStatus,
  });

  final CompanyJobSummary jobSummary;
  final CompanyApplicationSummary applicationSummary;
  final CompanyCandidateIntelligence candidateIntelligence;
  final CompanyInterviewSummary interviewSummary;
  final CompanyHiringFunnel funnel;
  final List<CompanyJobHealth> jobHealth;
  final List<String> recommendations;
  final String verificationStatus;

  bool get hasData =>
      jobSummary.totalJobs > 0 || applicationSummary.totalApplications > 0;

  static const empty = CompanyHiringIntelligence(
    jobSummary: CompanyJobSummary.empty,
    applicationSummary: CompanyApplicationSummary.empty,
    candidateIntelligence: CompanyCandidateIntelligence.empty,
    interviewSummary: CompanyInterviewSummary.empty,
    funnel: CompanyHiringFunnel.empty,
    jobHealth: <CompanyJobHealth>[],
    recommendations: <String>[
      'Post your first job to start receiving candidates.',
    ],
    verificationStatus: '',
  );
}

class CompanyJobSummary {
  const CompanyJobSummary({
    required this.totalJobs,
    required this.activeJobs,
    required this.inactiveJobs,
    required this.jobsWithZeroApplicants,
    required this.jobsWithApplicants,
    required this.jobsWithHighMatchCandidates,
  });

  final int totalJobs;
  final int activeJobs;
  final int inactiveJobs;
  final int jobsWithZeroApplicants;
  final int jobsWithApplicants;
  final int jobsWithHighMatchCandidates;

  static const empty = CompanyJobSummary(
    totalJobs: 0,
    activeJobs: 0,
    inactiveJobs: 0,
    jobsWithZeroApplicants: 0,
    jobsWithApplicants: 0,
    jobsWithHighMatchCandidates: 0,
  );
}

class CompanyApplicationSummary {
  const CompanyApplicationSummary({
    required this.totalApplications,
    required this.applied,
    required this.screening,
    required this.shortlisted,
    required this.interviewScheduled,
    required this.interviewCompleted,
    required this.interview,
    required this.offer,
    required this.selected,
    required this.hired,
    required this.rejected,
    required this.onHold,
    required this.talentPool,
    required this.withdrawn,
  });

  final int totalApplications;
  final int applied;
  final int screening;
  final int shortlisted;
  final int interviewScheduled;
  final int interviewCompleted;
  final int interview;
  final int offer;
  final int selected;
  final int hired;
  final int rejected;
  final int onHold;
  final int talentPool;
  final int withdrawn;

  static const empty = CompanyApplicationSummary(
    totalApplications: 0,
    applied: 0,
    screening: 0,
    shortlisted: 0,
    interviewScheduled: 0,
    interviewCompleted: 0,
    interview: 0,
    offer: 0,
    selected: 0,
    hired: 0,
    rejected: 0,
    onHold: 0,
    talentPool: 0,
    withdrawn: 0,
  );
}

class CompanyCandidateIntelligence {
  const CompanyCandidateIntelligence({
    required this.topCandidates,
    required this.averageMatchScore,
    required this.highMatchCandidateCount,
    required this.candidatesNeedingReview,
    required this.candidatesWithMissingRequiredSkills,
  });

  final List<CompanyCandidateSignal> topCandidates;
  final double averageMatchScore;
  final int highMatchCandidateCount;
  final int candidatesNeedingReview;
  final int candidatesWithMissingRequiredSkills;

  static const empty = CompanyCandidateIntelligence(
    topCandidates: <CompanyCandidateSignal>[],
    averageMatchScore: 0,
    highMatchCandidateCount: 0,
    candidatesNeedingReview: 0,
    candidatesWithMissingRequiredSkills: 0,
  );
}

class CompanyCandidateSignal {
  const CompanyCandidateSignal({
    required this.candidateId,
    required this.candidateName,
    required this.candidateEmail,
    required this.candidateRole,
    required this.jobId,
    required this.jobTitle,
    required this.applicationId,
    required this.applicationStatus,
    required this.match,
  });

  final String candidateId;
  final String candidateName;
  final String candidateEmail;
  final String candidateRole;
  final String jobId;
  final String jobTitle;
  final String applicationId;
  final String applicationStatus;
  final JobMatchModel match;
}

class CompanyInterviewSummary {
  const CompanyInterviewSummary({
    required this.upcomingInterviews,
    required this.pendingEvaluations,
    required this.completedInterviews,
    required this.averageInterviewScore,
    required this.selectedCount,
    required this.rejectedCount,
    required this.onHoldCount,
  });

  final int upcomingInterviews;
  final int pendingEvaluations;
  final int completedInterviews;
  final double averageInterviewScore;
  final int selectedCount;
  final int rejectedCount;
  final int onHoldCount;

  static const empty = CompanyInterviewSummary(
    upcomingInterviews: 0,
    pendingEvaluations: 0,
    completedInterviews: 0,
    averageInterviewScore: 0,
    selectedCount: 0,
    rejectedCount: 0,
    onHoldCount: 0,
  );
}

class CompanyHiringFunnel {
  const CompanyHiringFunnel({
    required this.applied,
    required this.shortlisted,
    required this.interviewScheduled,
    required this.interviewCompleted,
    required this.selected,
  });

  final int applied;
  final int shortlisted;
  final int interviewScheduled;
  final int interviewCompleted;
  final int selected;

  double get shortlistRate => _rate(shortlisted, applied);
  double get interviewRate => _rate(interviewScheduled, shortlisted);
  double get completionRate => _rate(interviewCompleted, interviewScheduled);
  double get selectionRate => _rate(selected, interviewCompleted);

  static double _rate(int value, int base) {
    if (base <= 0) return 0;
    return (value / base * 100).clamp(0, 100).toDouble();
  }

  static const empty = CompanyHiringFunnel(
    applied: 0,
    shortlisted: 0,
    interviewScheduled: 0,
    interviewCompleted: 0,
    selected: 0,
  );
}

class CompanyJobHealth {
  const CompanyJobHealth({
    required this.jobId,
    required this.jobTitle,
    required this.applicantCount,
    required this.averageMatchScore,
    required this.topCandidate,
    required this.pendingReviewCount,
    required this.interviewCount,
    required this.selectedCount,
    required this.healthScore,
    required this.healthStatus,
    required this.reason,
  });

  final String jobId;
  final String jobTitle;
  final int applicantCount;
  final double averageMatchScore;
  final CompanyCandidateSignal? topCandidate;
  final int pendingReviewCount;
  final int interviewCount;
  final int selectedCount;
  final double healthScore;
  final String healthStatus;
  final String reason;

  static const empty = CompanyJobHealth(
    jobId: '',
    jobTitle: '',
    applicantCount: 0,
    averageMatchScore: 0,
    topCandidate: null,
    pendingReviewCount: 0,
    interviewCount: 0,
    selectedCount: 0,
    healthScore: 0,
    healthStatus: CompanyJobHealthStatus.critical,
    reason: '',
  );
}

class CompanyJobHealthStatus {
  const CompanyJobHealthStatus._();

  static const String excellent = 'Excellent';
  static const String healthy = 'Healthy';
  static const String needsAttention = 'Needs Attention';
  static const String critical = 'Critical';

  static String fromScore(double score) {
    if (score >= 85) return excellent;
    if (score >= 65) return healthy;
    if (score >= 40) return needsAttention;
    return critical;
  }
}
