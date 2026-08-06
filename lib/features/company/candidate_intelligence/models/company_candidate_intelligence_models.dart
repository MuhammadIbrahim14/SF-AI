import '../../../../models/application_model.dart';
import '../../../../models/job_model.dart';
import '../../../../models/user_model.dart';
import '../../../courses/data/models/certificate_model.dart';
import '../../../interview_lab/models/interview_lab_models.dart';

/// Aggregated candidate intelligence for company ATS (read-only Lab scores).
class CompanyCandidateIntelligenceProfile {
  const CompanyCandidateIntelligenceProfile({
    required this.candidate,
    required this.application,
    required this.job,
    required this.labSessions,
    required this.labReports,
    required this.badges,
    required this.certificates,
    required this.skills,
    required this.portfolioLinks,
    required this.portfolioHeadline,
    required this.completedCourseTitles,
    this.progress,
    this.latestReport,
    this.aiSummary = '',
    this.aiRecommendation = '',
    this.aiRecommendationReason = '',
    this.jobMatchPercent = 0,
    this.jobMatchReasoning = '',
    this.matchingSkills = const [],
    this.missingSkills = const [],
    this.profileCompletion = 0,
  });

  final UserModel candidate;
  final ApplicationModel application;
  final JobModel job;
  final List<InterviewLabSessionModel> labSessions;
  final List<InterviewLabReportModel> labReports;
  final List<InterviewLabBadgeModel> badges;
  final List<CertificateModel> certificates;
  final List<String> skills;
  final List<String> portfolioLinks;
  final String portfolioHeadline;
  final List<String> completedCourseTitles;
  final InterviewLabProgressModel? progress;
  final InterviewLabReportModel? latestReport;

  final String aiSummary;
  final String aiRecommendation;
  final String aiRecommendationReason;
  final double jobMatchPercent;
  final String jobMatchReasoning;
  final List<String> matchingSkills;
  final List<String> missingSkills;
  final int profileCompletion;

  double get technicalScore =>
      latestReport?.technicalScore ?? application.evaluationScore;
  double get communicationScore => latestReport?.communicationScore ?? 0;
  double get confidenceScore => latestReport?.confidenceScore ?? 0;
  double get problemSolvingScore => latestReport?.problemSolvingScore ?? 0;
  double get overallInterviewScore =>
      latestReport?.overallRating ?? application.rankingScore;
  String get readinessLevel =>
      latestReport?.interviewLevel ??
      (overallInterviewScore >= 75 ? 'Job Ready' : 'Developing');

  CompanyCandidateIntelligenceProfile copyWith({
    String? aiSummary,
    String? aiRecommendation,
    String? aiRecommendationReason,
    double? jobMatchPercent,
    String? jobMatchReasoning,
    List<String>? matchingSkills,
    List<String>? missingSkills,
  }) {
    return CompanyCandidateIntelligenceProfile(
      candidate: candidate,
      application: application,
      job: job,
      labSessions: labSessions,
      labReports: labReports,
      badges: badges,
      certificates: certificates,
      skills: skills,
      portfolioLinks: portfolioLinks,
      portfolioHeadline: portfolioHeadline,
      completedCourseTitles: completedCourseTitles,
      progress: progress,
      latestReport: latestReport,
      aiSummary: aiSummary ?? this.aiSummary,
      aiRecommendation: aiRecommendation ?? this.aiRecommendation,
      aiRecommendationReason:
          aiRecommendationReason ?? this.aiRecommendationReason,
      jobMatchPercent: jobMatchPercent ?? this.jobMatchPercent,
      jobMatchReasoning: jobMatchReasoning ?? this.jobMatchReasoning,
      matchingSkills: matchingSkills ?? this.matchingSkills,
      missingSkills: missingSkills ?? this.missingSkills,
      profileCompletion: profileCompletion,
    );
  }
}

class CompanyCandidateComparisonRow {
  const CompanyCandidateComparisonRow({
    required this.applicationId,
    required this.candidateName,
    required this.technical,
    required this.communication,
    required this.confidence,
    required this.portfolioScore,
    required this.projectsScore,
    required this.certificatesCount,
    required this.interviewScore,
    required this.overallRecommendation,
  });

  final String applicationId;
  final String candidateName;
  final double technical;
  final double communication;
  final double confidence;
  final double portfolioScore;
  final double projectsScore;
  final int certificatesCount;
  final double interviewScore;
  final String overallRecommendation;
}

class CompanyHiringRecommendation {
  const CompanyHiringRecommendation._();

  static const highlyRecommended = 'Highly Recommended';
  static const recommended = 'Recommended';
  static const needsInterview = 'Needs Interview';
  static const needsImprovement = 'Needs Improvement';
  static const notRecommended = 'Not Recommended';

  static const all = <String>[
    highlyRecommended,
    recommended,
    needsInterview,
    needsImprovement,
    notRecommended,
  ];
}
