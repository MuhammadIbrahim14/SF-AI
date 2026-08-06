import 'package:cloud_firestore/cloud_firestore.dart';

/// Gateway task types for Phase 6 Career Intelligence.
abstract final class CareerIntelligenceTaskType {
  static const studentAdvisor = 'studentCareerAdvisor';
  static const freelancerAdvisor = 'freelancerCareerAdvisor';
  static const teacherAdvisor = 'teacherCareerAdvisor';
  static const companyAdvisor = 'companyCareerAdvisor';
  static const skillGap = 'careerSkillGapAnalysis';
  static const learningRoadmap = 'careerLearningRoadmap';
  static const resumeReview = 'careerResumeReview';
  static const portfolioReview = 'careerPortfolioReview';
  static const marketInsights = 'careerMarketInsights';

  static String advisorForRole(String role) {
    return switch (role.trim().toLowerCase()) {
      'freelancer' => freelancerAdvisor,
      'teacher' => teacherAdvisor,
      'company' => companyAdvisor,
      _ => studentAdvisor,
    };
  }
}

class CareerSkillGap {
  const CareerSkillGap({
    required this.currentSkills,
    required this.missingSkills,
    required this.targetSkills,
    required this.estimatedLearningHours,
    required this.suggestedPath,
    this.progressPercent = 0,
  });

  final List<String> currentSkills;
  final List<String> missingSkills;
  final List<String> targetSkills;
  final int estimatedLearningHours;
  final List<String> suggestedPath;
  final double progressPercent;

  factory CareerSkillGap.fromMap(Map<String, dynamic>? data) {
    final map = data ?? const <String, dynamic>{};
    return CareerSkillGap(
      currentSkills: _strings(map['currentSkills']),
      missingSkills: _strings(map['missingSkills']),
      targetSkills: _strings(map['targetSkills']),
      estimatedLearningHours: _int(map['estimatedLearningHours'], 40),
      suggestedPath: _strings(map['suggestedPath']),
      progressPercent: _double(map['progressPercent']),
    );
  }

  Map<String, dynamic> toMap() => {
        'currentSkills': currentSkills,
        'missingSkills': missingSkills,
        'targetSkills': targetSkills,
        'estimatedLearningHours': estimatedLearningHours,
        'suggestedPath': suggestedPath,
        'progressPercent': progressPercent,
      };

  static const empty = CareerSkillGap(
    currentSkills: <String>[],
    missingSkills: <String>[],
    targetSkills: <String>[],
    estimatedLearningHours: 0,
    suggestedPath: <String>[],
  );
}

class CareerRoadmapPlan {
  const CareerRoadmapPlan({
    required this.days30,
    required this.days60,
    required this.days90,
    this.focus = '',
  });

  final List<String> days30;
  final List<String> days60;
  final List<String> days90;
  final String focus;

  factory CareerRoadmapPlan.fromMap(Map<String, dynamic>? data) {
    final map = data ?? const <String, dynamic>{};
    return CareerRoadmapPlan(
      days30: _strings(map['days30'] ?? map['30']),
      days60: _strings(map['days60'] ?? map['60']),
      days90: _strings(map['days90'] ?? map['90']),
      focus: (map['focus'] as String?)?.trim() ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'days30': days30,
        'days60': days60,
        'days90': days90,
        'focus': focus,
      };

  static const empty = CareerRoadmapPlan(
    days30: <String>[],
    days60: <String>[],
    days90: <String>[],
  );
}

class CareerReviewResult {
  const CareerReviewResult({
    required this.score,
    required this.summary,
    required this.improvements,
    required this.missingSections,
    required this.strengths,
    this.atsReady = false,
  });

  final double score;
  final String summary;
  final List<String> improvements;
  final List<String> missingSections;
  final List<String> strengths;
  final bool atsReady;

  factory CareerReviewResult.fromMap(Map<String, dynamic>? data) {
    final map = data ?? const <String, dynamic>{};
    return CareerReviewResult(
      score: _double(map['score'] ?? map['profileScore']),
      summary: (map['summary'] as String?)?.trim() ?? '',
      improvements: _strings(map['improvements'] ?? map['suggestions']),
      missingSections: _strings(map['missingSections']),
      strengths: _strings(map['strengths']),
      atsReady: map['atsReady'] == true || map['atsReadiness'] == true,
    );
  }

  Map<String, dynamic> toMap() => {
        'score': score,
        'summary': summary,
        'improvements': improvements,
        'missingSections': missingSections,
        'strengths': strengths,
        'atsReady': atsReady,
      };

  static const empty = CareerReviewResult(
    score: 0,
    summary: '',
    improvements: <String>[],
    missingSections: <String>[],
    strengths: <String>[],
  );
}

class CareerMarketInsights {
  const CareerMarketInsights({
    required this.trendingSkills,
    required this.mostDemanded,
    required this.highestPaying,
    required this.recommendedCertifications,
    required this.emergingTechnologies,
  });

  final List<String> trendingSkills;
  final List<String> mostDemanded;
  final List<String> highestPaying;
  final List<String> recommendedCertifications;
  final List<String> emergingTechnologies;

  factory CareerMarketInsights.fromMap(Map<String, dynamic>? data) {
    final map = data ?? const <String, dynamic>{};
    return CareerMarketInsights(
      trendingSkills: _strings(map['trendingSkills']),
      mostDemanded: _strings(map['mostDemanded'] ?? map['demandedSkills']),
      highestPaying: _strings(map['highestPaying'] ?? map['highestPayingSkills']),
      recommendedCertifications: _strings(map['recommendedCertifications']),
      emergingTechnologies: _strings(map['emergingTechnologies']),
    );
  }

  Map<String, dynamic> toMap() => {
        'trendingSkills': trendingSkills,
        'mostDemanded': mostDemanded,
        'highestPaying': highestPaying,
        'recommendedCertifications': recommendedCertifications,
        'emergingTechnologies': emergingTechnologies,
      };

  static const empty = CareerMarketInsights(
    trendingSkills: <String>[],
    mostDemanded: <String>[],
    highestPaying: <String>[],
    recommendedCertifications: <String>[],
    emergingTechnologies: <String>[],
  );
}

class CareerAchievementBadge {
  const CareerAchievementBadge({
    required this.id,
    required this.title,
    required this.description,
    required this.earnedAt,
  });

  final String id;
  final String title;
  final String description;
  final DateTime earnedAt;

  factory CareerAchievementBadge.fromMap(Map<String, dynamic> data) {
    return CareerAchievementBadge(
      id: (data['id'] as String?)?.trim() ?? '',
      title: (data['title'] as String?)?.trim() ?? '',
      description: (data['description'] as String?)?.trim() ?? '',
      earnedAt: data['earnedAt'] is Timestamp
          ? (data['earnedAt'] as Timestamp).toDate()
          : DateTime.tryParse('${data['earnedAt']}') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'earnedAt': Timestamp.fromDate(earnedAt),
      };
}

class CareerIntelligenceReport {
  const CareerIntelligenceReport({
    required this.userId,
    required this.role,
    required this.title,
    required this.summary,
    required this.readinessScore,
    required this.insights,
    required this.recommendations,
    required this.skillGap,
    required this.roadmap,
    required this.resumeReview,
    required this.portfolioReview,
    required this.marketInsights,
    required this.achievements,
    required this.metrics,
    required this.updatedAt,
    this.fromCache = false,
    this.aiAvailable = true,
    this.errorMessage = '',
  });

  final String userId;
  final String role;
  final String title;
  final String summary;
  final double readinessScore;
  final List<String> insights;
  final List<String> recommendations;
  final CareerSkillGap skillGap;
  final CareerRoadmapPlan roadmap;
  final CareerReviewResult resumeReview;
  final CareerReviewResult portfolioReview;
  final CareerMarketInsights marketInsights;
  final List<CareerAchievementBadge> achievements;
  final Map<String, dynamic> metrics;
  final DateTime updatedAt;
  final bool fromCache;
  final bool aiAvailable;
  final String errorMessage;

  factory CareerIntelligenceReport.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return CareerIntelligenceReport(
      userId: (data['userId'] as String?) ?? doc.id,
      role: (data['role'] as String?) ?? 'student',
      title: (data['title'] as String?) ?? 'Career Intelligence',
      summary: (data['summary'] as String?) ?? '',
      readinessScore: _double(data['readinessScore']),
      insights: _strings(data['insights']),
      recommendations: _strings(data['recommendations']),
      skillGap: CareerSkillGap.fromMap(
        data['skillGap'] is Map
            ? Map<String, dynamic>.from(data['skillGap'] as Map)
            : null,
      ),
      roadmap: CareerRoadmapPlan.fromMap(
        data['roadmap'] is Map
            ? Map<String, dynamic>.from(data['roadmap'] as Map)
            : null,
      ),
      resumeReview: CareerReviewResult.fromMap(
        data['resumeReview'] is Map
            ? Map<String, dynamic>.from(data['resumeReview'] as Map)
            : null,
      ),
      portfolioReview: CareerReviewResult.fromMap(
        data['portfolioReview'] is Map
            ? Map<String, dynamic>.from(data['portfolioReview'] as Map)
            : null,
      ),
      marketInsights: CareerMarketInsights.fromMap(
        data['marketInsights'] is Map
            ? Map<String, dynamic>.from(data['marketInsights'] as Map)
            : null,
      ),
      achievements: (data['achievements'] is Iterable)
          ? (data['achievements'] as Iterable)
              .whereType<Map>()
              .map((e) => CareerAchievementBadge.fromMap(
                    Map<String, dynamic>.from(e),
                  ))
              .toList()
          : const <CareerAchievementBadge>[],
      metrics: data['metrics'] is Map
          ? Map<String, dynamic>.from(data['metrics'] as Map)
          : const <String, dynamic>{},
      updatedAt: data['updatedAt'] is Timestamp
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      fromCache: true,
      aiAvailable: data['aiAvailable'] != false,
      errorMessage: (data['errorMessage'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'role': role,
        'title': title,
        'summary': summary,
        'readinessScore': readinessScore,
        'insights': insights,
        'recommendations': recommendations,
        'skillGap': skillGap.toMap(),
        'roadmap': roadmap.toMap(),
        'resumeReview': resumeReview.toMap(),
        'portfolioReview': portfolioReview.toMap(),
        'marketInsights': marketInsights.toMap(),
        'achievements': achievements.map((e) => e.toMap()).toList(),
        'metrics': metrics,
        'updatedAt': Timestamp.fromDate(updatedAt),
        'aiAvailable': aiAvailable,
        'errorMessage': errorMessage,
      };

  CareerIntelligenceReport copyWith({
    bool? fromCache,
    bool? aiAvailable,
    String? errorMessage,
  }) {
    return CareerIntelligenceReport(
      userId: userId,
      role: role,
      title: title,
      summary: summary,
      readinessScore: readinessScore,
      insights: insights,
      recommendations: recommendations,
      skillGap: skillGap,
      roadmap: roadmap,
      resumeReview: resumeReview,
      portfolioReview: portfolioReview,
      marketInsights: marketInsights,
      achievements: achievements,
      metrics: metrics,
      updatedAt: updatedAt,
      fromCache: fromCache ?? this.fromCache,
      aiAvailable: aiAvailable ?? this.aiAvailable,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

List<String> _strings(Object? value) {
  if (value is Iterable) {
    return value
        .map((e) => e?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
  }
  if (value is String && value.trim().isNotEmpty) {
    return value
        .split(RegExp(r'[\n,]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
  return const <String>[];
}

int _int(Object? value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

double _double(Object? value, [double fallback = 0]) {
  if (value is num) return value.toDouble().clamp(0, 100);
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}
