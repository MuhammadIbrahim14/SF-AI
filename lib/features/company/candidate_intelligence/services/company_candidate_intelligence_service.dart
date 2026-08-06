import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../../repositories/application_repository.dart';
import '../../../../repositories/job_repository.dart';
import '../../../../repositories/user_repository.dart';
import '../../../copilot/models/copilot_ai_request_model.dart';
import '../../../copilot/services/ai_gateway_client.dart';
import '../../../courses/data/models/certificate_model.dart';
import '../../../courses/data/repositories/certificate_repository.dart';
import '../../../interview_lab/data/interview_lab_repository.dart';
import '../../../interview_lab/models/interview_lab_models.dart';
import '../../ai_hiring/models/company_ai_hiring_models.dart';
import '../../ai_hiring/services/company_ai_hiring_service.dart';
import '../models/company_candidate_intelligence_models.dart';

/// Bridges Interview Lab + profile evidence into company ATS views.
/// Never mutates Lab reports/scores.
class CompanyCandidateIntelligenceService {
  CompanyCandidateIntelligenceService({
    required FirebaseFirestore firestore,
    required UserRepository userRepository,
    required ApplicationRepository applicationRepository,
    required JobRepository jobRepository,
    required InterviewLabRepository interviewLabRepository,
    required CertificateRepository certificateRepository,
    CompanyAiHiringService? aiHiringService,
    AiGatewayClient? gatewayClient,
    FirebaseAuth? auth,
  })  : _firestore = firestore,
        _users = userRepository,
        _applications = applicationRepository,
        _jobs = jobRepository,
        _lab = interviewLabRepository,
        _certificates = certificateRepository,
        _aiHiring = aiHiringService ?? CompanyAiHiringService(),
        _gateway = gatewayClient ?? AiGatewayClient(),
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final UserRepository _users;
  final ApplicationRepository _applications;
  final JobRepository _jobs;
  final InterviewLabRepository _lab;
  final CertificateRepository _certificates;
  final CompanyAiHiringService _aiHiring;
  final AiGatewayClient _gateway;
  final FirebaseAuth _auth;

  static String accessDocId(String companyId, String candidateId) =>
      '${companyId}_$candidateId';

  /// Ensures company can read Lab docs for this applicant (permission bridge).
  Future<void> ensureHiringAccess({
    required String companyId,
    required String candidateId,
    required String applicationId,
    required String jobId,
  }) async {
    final id = accessDocId(companyId, candidateId);
    await _firestore.collection('hiring_candidate_access').doc(id).set({
      'accessId': id,
      'companyId': companyId,
      'candidateId': candidateId,
      'applicationId': applicationId,
      'jobId': jobId,
      'module': 'company_hiring',
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<CompanyCandidateIntelligenceProfile> loadProfile({
    required String applicationId,
  }) async {
    final application = await _applications.getApplication(applicationId);
    if (application == null) {
      throw StateError('Application not found.');
    }
    final job = await _jobs.getJob(application.jobId);
    if (job == null) {
      throw StateError('Job not found.');
    }
    final candidate = await _users.getUser(application.applicantId);
    if (candidate == null) {
      throw StateError('Candidate not found.');
    }

    await ensureHiringAccess(
      companyId: application.companyId,
      candidateId: application.applicantId,
      applicationId: application.id,
      jobId: application.jobId,
    );

    final sessions = (await _lab.listSessionsForCandidate(
      application.applicantId,
      limit: 40,
    ))
        .where((s) => s.status == InterviewLabSessionStatus.completed)
        .toList();

    final reports = <InterviewLabReportModel>[];
    for (final s in sessions) {
      final report = await _lab.getReportForSession(s.sessionId);
      if (report != null) reports.add(report);
    }
    reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final badges = await _lab.listBadgesForCandidate(application.applicantId);
    final progress = await _lab.getProgress(application.applicantId);

    List<CertificateModel> certificates = const [];
    try {
      certificates = await _certificates
          .watchStudentCertificates(application.applicantId)
          .first
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      AppLogger.debug('Candidate intelligence certificates were unavailable.');
    }

    final portfolio = await _loadPortfolio(application.applicantId);
    final courses = await _loadCompletedCourses(application.applicantId);

    return CompanyCandidateIntelligenceProfile(
      candidate: candidate,
      application: application,
      job: job,
      labSessions: sessions,
      labReports: reports,
      badges: badges,
      certificates: certificates,
      skills: portfolio.skills,
      portfolioLinks: portfolio.links,
      portfolioHeadline: portfolio.headline,
      completedCourseTitles: courses,
      progress: progress,
      latestReport: reports.isEmpty ? null : reports.first,
      profileCompletion: candidate.profileCompleted,
      matchingSkills: application.matchedSkills,
      missingSkills: application.missingSkills,
      jobMatchPercent: application.rankingScore > 0
          ? application.rankingScore
          : 0,
      aiSummary: application.evaluationSummary,
      aiRecommendation: application.recommendedNextStep,
    );
  }

  Future<CompanyCandidateIntelligenceProfile> enrichWithAi(
    CompanyCandidateIntelligenceProfile profile,
  ) async {
    final summary = await _generateSummary(profile);
    final match = await _generateJobMatch(profile);
    final recommendation = await _generateRecommendation(profile, match);

    // Cache advisory fields on application (not Lab docs).
    await _applications.updateApplicationHiringData(
      applicationId: profile.application.id,
      evaluationSummary: summary,
      rankingScore: match.percent,
      rankingReason: match.reasoning,
      matchedSkills: match.matching,
      missingSkills: match.missing,
      recommendedNextStep: '${recommendation.label}: ${recommendation.reason}',
      evaluatedAt: DateTime.now(),
    );

    return profile.copyWith(
      aiSummary: summary,
      aiRecommendation: recommendation.label,
      aiRecommendationReason: recommendation.reason,
      jobMatchPercent: match.percent,
      jobMatchReasoning: match.reasoning,
      matchingSkills: match.matching,
      missingSkills: match.missing,
    );
  }

  Future<List<CompanyCandidateComparisonRow>> compareCandidates({
    required String jobId,
    required List<String> applicationIds,
  }) async {
    final profiles = <CompanyCandidateIntelligenceProfile>[];
    for (final id in applicationIds) {
      profiles.add(await loadProfile(applicationId: id));
    }

    final response = await _aiHiring.generate(
      CompanyAiHiringRequestModel(
        taskType: CompanyAiTaskType.companyCandidateComparison,
        prompt: '''
Compare these candidates for job compatibility. Return structuredData.comparison
with candidates[] each having: applicationId, technical, communication, confidence,
portfolio, projects, certificates, interviewScore, overallRecommendation.
Use Interview Lab scores when present. Never invent protected attributes.
''',
        context: CompanyAiContextModel(
          companyId: profiles.first.application.companyId,
          companyName: 'Company',
          job: profiles.first.job,
          applications: profiles.map((p) => p.application).toList(),
          extraInstructions: profiles.map((p) {
            return '''
applicationId=${p.application.id}
name=${p.candidate.fullName}
tech=${p.technicalScore} comm=${p.communicationScore} conf=${p.confidenceScore}
interview=${p.overallInterviewScore} certs=${p.certificates.length}
portfolioLinks=${p.portfolioLinks.length} courses=${p.completedCourseTitles.length}
readiness=${p.readinessLevel}
''';
          }).join('\n'),
        ),
      ),
    );

    if (response.isUnavailable || response.structuredData.isEmpty) {
      throw StateError(
        response.summary.isNotEmpty
            ? response.summary
            : 'AI comparison unavailable. Start the AI Gateway and retry.',
      );
    }

    final comparison = response.structuredData['comparison'];
    final rows = <CompanyCandidateComparisonRow>[];
    if (comparison is Map && comparison['candidates'] is List) {
      for (final item in comparison['candidates'] as List) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final appId = map['applicationId']?.toString() ?? '';
        final fallback = profiles.cast<CompanyCandidateIntelligenceProfile?>().firstWhere(
              (p) => p?.application.id == appId,
              orElse: () => null,
            );
        rows.add(
          CompanyCandidateComparisonRow(
            applicationId: appId.isNotEmpty
                ? appId
                : (fallback?.application.id ?? ''),
            candidateName: map['name']?.toString() ??
                fallback?.candidate.fullName ??
                'Candidate',
            technical: _d(map['technical'], fallback?.technicalScore ?? 0),
            communication:
                _d(map['communication'], fallback?.communicationScore ?? 0),
            confidence: _d(map['confidence'], fallback?.confidenceScore ?? 0),
            portfolioScore: _d(map['portfolio'], fallback == null
                ? 0
                : (fallback.portfolioLinks.isEmpty ? 30 : 70)),
            projectsScore: _d(map['projects'], fallback == null
                ? 0
                : (fallback.completedCourseTitles.isEmpty ? 25 : 65)),
            certificatesCount: (map['certificates'] as num?)?.toInt() ??
                fallback?.certificates.length ??
                0,
            interviewScore:
                _d(map['interviewScore'], fallback?.overallInterviewScore ?? 0),
            overallRecommendation:
                map['overallRecommendation']?.toString() ??
                    map['suggestedFit']?.toString() ??
                    'Needs Interview',
          ),
        );
      }
    }

    if (rows.isEmpty) {
      // Fail closed on empty AI — still allow local scoreboard without fake narrative.
      for (final p in profiles) {
        rows.add(
          CompanyCandidateComparisonRow(
            applicationId: p.application.id,
            candidateName: p.candidate.fullName,
            technical: p.technicalScore,
            communication: p.communicationScore,
            confidence: p.confidenceScore,
            portfolioScore: p.portfolioLinks.isEmpty ? 30 : 70,
            projectsScore: p.completedCourseTitles.isEmpty ? 25 : 65,
            certificatesCount: p.certificates.length,
            interviewScore: p.overallInterviewScore,
            overallRecommendation: 'Needs Interview',
          ),
        );
      }
      if (response.structuredData.isEmpty) {
        throw StateError(
          'AI returned an empty comparison. Scores shown locally — retry AI when Gateway is healthy.',
        );
      }
    }
    return rows;
  }

  Future<String> _generateSummary(
    CompanyCandidateIntelligenceProfile profile,
  ) async {
    final response = await _aiHiring.generate(
      CompanyAiHiringRequestModel(
        taskType: CompanyAiTaskType.companyCandidateSummary,
        prompt: '''
Write a professional hiring summary (3-6 sentences) for this candidate.
Include readiness recommendation for role "${profile.job.title}".
Ground claims in Interview Lab scores and profile evidence only.
''',
        context: CompanyAiContextModel(
          companyId: profile.application.companyId,
          companyName: 'Company',
          job: profile.job,
          applications: [profile.application],
          extraInstructions: _evidenceBlock(profile),
        ),
      ),
    );
    if (response.isUnavailable || response.structuredData.isEmpty) {
      throw StateError(
        response.summary.isNotEmpty
            ? response.summary
            : 'AI summary unavailable.',
      );
    }
    final summaryMap = response.structuredData['candidateSummary'];
    if (summaryMap is Map) {
      final headline = summaryMap['headline']?.toString() ?? '';
      final strengths = (summaryMap['roleRelevantStrengths'] as List?)
              ?.map((e) => e.toString())
              .join('; ') ??
          '';
      final next = summaryMap['recommendedNextStep']?.toString() ?? '';
      final text = [
        if (headline.isNotEmpty) headline,
        if (strengths.isNotEmpty) strengths,
        if (next.isNotEmpty) 'Recommended: $next',
      ].join(' ');
      if (text.trim().isNotEmpty) return text.trim();
    }
    final message = response.summary.trim();
    if (message.isNotEmpty) return message;
    throw const FormatException('AI returned an empty candidate summary.');
  }

  Future<({double percent, String reasoning, List<String> matching, List<String> missing})>
      _generateJobMatch(CompanyCandidateIntelligenceProfile profile) async {
    final request = CopilotAiRequestModel(
      requestId: 'job_match_${DateTime.now().microsecondsSinceEpoch}',
      userId: _auth.currentUser?.uid ?? profile.application.companyId,
      role: 'company',
      accountType: 'professional',
      taskType: 'companyJobMatchScore',
      userMessage: '''
Calculate job compatibility for "${profile.job.title}".
Return structuredData.jobMatch with percent (0-100), reasoning, matchingSkills[], missingSkills[].
Evidence:
${_evidenceBlock(profile)}
Job required skills: ${profile.job.requiredSkills.join(', ')}
''',
      pageContext: {
        'module': 'company_hiring',
        'applicationId': profile.application.id,
        'jobId': profile.job.id,
      },
      safeAppContext: {
        'module': 'company_hiring',
        'task': 'job_match',
      },
      languageHint: 'en',
      constraints: const [
        'Return JSON only.',
        'Do not write Firestore.',
        'No protected attributes.',
        'Advisory only — no hire/reject.',
      ],
      timestamp: DateTime.now(),
    );

    final response = await _gateway.send(request);
    if (!response.isSuccess) {
      throw StateError(
        response.message.isNotEmpty
            ? response.message
            : 'AI job match unavailable.',
      );
    }
    final raw = response.structuredData['jobMatch'];
    if (raw is! Map) {
      throw const FormatException('AI returned an invalid job match payload.');
    }
    final map = Map<String, dynamic>.from(raw);
    final percent = (map['percent'] as num?)?.toDouble() ??
        (map['score'] as num?)?.toDouble() ??
        0;
    final matching = (map['matchingSkills'] as List?)
            ?.map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const <String>[];
    final missing = (map['missingSkills'] as List?)
            ?.map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const <String>[];
    final reasoning = map['reasoning']?.toString() ?? '';
    if (reasoning.isEmpty && percent <= 0) {
      throw const FormatException('AI job match was empty.');
    }
    return (
      percent: percent.clamp(0, 100).toDouble(),
      reasoning: reasoning,
      matching: matching,
      missing: missing,
    );
  }

  Future<({String label, String reason})> _generateRecommendation(
    CompanyCandidateIntelligenceProfile profile,
    ({double percent, String reasoning, List<String> matching, List<String> missing})
        match,
  ) async {
    final request = CopilotAiRequestModel(
      requestId: 'hire_rec_${DateTime.now().microsecondsSinceEpoch}',
      userId: _auth.currentUser?.uid ?? profile.application.companyId,
      role: 'company',
      accountType: 'professional',
      taskType: 'companyHiringRecommendation',
      userMessage: '''
Recommend one of: Highly Recommended | Recommended | Needs Interview | Needs Improvement | Not Recommended.
Explain WHY in 2-4 sentences. Return structuredData.recommendation {label, reason}.
Job match ${match.percent}% — ${match.reasoning}
${_evidenceBlock(profile)}
''',
      pageContext: {
        'module': 'company_hiring',
        'applicationId': profile.application.id,
      },
      safeAppContext: {
        'module': 'company_hiring',
        'task': 'hiring_recommendation',
      },
      languageHint: 'en',
      constraints: const [
        'Return JSON only.',
        'Do not change statuses.',
        'Advisory only.',
      ],
      timestamp: DateTime.now(),
    );
    final response = await _gateway.send(request);
    if (!response.isSuccess) {
      throw StateError(
        response.message.isNotEmpty
            ? response.message
            : 'AI recommendation unavailable.',
      );
    }
    final raw = response.structuredData['recommendation'];
    if (raw is! Map) {
      throw const FormatException('Invalid recommendation payload.');
    }
    final label = raw['label']?.toString() ?? '';
    final reason = raw['reason']?.toString() ?? '';
    if (!CompanyHiringRecommendation.all.contains(label) || reason.isEmpty) {
      throw const FormatException('AI recommendation incomplete.');
    }
    return (label: label, reason: reason);
  }

  String _evidenceBlock(CompanyCandidateIntelligenceProfile p) {
    return '''
candidate=${p.candidate.fullName}
role=${p.candidate.primaryRole}
profileCompletion=${p.profileCompletion}%
bio=${p.candidate.bio}
skills=${p.skills.join(', ')}
portfolio=${p.portfolioHeadline} links=${p.portfolioLinks.join(' | ')}
certificates=${p.certificates.map((c) => c.courseTitle).join(', ')}
courses=${p.completedCourseTitles.join(', ')}
badges=${p.badges.map((b) => b.title).join(', ')}
labOverall=${p.overallInterviewScore} tech=${p.technicalScore} comm=${p.communicationScore}
conf=${p.confidenceScore} ps=${p.problemSolvingScore} level=${p.readinessLevel}
labSessions=${p.labSessions.length}
progressInsights=${p.progress?.insights.join('; ') ?? 'n/a'}
''';
  }

  Future<({String headline, List<String> skills, List<String> links})>
      _loadPortfolio(String uid) async {
    try {
      final snap = await _firestore.collection('users').doc(uid).get();
      final data = snap.data() ?? {};
      final details = Map<String, dynamic>.from(
        (data['professionalDetails'] as Map?)?.cast<String, dynamic>() ??
            (data['details'] as Map?)?.cast<String, dynamic>() ??
            const {},
      );
      final skills = <String>[
        ..._strings(details['skills']),
        ..._strings(data['skills']),
      ];
      final links = <String>[
        ..._strings(details['portfolioLinks']),
        ..._strings(data['portfolioLinks']),
        if ((details['portfolioUrl'] ?? data['portfolioUrl'] ?? '')
            .toString()
            .isNotEmpty)
          (details['portfolioUrl'] ?? data['portfolioUrl']).toString(),
      ];
      final headline = (details['professionalTitle'] ??
              details['headline'] ??
              data['headline'] ??
              '')
          .toString();
      return (headline: headline, skills: skills.toSet().toList(), links: links);
    } catch (_) {
      return (headline: '', skills: const <String>[], links: const <String>[]);
    }
  }

  Future<List<String>> _loadCompletedCourses(String uid) async {
    try {
      final snap = await _firestore
          .collection('enrollments')
          .where('studentId', isEqualTo: uid)
          .limit(30)
          .get();
      final titles = <String>[];
      for (final doc in snap.docs) {
        final data = doc.data();
        final status = (data['status'] ?? '').toString().toLowerCase();
        final progress = (data['progressPercent'] as num?)?.toDouble() ?? 0;
        if (status.contains('complete') || progress >= 100) {
          final title = (data['courseTitle'] ?? data['courseId'] ?? '').toString();
          if (title.isNotEmpty) titles.add(title);
        }
      }
      return titles;
    } catch (_) {
      return const [];
    }
  }

  double _d(Object? value, double fallback) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  List<String> _strings(Object? value) {
    if (value is Iterable) {
      return value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    if (value is String && value.trim().isNotEmpty) return [value.trim()];
    return const [];
  }
}
