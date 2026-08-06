import 'package:cloud_firestore/cloud_firestore.dart';

class LegalSection {
  final String title;
  final String body;

  const LegalSection({required this.title, required this.body});

  factory LegalSection.fromJson(Map<String, dynamic> json) {
    return LegalSection(
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'title': title, 'body': body};
  }
}

class LegalPolicies {
  final List<LegalSection> privacyPolicy;
  final List<LegalSection> termsOfService;
  final List<LegalSection> accountDeletion;
  final List<LegalSection> returnRefundPolicy;
  final List<LegalSection> shippingServicePolicy;
  final String version;
  final DateTime updatedAt;
  final String updatedBy;

  const LegalPolicies({
    this.privacyPolicy = const [],
    this.termsOfService = const [],
    this.accountDeletion = const [],
    this.returnRefundPolicy = const [],
    this.shippingServicePolicy = const [],
    this.version = '1.0.0',
    required this.updatedAt,
    this.updatedBy = '',
  });

  factory LegalPolicies.fromJson(Map<String, dynamic> json) {
    List<LegalSection> parseSections(String key) {
      return (json[key] as List<dynamic>?)
              ?.map((e) => LegalSection.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
    }

    return LegalPolicies(
      privacyPolicy: parseSections('privacyPolicy'),
      termsOfService: parseSections('termsOfService'),
      accountDeletion: parseSections('accountDeletion'),
      returnRefundPolicy: parseSections('returnRefundPolicy'),
      shippingServicePolicy: parseSections('shippingServicePolicy'),
      version: json['version'] as String? ?? '1.0.0',
      updatedAt: json['updatedAt'] != null
          ? (json['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedBy: json['updatedBy'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'privacyPolicy': privacyPolicy.map((e) => e.toJson()).toList(),
      'termsOfService': termsOfService.map((e) => e.toJson()).toList(),
      'accountDeletion': accountDeletion.map((e) => e.toJson()).toList(),
      'returnRefundPolicy': returnRefundPolicy.map((e) => e.toJson()).toList(),
      'shippingServicePolicy':
          shippingServicePolicy.map((e) => e.toJson()).toList(),
      'version': version,
      'updatedAt': Timestamp.fromDate(updatedAt),
      'updatedBy': updatedBy,
    };
  }

  LegalPolicies copyWith({
    List<LegalSection>? privacyPolicy,
    List<LegalSection>? termsOfService,
    List<LegalSection>? accountDeletion,
    List<LegalSection>? returnRefundPolicy,
    List<LegalSection>? shippingServicePolicy,
    String? version,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return LegalPolicies(
      privacyPolicy: privacyPolicy ?? this.privacyPolicy,
      termsOfService: termsOfService ?? this.termsOfService,
      accountDeletion: accountDeletion ?? this.accountDeletion,
      returnRefundPolicy: returnRefundPolicy ?? this.returnRefundPolicy,
      shippingServicePolicy:
          shippingServicePolicy ?? this.shippingServicePolicy,
      version: version ?? this.version,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }
}
