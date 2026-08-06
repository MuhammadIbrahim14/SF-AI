import 'package:cloud_firestore/cloud_firestore.dart';

DateTime _date(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  return DateTime.now();
}

/// Dynamically awarded Interview Lab badge (practice only — not hiring).
class InterviewLabBadgeModel {
  const InterviewLabBadgeModel({
    required this.badgeId,
    required this.candidateId,
    required this.badgeKey,
    required this.title,
    required this.description,
    required this.awardedAt,
    this.sessionId,
    this.roleTrack,
    this.metadata = const {},
  });

  final String badgeId;
  final String candidateId;
  final String badgeKey;
  final String title;
  final String description;
  final String? sessionId;
  final String? roleTrack;
  final DateTime awardedAt;
  final Map<String, dynamic> metadata;

  factory InterviewLabBadgeModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return InterviewLabBadgeModel(
      badgeId: data['badgeId']?.toString() ?? doc.id,
      candidateId: data['candidateId']?.toString() ?? '',
      badgeKey: data['badgeKey']?.toString() ?? '',
      title: data['title']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      sessionId: data['sessionId']?.toString(),
      roleTrack: data['roleTrack']?.toString(),
      awardedAt: _date(data['awardedAt']),
      metadata: Map<String, dynamic>.from(
        (data['metadata'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
    );
  }

  Map<String, dynamic> toMap({bool useServerTimestamps = true}) => {
        'badgeId': badgeId,
        'candidateId': candidateId,
        'badgeKey': badgeKey,
        'title': title,
        'description': description,
        'sessionId': sessionId,
        'roleTrack': roleTrack,
        'awardedAt': useServerTimestamps
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(awardedAt),
        'metadata': metadata,
        'module': 'interview_lab',
      };
}

/// Long-term practice analytics per candidate (`interview_progress/{uid}`).
class InterviewLabProgressModel {
  const InterviewLabProgressModel({
    required this.candidateId,
    required this.updatedAt,
    this.completedInterviews = 0,
    this.averageOverall = 0,
    this.skillAverages = const {},
    this.skillTrends = const {},
    this.trackAverages = const {},
    this.insights = const [],
    this.lastSessionId,
    this.lastInterviewLevel,
  });

  final String candidateId;
  final int completedInterviews;
  final double averageOverall;
  final Map<String, double> skillAverages;
  final Map<String, List<double>> skillTrends;
  final Map<String, double> trackAverages;
  final List<String> insights;
  final String? lastSessionId;
  final String? lastInterviewLevel;
  final DateTime updatedAt;

  static InterviewLabProgressModel empty(String candidateId) =>
      InterviewLabProgressModel(
        candidateId: candidateId,
        updatedAt: DateTime.now(),
      );

  factory InterviewLabProgressModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final trendsRaw = data['skillTrends'];
    final trends = <String, List<double>>{};
    if (trendsRaw is Map) {
      for (final e in trendsRaw.entries) {
        final list = e.value;
        if (list is List) {
          trends[e.key.toString()] = list
              .map((v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0)
              .toList();
        }
      }
    }
    final skillAvg = <String, double>{};
    final skillRaw = data['skillAverages'];
    if (skillRaw is Map) {
      for (final e in skillRaw.entries) {
        skillAvg[e.key.toString()] =
            e.value is num ? (e.value as num).toDouble() : 0;
      }
    }
    final trackAvg = <String, double>{};
    final trackRaw = data['trackAverages'];
    if (trackRaw is Map) {
      for (final e in trackRaw.entries) {
        trackAvg[e.key.toString()] =
            e.value is num ? (e.value as num).toDouble() : 0;
      }
    }
    return InterviewLabProgressModel(
      candidateId: data['candidateId']?.toString() ?? doc.id,
      completedInterviews: (data['completedInterviews'] as num?)?.toInt() ?? 0,
      averageOverall: (data['averageOverall'] as num?)?.toDouble() ?? 0,
      skillAverages: skillAvg,
      skillTrends: trends,
      trackAverages: trackAvg,
      insights: (data['insights'] as List?)
              ?.map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList() ??
          const [],
      lastSessionId: data['lastSessionId']?.toString(),
      lastInterviewLevel: data['lastInterviewLevel']?.toString(),
      updatedAt: _date(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap({bool useServerTimestamps = true}) => {
        'candidateId': candidateId,
        'completedInterviews': completedInterviews,
        'averageOverall': averageOverall,
        'skillAverages': skillAverages,
        'skillTrends': skillTrends,
        'trackAverages': trackAverages,
        'insights': insights,
        'lastSessionId': lastSessionId,
        'lastInterviewLevel': lastInterviewLevel,
        'updatedAt': useServerTimestamps
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(updatedAt),
        'module': 'interview_lab',
      };
}
