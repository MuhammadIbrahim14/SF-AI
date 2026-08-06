import 'package:cloud_firestore/cloud_firestore.dart';

String _stringValue(Object? value, [String fallback = '']) {
  return value is String ? value : fallback;
}

double _doubleValue(Object? value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

int _intValue(Object? value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

bool _boolValue(Object? value, [bool fallback = false]) {
  if (value is bool) return value;
  if (value is String) return value.trim().toLowerCase() == 'true';
  return fallback;
}

DateTime? _nullableDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  return null;
}

DateTime _dateValue(Object? value) => _nullableDate(value) ?? DateTime.now();

List<String> _stringList(Object? value) {
  if (value is Iterable) {
    return value
        .map((item) => item?.toString() ?? '')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  if (value is String) {
    return value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  return const <String>[];
}

class FreelancerServiceStatus {
  const FreelancerServiceStatus._();

  static const String draft = 'draft';
  static const String published = 'published';
  static const String hidden = 'hidden';

  static const Set<String> values = {draft, published, hidden};

  static String normalize(String? value) {
    final normalized = (value ?? draft).trim().toLowerCase();
    return values.contains(normalized) ? normalized : draft;
  }
}

class FreelancerServicePricingType {
  const FreelancerServicePricingType._();

  static const String fixed = 'fixed';
  static const String hourly = 'hourly';

  static const Set<String> values = {fixed, hourly};

  static String normalize(String? value) {
    final normalized = (value ?? fixed).trim().toLowerCase();
    return values.contains(normalized) ? normalized : fixed;
  }
}

class ServicePackageModel {
  const ServicePackageModel({
    required this.packageId,
    required this.title,
    required this.description,
    required this.price,
    required this.deliveryDays,
    required this.revisionsIncluded,
    required this.isActive,
  });

  final String packageId;
  final String title;
  final String description;
  final double price;
  final int deliveryDays;
  final int revisionsIncluded;
  final bool isActive;

  factory ServicePackageModel.fromMap(Map<String, dynamic> data) {
    return ServicePackageModel(
      packageId: _stringValue(data['packageId']),
      title: _stringValue(data['title'], 'Standard'),
      description: _stringValue(data['description']),
      price: _doubleValue(data['price']),
      deliveryDays: _intValue(data['deliveryDays'], 7).clamp(1, 365).toInt(),
      revisionsIncluded: _intValue(
        data['revisionsIncluded'],
        1,
      ).clamp(0, 20).toInt(),
      isActive: _boolValue(data['isActive'], true),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'packageId': packageId,
      'title': title,
      'description': description,
      'price': price,
      'deliveryDays': deliveryDays,
      'revisionsIncluded': revisionsIncluded,
      'isActive': isActive,
    };
  }
}

List<ServicePackageModel> _packageList(Object? value) {
  if (value is Iterable) {
    return value
        .whereType<Map>()
        .map(
          (item) =>
              ServicePackageModel.fromMap(Map<String, dynamic>.from(item)),
        )
        .where((item) => item.price > 0 && item.deliveryDays >= 1)
        .toList();
  }
  return const <ServicePackageModel>[];
}

class FreelancerServiceModel {
  const FreelancerServiceModel({
    required this.serviceId,
    required this.freelancerId,
    required this.freelancerName,
    required this.freelancerAvatarUrl,
    required this.title,
    required this.shortDescription,
    required this.fullDescription,
    required this.category,
    required this.tags,
    required this.pricingType,
    required this.startingPrice,
    required this.estimatedDelivery,
    required this.packages,
    required this.currency,
    required this.coverImageUrl,
    required this.galleryUrls,
    required this.portfolioLinks,
    required this.linkedCertificateIds,
    required this.linkedSkills,
    required this.skillScore,
    required this.verifiedBadge,
    required this.status,
    required this.isPublished,
    required this.createdAt,
    required this.updatedAt,
    required this.publishedAt,
    required this.viewCount,
    required this.inquiryCount,
  });

  final String serviceId;
  final String freelancerId;
  final String freelancerName;
  final String freelancerAvatarUrl;
  final String title;
  final String shortDescription;
  final String fullDescription;
  final String category;
  final List<String> tags;
  final String pricingType;
  final double startingPrice;
  final String estimatedDelivery;
  final List<ServicePackageModel> packages;
  final String currency;
  final String coverImageUrl;
  final List<String> galleryUrls;
  final List<String> portfolioLinks;
  final List<String> linkedCertificateIds;
  final List<String> linkedSkills;
  final double skillScore;
  final bool verifiedBadge;
  final String status;
  final bool isPublished;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? publishedAt;
  final int viewCount;
  final int inquiryCount;

  bool get isDraft => status == FreelancerServiceStatus.draft;
  bool get isHidden => status == FreelancerServiceStatus.hidden;
  bool get isLive => status == FreelancerServiceStatus.published && isPublished;
  List<ServicePackageModel> get activePackages {
    final active = packages.where((item) => item.isActive).toList();
    return active.isNotEmpty ? active : legacyPackages;
  }

  List<ServicePackageModel> get legacyPackages {
    final deliveryDays = _deliveryDaysFromText(estimatedDelivery);
    final price = startingPrice > 0 ? startingPrice : 0.0;
    return [
      ServicePackageModel(
        packageId: 'legacy_standard',
        title: 'Standard',
        description: estimatedDelivery.trim().isEmpty
            ? 'Legacy service package'
            : 'Legacy service package - $estimatedDelivery',
        price: price,
        deliveryDays: deliveryDays,
        revisionsIncluded: 1,
        isActive: true,
      ),
    ];
  }

  factory FreelancerServiceModel.empty({
    required String freelancerId,
    required String freelancerName,
    String freelancerAvatarUrl = '',
  }) {
    final now = DateTime.now();
    return FreelancerServiceModel(
      serviceId: '',
      freelancerId: freelancerId,
      freelancerName: freelancerName,
      freelancerAvatarUrl: freelancerAvatarUrl,
      title: '',
      shortDescription: '',
      fullDescription: '',
      category: '',
      tags: const [],
      pricingType: FreelancerServicePricingType.fixed,
      startingPrice: 0,
      estimatedDelivery: '',
      packages: const [],
      currency: 'USD',
      coverImageUrl: '',
      galleryUrls: const [],
      portfolioLinks: const [],
      linkedCertificateIds: const [],
      linkedSkills: const [],
      skillScore: 0,
      verifiedBadge: false,
      status: FreelancerServiceStatus.draft,
      isPublished: false,
      createdAt: now,
      updatedAt: now,
      publishedAt: null,
      viewCount: 0,
      inquiryCount: 0,
    );
  }

  factory FreelancerServiceModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final status = FreelancerServiceStatus.normalize(
      data['status']?.toString(),
    );
    return FreelancerServiceModel(
      serviceId: _stringValue(data['serviceId'], doc.id),
      freelancerId: _stringValue(data['freelancerId']),
      freelancerName: _stringValue(data['freelancerName']),
      freelancerAvatarUrl: _stringValue(data['freelancerAvatarUrl']),
      title: _stringValue(data['title']),
      shortDescription: _stringValue(data['shortDescription']),
      fullDescription: _stringValue(data['fullDescription']),
      category: _stringValue(data['category']),
      tags: _stringList(data['tags']),
      pricingType: FreelancerServicePricingType.normalize(
        data['pricingType']?.toString(),
      ),
      startingPrice: _doubleValue(data['startingPrice']),
      estimatedDelivery: _stringValue(data['estimatedDelivery']),
      packages: _packageList(data['packages']),
      currency: _stringValue(data['currency'], 'USD'),
      coverImageUrl: _stringValue(data['coverImageUrl']),
      galleryUrls: _stringList(data['galleryUrls']),
      portfolioLinks: _stringList(data['portfolioLinks']),
      linkedCertificateIds: _stringList(data['linkedCertificateIds']),
      linkedSkills: _stringList(data['linkedSkills']),
      skillScore: _doubleValue(data['skillScore']).clamp(0, 100).toDouble(),
      verifiedBadge: _boolValue(data['verifiedBadge']),
      status: status,
      isPublished: _boolValue(
        data['isPublished'],
        status == FreelancerServiceStatus.published,
      ),
      createdAt: _dateValue(data['createdAt']),
      updatedAt: _dateValue(data['updatedAt']),
      publishedAt: _nullableDate(data['publishedAt']),
      viewCount: _intValue(data['viewCount']),
      inquiryCount: _intValue(data['inquiryCount']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'serviceId': serviceId,
      'freelancerId': freelancerId,
      'freelancerName': freelancerName,
      'freelancerAvatarUrl': freelancerAvatarUrl,
      'title': title,
      'shortDescription': shortDescription,
      'fullDescription': fullDescription,
      'category': category,
      'tags': tags,
      'pricingType': FreelancerServicePricingType.normalize(pricingType),
      'startingPrice': startingPrice,
      'estimatedDelivery': estimatedDelivery,
      'packages': packages.map((item) => item.toJson()).toList(),
      'currency': currency,
      'coverImageUrl': coverImageUrl,
      'galleryUrls': galleryUrls,
      'portfolioLinks': portfolioLinks,
      'linkedCertificateIds': linkedCertificateIds,
      'linkedSkills': linkedSkills,
      'skillScore': skillScore.clamp(0, 100),
      'verifiedBadge': verifiedBadge,
      'status': FreelancerServiceStatus.normalize(status),
      'isPublished': isPublished,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (publishedAt != null) 'publishedAt': Timestamp.fromDate(publishedAt!),
      'viewCount': viewCount,
      'inquiryCount': inquiryCount,
    };
  }

  FreelancerServiceModel copyWith({
    String? serviceId,
    String? freelancerId,
    String? freelancerName,
    String? freelancerAvatarUrl,
    String? title,
    String? shortDescription,
    String? fullDescription,
    String? category,
    List<String>? tags,
    String? pricingType,
    double? startingPrice,
    String? estimatedDelivery,
    List<ServicePackageModel>? packages,
    String? currency,
    String? coverImageUrl,
    List<String>? galleryUrls,
    List<String>? portfolioLinks,
    List<String>? linkedCertificateIds,
    List<String>? linkedSkills,
    double? skillScore,
    bool? verifiedBadge,
    String? status,
    bool? isPublished,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? publishedAt,
    bool clearPublishedAt = false,
    int? viewCount,
    int? inquiryCount,
  }) {
    return FreelancerServiceModel(
      serviceId: serviceId ?? this.serviceId,
      freelancerId: freelancerId ?? this.freelancerId,
      freelancerName: freelancerName ?? this.freelancerName,
      freelancerAvatarUrl: freelancerAvatarUrl ?? this.freelancerAvatarUrl,
      title: title ?? this.title,
      shortDescription: shortDescription ?? this.shortDescription,
      fullDescription: fullDescription ?? this.fullDescription,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      pricingType: pricingType ?? this.pricingType,
      startingPrice: startingPrice ?? this.startingPrice,
      estimatedDelivery: estimatedDelivery ?? this.estimatedDelivery,
      packages: packages ?? this.packages,
      currency: currency ?? this.currency,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      galleryUrls: galleryUrls ?? this.galleryUrls,
      portfolioLinks: portfolioLinks ?? this.portfolioLinks,
      linkedCertificateIds: linkedCertificateIds ?? this.linkedCertificateIds,
      linkedSkills: linkedSkills ?? this.linkedSkills,
      skillScore: skillScore ?? this.skillScore,
      verifiedBadge: verifiedBadge ?? this.verifiedBadge,
      status: FreelancerServiceStatus.normalize(status ?? this.status),
      isPublished: isPublished ?? this.isPublished,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      publishedAt: clearPublishedAt ? null : publishedAt ?? this.publishedAt,
      viewCount: viewCount ?? this.viewCount,
      inquiryCount: inquiryCount ?? this.inquiryCount,
    );
  }
}

int _deliveryDaysFromText(String value) {
  final match = RegExp(r'\d+').firstMatch(value);
  final parsed = int.tryParse(match?.group(0) ?? '') ?? 7;
  return parsed.clamp(1, 365).toInt();
}
