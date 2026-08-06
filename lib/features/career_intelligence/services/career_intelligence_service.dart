import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/utils/app_logger.dart';
import '../../copilot/models/copilot_ai_request_model.dart';
import '../../copilot/models/copilot_ai_response_model.dart';
import '../../copilot/services/ai_gateway_client.dart';
import '../../interview_lab/data/interview_lab_repository.dart';
import '../models/career_intelligence_models.dart';
import 'career_intelligence_context_builder.dart';

/// Phase 6 orchestrator — aggregates evidence + one AI advisor call + cache.
class CareerIntelligenceService {
  CareerIntelligenceService({
    required FirebaseFirestore firestore,
    required InterviewLabRepository labRepository,
    AiGatewayClient? gatewayClient,
    FirebaseAuth? auth,
  })  : _firestore = firestore,
        _gateway = gatewayClient ?? AiGatewayClient(),
        _auth = auth ?? FirebaseAuth.instance,
        _contextBuilder = CareerIntelligenceContextBuilder(
          firestore: firestore,
          labRepository: labRepository,
        );

  final FirebaseFirestore _firestore;
  final AiGatewayClient _gateway;
  final FirebaseAuth _auth;
  final CareerIntelligenceContextBuilder _contextBuilder;

  static const cacheTtl = Duration(hours: 12);
  static const offlineCacheTtl = Duration(minutes: 15);

  DocumentReference<Map<String, dynamic>> _cacheRef(String userId) =>
      _firestore.collection('careerIntelligence').doc(userId);

  CollectionReference<Map<String, dynamic>> get _badgesRef =>
      _firestore.collection('career_badges');

  Future<CareerIntelligenceReport?> getCached(String userId) async {
    final doc = await _cacheRef(userId).get();
    if (!doc.exists || doc.data() == null) return null;
    return CareerIntelligenceReport.fromFirestore(doc);
  }

  Future<CareerIntelligenceReport> loadReport({
    required String userId,
    required String role,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      try {
        final cached = await getCached(userId).timeout(const Duration(seconds: 6));
        if (cached != null) {
          final age = DateTime.now().difference(cached.updatedAt);
          final ttl = cached.aiAvailable ? cacheTtl : offlineCacheTtl;
          if (age < ttl) {
            return cached.copyWith(fromCache: true);
          }
        }
      } catch (_) {
        AppLogger.debug('Career intelligence cache read was skipped.');
      }
    }

    Map<String, dynamic> evidence;
    try {
      evidence = await _contextBuilder
          .build(userId: userId, role: role)
          .timeout(const Duration(seconds: 18));
    } catch (_) {
      AppLogger.warn('Career intelligence evidence gathering was unavailable.');
      evidence = {
        'role': role,
        'userId': userId,
        'profile': const <String, dynamic>{},
        'learning': const <String, dynamic>{},
        'interviewLab': const <String, dynamic>{},
        'applications': const <String, dynamic>{'count': 0},
        'resume': const <String, dynamic>{'exists': false},
        'market': const <String, dynamic>{
          'trendingFromJobs': <String>[],
          'jobSampleSize': 0,
        },
      };
    }

    final local = _buildLocalBaseline(
      userId: userId,
      role: role,
      evidence: evidence,
    );

    CopilotAiResponseModel? ai;
    try {
      ai = await _gateway
          .send(
            CopilotAiRequestModel(
              requestId: 'career_${DateTime.now().microsecondsSinceEpoch}',
              userId: _auth.currentUser?.uid ?? userId,
              role: role,
              accountType: 'professional',
              taskType: CareerIntelligenceTaskType.advisorForRole(role),
              userMessage: _advisorPrompt(role),
              pageContext: evidence,
              safeAppContext: evidence,
              languageHint: 'en',
              constraints: const [
                'Return JSON only.',
                'Do not write Firestore.',
                'Use only provided evidence.',
                'Do not invent credentials, salaries as guarantees, or certificates.',
                'Manual review required.',
              ],
              timestamp: DateTime.now(),
            ),
          )
          .timeout(const Duration(seconds: 40));
    } catch (_) {
      AppLogger.warn('Career intelligence AI gateway request failed.');
    }

    final merged = _mergeAi(local, ai);
    var achievements = const <CareerAchievementBadge>[];
    try {
      achievements = await _awardAchievements(
        userId: userId,
        role: role,
        evidence: evidence,
        readiness: merged.readinessScore,
      ).timeout(const Duration(seconds: 10));
    } catch (_) {
      AppLogger.debug('Career intelligence achievements were skipped.');
    }

    final report = CareerIntelligenceReport(
      userId: userId,
      role: role,
      title: merged.title,
      summary: merged.summary,
      readinessScore: merged.readinessScore,
      insights: merged.insights,
      recommendations: merged.recommendations,
      skillGap: merged.skillGap,
      roadmap: merged.roadmap,
      resumeReview: merged.resumeReview,
      portfolioReview: merged.portfolioReview,
      marketInsights: merged.marketInsights,
      achievements: achievements,
      metrics: merged.metrics,
      updatedAt: DateTime.now(),
      fromCache: false,
      aiAvailable: ai?.isSuccess == true,
      errorMessage: ai == null || ai.isSuccess
          ? ''
          : (ai.message.isNotEmpty
              ? ai.message
              : 'AI advisor unavailable. Showing evidence-based insights.'),
    );

    try {
      await _cacheRef(userId)
          .set(report.toJson(), SetOptions(merge: true))
          .timeout(const Duration(seconds: 6));
    } catch (_) {
      AppLogger.debug('Career intelligence cache write was skipped.');
    }
    return report;
  }

  Future<CareerIntelligenceReport> runFocusedReview({
    required String userId,
    required String role,
    required String taskType,
  }) async {
    final evidence = await _contextBuilder.build(userId: userId, role: role);
    final base = await loadReport(userId: userId, role: role);
    final response = await _gateway.send(
      CopilotAiRequestModel(
        requestId: 'career_focus_${DateTime.now().microsecondsSinceEpoch}',
        userId: _auth.currentUser?.uid ?? userId,
        role: role,
        accountType: 'professional',
        taskType: taskType,
        userMessage: 'Generate focused career analysis for $taskType.',
        pageContext: evidence,
        safeAppContext: evidence,
        languageHint: 'en',
        constraints: const [
          'Return JSON only.',
          'Do not write Firestore.',
          'Use only provided evidence.',
        ],
        timestamp: DateTime.now(),
      ),
    );

    final data = response.structuredData;
    CareerReviewResult? resume;
    CareerReviewResult? portfolio;
    CareerRoadmapPlan? roadmap;
    CareerSkillGap? gap;
    CareerMarketInsights? market;

    if (taskType == CareerIntelligenceTaskType.resumeReview) {
      resume = CareerReviewResult.fromMap(_asMap(data['resumeReview'] ?? data));
    } else if (taskType == CareerIntelligenceTaskType.portfolioReview) {
      portfolio =
          CareerReviewResult.fromMap(_asMap(data['portfolioReview'] ?? data));
    } else if (taskType == CareerIntelligenceTaskType.learningRoadmap) {
      roadmap = CareerRoadmapPlan.fromMap(_asMap(data['roadmap'] ?? data));
    } else if (taskType == CareerIntelligenceTaskType.skillGap) {
      gap = CareerSkillGap.fromMap(_asMap(data['skillGap'] ?? data));
    } else if (taskType == CareerIntelligenceTaskType.marketInsights) {
      market = CareerMarketInsights.fromMap(
        _asMap(data['marketInsights'] ?? data),
      );
    }

    final updated = CareerIntelligenceReport(
      userId: base.userId,
      role: base.role,
      title: base.title,
      summary: response.message.isNotEmpty ? response.message : base.summary,
      readinessScore: base.readinessScore,
      insights: base.insights,
      recommendations: [
        ...base.recommendations,
        ...response.suggestions,
      ],
      skillGap: gap ?? base.skillGap,
      roadmap: roadmap ?? base.roadmap,
      resumeReview: resume ?? base.resumeReview,
      portfolioReview: portfolio ?? base.portfolioReview,
      marketInsights: market ?? base.marketInsights,
      achievements: base.achievements,
      metrics: base.metrics,
      updatedAt: DateTime.now(),
      aiAvailable: response.isSuccess,
      errorMessage: response.isSuccess ? '' : response.message,
    );
    await _cacheRef(userId).set(updated.toJson(), SetOptions(merge: true));
    return updated;
  }

  String _advisorPrompt(String role) {
    return switch (role.trim().toLowerCase()) {
      'freelancer' =>
        'Act as Freelancer AI Career Advisor. Return structuredData with readinessScore, insights[], recommendations[], skillGap, roadmap{days30,days60,days90,focus}, portfolioReview, marketInsights, higherPayingSkills[], pricingSuggestions[], profileImprovements[], proposalImprovements[], recommendedServices[].',
      'teacher' =>
        'Act as Teacher AI Career Advisor. Return structuredData with readinessScore, insights[], recommendations[], skillGap, roadmap{days30,days60,days90,focus}, courseImprovements[], weakTopics[], mostRequestedSkills[], contentRecommendations[], marketInsights.',
      'company' =>
        'Act as Company AI Talent Advisor. Return structuredData with readinessScore, insights[], recommendations[], hiringAnalytics{}, demandedSkills[], recruitmentRecommendations[], hiringBottlenecks[], skillTrends[], marketInsights. Never auto-hire.',
      _ =>
        'Act as Student AI Career Advisor. Return structuredData with readinessScore, careerReadiness, skillGap, learningProgress, recommendedSkills[], recommendedCourses[], recommendedProjects[], recommendedCertifications[], recommendedCareerPath, estimatedSalaryRange, industryReadiness, roadmap{days30,days60,days90,focus}, resumeReview, portfolioReview, marketInsights, insights[], recommendations[].',
    };
  }

  CareerIntelligenceReport _buildLocalBaseline({
    required String userId,
    required String role,
    required Map<String, dynamic> evidence,
  }) {
    final marketRaw = _asMap(evidence['market']);
    final trending = _strings(marketRaw['trendingFromJobs']);
    final profile = _asMap(evidence['profile']);
    final skills = _strings(profile['skills']);
    final missing = trending
        .where((t) => !skills.any((s) => s.toLowerCase() == t.toLowerCase()))
        .take(8)
        .toList();

    final readiness = _localReadiness(role, evidence);
    final resume = _asMap(evidence['resume']);
    final learning = _asMap(evidence['learning']);
    final hiring = _asMap(evidence['hiring']);
    final commerce = _asMap(evidence['commerce']);
    final interview = _asMap(evidence['interviewLab']);

    return CareerIntelligenceReport(
      userId: userId,
      role: role,
      title: 'Career Intelligence',
      summary: _localSummary(role, readiness, evidence),
      readinessScore: readiness,
      insights: _localInsights(role, evidence),
      recommendations: missing
          .take(5)
          .map((s) => 'Build strength in $s based on current job demand.')
          .toList(),
      skillGap: CareerSkillGap(
        currentSkills: skills,
        missingSkills: missing,
        targetSkills: trending.take(8).toList(),
        estimatedLearningHours: missing.length * 12,
        suggestedPath: [
          if (missing.isNotEmpty) 'Focus first on ${missing.first}',
          'Practice with Interview Lab weekly',
          'Ship one portfolio project every 30 days',
        ],
        progressPercent: readiness,
      ),
      roadmap: CareerRoadmapPlan(
        days30: missing.isEmpty
            ? const <String>['Maintain current practice cadence']
            : [
                'Close gap: ${missing.first}',
                if (missing.length > 1) 'Practice ${missing[1]} with evidence',
              ],
        days60: const <String>[],
        days90: const <String>[],
        focus: skills.isEmpty ? 'Foundation building' : skills.first,
      ),
      resumeReview: CareerReviewResult(
        score: _double(resume['score']),
        summary: resume['exists'] == true
            ? 'Smart resume evidence is available.'
            : 'Generate a smart resume to unlock deeper review.',
        improvements: _strings(resume['improvementAreas']),
        missingSections: resume['exists'] == true
            ? const <String>[]
            : const ['Smart resume not generated'],
        strengths: _strings(resume['strengths']),
        atsReady: _double(resume['score']) >= 70,
      ),
      portfolioReview: CareerReviewResult(
        score: readiness,
        summary: skills.isEmpty
            ? 'Not enough portfolio evidence yet.'
            : 'Evidence-based portfolio baseline from profile proof.',
        improvements: const <String>[],
        missingSections: const <String>[],
        strengths: skills.take(5).toList(),
      ),
      marketInsights: CareerMarketInsights(
        trendingSkills: trending,
        mostDemanded: trending.take(8).toList(),
        highestPaying: trending.take(5).toList(),
        recommendedCertifications: const <String>[],
        emergingTechnologies: trending.take(4).toList(),
      ),
      achievements: const <CareerAchievementBadge>[],
      metrics: {
        'learning': learning,
        'hiring': hiring,
        'commerce': commerce,
        'interviewLab': interview,
      },
      updatedAt: DateTime.now(),
      aiAvailable: false,
    );
  }

  CareerIntelligenceReport _mergeAi(
    CareerIntelligenceReport local,
    CopilotAiResponseModel? ai,
  ) {
    if (ai == null || !ai.isSuccess) return local;
    final data = ai.structuredData;
    final skillGap = CareerSkillGap.fromMap(_asMap(data['skillGap']));
    final roadmap = CareerRoadmapPlan.fromMap(_asMap(data['roadmap']));
    final resume = CareerReviewResult.fromMap(_asMap(data['resumeReview']));
    final portfolio =
        CareerReviewResult.fromMap(_asMap(data['portfolioReview']));
    final market = CareerMarketInsights.fromMap(_asMap(data['marketInsights']));

    final insights = [
      ..._strings(data['insights']),
      ...local.insights,
    ];
    final recommendations = [
      ..._strings(data['recommendations']),
      ..._strings(data['recommendedSkills']),
      ..._strings(data['recommendedCourses']),
      ..._strings(data['courseImprovements']),
      ..._strings(data['recruitmentRecommendations']),
      ...ai.suggestions,
      ...local.recommendations,
    ];

    return CareerIntelligenceReport(
      userId: local.userId,
      role: local.role,
      title: ai.title.isNotEmpty ? ai.title : local.title,
      summary: ai.message.isNotEmpty
          ? ai.message
          : (data['summary']?.toString() ?? local.summary),
      readinessScore: _double(
        data['readinessScore'] ?? data['careerReadiness'],
        local.readinessScore,
      ),
      insights: insights.toSet().take(12).toList(),
      recommendations: recommendations.toSet().take(14).toList(),
      skillGap: skillGap.currentSkills.isEmpty && skillGap.missingSkills.isEmpty
          ? local.skillGap
          : skillGap,
      roadmap: roadmap.days30.isEmpty ? local.roadmap : roadmap,
      resumeReview: resume.summary.isEmpty ? local.resumeReview : resume,
      portfolioReview:
          portfolio.summary.isEmpty ? local.portfolioReview : portfolio,
      marketInsights: market.trendingSkills.isEmpty
          ? local.marketInsights
          : market,
      achievements: local.achievements,
      metrics: {
        ...local.metrics,
        if (data['estimatedSalaryRange'] != null)
          'estimatedSalaryRange': data['estimatedSalaryRange'],
        if (data['recommendedCareerPath'] != null)
          'recommendedCareerPath': data['recommendedCareerPath'],
        if (data['hiringAnalytics'] != null)
          'hiringAnalytics': data['hiringAnalytics'],
        if (data['recommendedServices'] != null)
          'recommendedServices': data['recommendedServices'],
        if (data['pricingSuggestions'] != null)
          'pricingSuggestions': data['pricingSuggestions'],
        if (data['higherPayingSkills'] != null)
          'higherPayingSkills': data['higherPayingSkills'],
        if (data['profileImprovements'] != null)
          'profileImprovements': data['profileImprovements'],
      },
      updatedAt: DateTime.now(),
      aiAvailable: true,
    );
  }

  Future<List<CareerAchievementBadge>> _awardAchievements({
    required String userId,
    required String role,
    required Map<String, dynamic> evidence,
    required double readiness,
  }) async {
    final candidates = <CareerAchievementBadge>[];
    final now = DateTime.now();
    final interview = _asMap(evidence['interviewLab']);
    final learning = _asMap(evidence['learning']);
    final commerce = _asMap(evidence['commerce']);
    final hiring = _asMap(evidence['hiring']);

    if (readiness >= 75) {
      candidates.add(CareerAchievementBadge(
        id: 'job_ready',
        title: 'Job Ready',
        description: 'Career readiness crossed 75%.',
        earnedAt: now,
      ));
    }
    if (_double(interview['averageScore']) >= 80) {
      candidates.add(CareerAchievementBadge(
        id: 'interview_star',
        title: 'Interview Star',
        description: 'Strong Interview Lab performance.',
        earnedAt: now,
      ));
    }
    if (_int(learning['certificates']) >= 3) {
      candidates.add(CareerAchievementBadge(
        id: 'project_champion',
        title: 'Project Champion',
        description: 'Multiple certificates earned.',
        earnedAt: now,
      ));
    }
    if (_int(commerce['completedOrders']) >= 5) {
      candidates.add(CareerAchievementBadge(
        id: 'top_freelancer',
        title: 'Top Freelancer',
        description: 'Completed multiple client orders.',
        earnedAt: now,
      ));
    }
    if (_int(learning['completedCourses']) >= 5 ||
        _int(_asMap(evidence['courses'])['published']) >= 3) {
      if (role == 'teacher') {
        candidates.add(CareerAchievementBadge(
          id: 'top_teacher',
          title: 'Top Teacher',
          description: 'Published impactful learning content.',
          earnedAt: now,
        ));
      }
    }
    if (_strings(_asMap(evidence['profile'])['skills'])
        .any((s) => s.toLowerCase().contains('flutter'))) {
      candidates.add(CareerAchievementBadge(
        id: 'flutter_expert',
        title: 'Flutter Expert',
        description: 'Flutter skill evidenced on profile.',
        earnedAt: now,
      ));
    }
    if (_int(hiring['hired']) >= 1) {
      candidates.add(CareerAchievementBadge(
        id: 'ai_master',
        title: 'AI Master',
        description: 'Successful hiring conversions recorded.',
        earnedAt: now,
      ));
    }

    final awarded = <CareerAchievementBadge>[];
    for (final badge in candidates) {
      final id = '${userId}_${badge.id}';
      final ref = _badgesRef.doc(id);
      final existing = await ref.get();
      if (!existing.exists) {
        await ref.set({
          ...badge.toMap(),
          'userId': userId,
          'role': role,
          'badgeId': badge.id,
        });
      }
      awarded.add(badge);
    }

    final snap =
        await _badgesRef.where('userId', isEqualTo: userId).limit(30).get();
    return snap.docs
        .map((d) => CareerAchievementBadge.fromMap({
              ...d.data(),
              'id': d.data()['badgeId'] ?? d.data()['id'] ?? d.id,
            }))
        .toList();
  }

  double _localReadiness(String role, Map<String, dynamic> evidence) {
    double score = 20;
    final interview = _asMap(evidence['interviewLab']);
    score += (_double(interview['averageScore']) * 0.35).clamp(0, 35);
    if (role == 'student') {
      final learning = _asMap(evidence['learning']);
      score += (_int(learning['completedCourses']) * 4).clamp(0, 20);
      score += (_int(learning['certificates']) * 5).clamp(0, 15);
      score += (_double(_asMap(evidence['resume'])['score']) * 0.2).clamp(0, 20);
    } else if (role == 'freelancer') {
      final commerce = _asMap(evidence['commerce']);
      score += (_int(commerce['completedOrders']) * 4).clamp(0, 25);
      score += (_double(commerce['averageRating']) * 8).clamp(0, 20);
      score += (_int(commerce['services']) * 3).clamp(0, 12);
    } else if (role == 'teacher') {
      final courses = _asMap(evidence['courses']);
      score += (_int(courses['published']) * 8).clamp(0, 40);
      score += (_double(courses['avgEnrollmentsPerCourse']) * 0.5).clamp(0, 25);
    } else if (role == 'company') {
      final hiring = _asMap(evidence['hiring']);
      score += (_int(hiring['hired']) * 10).clamp(0, 30);
      score += (_double(hiring['offerAcceptanceRate']) * 0.3).clamp(0, 30);
      score += (_int(hiring['activeJobs']) * 4).clamp(0, 20);
    }
    return score.clamp(0, 100);
  }

  String _localSummary(
    String role,
    double readiness,
    Map<String, dynamic> evidence,
  ) {
    return 'Evidence-based $role career readiness is ${readiness.toStringAsFixed(0)}%. '
        'Insights combine your SkillForge activity with live market demand from active jobs.';
  }

  List<String> _localInsights(String role, Map<String, dynamic> evidence) {
    final market = _strings(_asMap(evidence['market'])['trendingFromJobs']);
    return [
      if (market.isNotEmpty) 'Top demanded skill right now: ${market.first}',
      'Keep Interview Lab practice consistent to raise readiness.',
      'Refresh portfolio proof every sprint.',
    ];
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  List<String> _strings(Object? value) {
    if (value is Iterable) {
      return value
          .map((e) => e?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const <String>[];
  }

  int _int(Object? value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  double _double(Object? value, [double fallback = 0]) {
    if (value is num) return value.toDouble().clamp(0, 100);
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }
}
