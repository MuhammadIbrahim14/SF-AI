import 'package:cloud_firestore/cloud_firestore.dart';

String _stringValue(Object? value, [String fallback = '']) {
  return value is String ? value : fallback;
}

int _intValue(Object? value, [int fallback = 1]) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

bool _boolValue(Object? value, [bool fallback = true]) {
  if (value is bool) return value;
  if (value is String) return value.trim().toLowerCase() == 'true';
  return fallback;
}

DateTime _dateValue(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  return DateTime.now();
}

List<String> _stringList(Object? value) {
  if (value is Iterable) {
    return value
        .map((item) => item?.toString() ?? '')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  return const <String>[];
}

class SkillForgeLawModel {
  const SkillForgeLawModel({
    required this.lawId,
    required this.title,
    required this.description,
    required this.caseType,
    required this.appliesWhen,
    required this.requiredEvidence,
    required this.clientRights,
    required this.freelancerRights,
    required this.adminAllowedActions,
    required this.defaultRecommendation,
    required this.priority,
    required this.isActive,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    required this.updatedBy,
  });

  final String lawId;
  final String title;
  final String description;
  final String caseType;
  final String appliesWhen;
  final String requiredEvidence;
  final String clientRights;
  final String freelancerRights;
  final List<String> adminAllowedActions;
  final String defaultRecommendation;
  final int priority;
  final bool isActive;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String updatedBy;

  factory SkillForgeLawModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return SkillForgeLawModel(
      lawId: _stringValue(data['lawId'], doc.id),
      title: _stringValue(data['title']),
      description: _stringValue(data['description']),
      caseType: _stringValue(data['caseType']),
      appliesWhen: _stringValue(data['appliesWhen']),
      requiredEvidence: _stringValue(data['requiredEvidence'], 'none'),
      clientRights: _stringValue(data['clientRights']),
      freelancerRights: _stringValue(data['freelancerRights']),
      adminAllowedActions: _stringList(data['adminAllowedActions']),
      defaultRecommendation: _stringValue(data['defaultRecommendation']),
      priority: _intValue(data['priority']),
      isActive: _boolValue(data['isActive']),
      version: _intValue(data['version']),
      createdAt: _dateValue(data['createdAt']),
      updatedAt: _dateValue(data['updatedAt']),
      updatedBy: _stringValue(data['updatedBy']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lawId': lawId,
      'title': title,
      'description': description,
      'caseType': caseType,
      'appliesWhen': appliesWhen,
      'requiredEvidence': requiredEvidence,
      'clientRights': clientRights,
      'freelancerRights': freelancerRights,
      'adminAllowedActions': adminAllowedActions,
      'defaultRecommendation': defaultRecommendation,
      'priority': priority,
      'isActive': isActive,
      'version': version,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'updatedBy': updatedBy,
    };
  }

  static List<SkillForgeLawModel> defaults(DateTime now) {
    SkillForgeLawModel law(
      String id,
      String title,
      String caseType,
      String appliesWhen,
      String evidence,
      String recommendation,
      int priority,
    ) {
      return SkillForgeLawModel(
        lawId: id,
        title: title,
        description: '$title marketplace rule for sandbox escrow decisions.',
        caseType: caseType,
        appliesWhen: appliesWhen,
        requiredEvidence: evidence,
        clientRights:
            'Client can present claim, request refund, and respond to freelancer evidence.',
        freelancerRights:
            'Freelancer can defend delivery/work proof and dispute unfair refund claims.',
        adminAllowedActions: const [
          'refundToClient',
          'releaseToFreelancer',
          'splitRelease',
          'rejectCase',
          'requestEvidence',
        ],
        defaultRecommendation: recommendation,
        priority: priority,
        isActive: true,
        version: 1,
        createdAt: now,
        updatedAt: now,
        updatedBy: 'system-default',
      );
    }

    return [
      law(
        'law_refund_before_delivery',
        'Refund Before Delivery',
        'refund',
        'beforeDelivery,noDelivery,clientRequestedRefund',
        'freelancer',
        'refundToClient',
        10,
      ),
      law(
        'law_refund_after_delivery',
        'Refund After Delivery',
        'refund',
        'afterDelivery,deliverySubmitted',
        'both',
        'requestEvidence',
        20,
      ),
      law(
        'law_freelancer_disputes_refund',
        'Freelancer Disputes Refund',
        'dispute',
        'freelancerDisputedRefund',
        'freelancer',
        'requestEvidence',
        30,
      ),
      law(
        'law_split_settlement',
        'Split Settlement',
        'dispute',
        'partialWork',
        'both',
        'splitRelease',
        40,
      ),
    ];
  }
}
