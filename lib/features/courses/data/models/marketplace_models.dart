import 'package:cloud_firestore/cloud_firestore.dart';

// ==================== HELPERS ====================
String _stringValue(Object? value, [String fallback = '']) {
  return value is String ? value : fallback;
}

double _doubleValue(Object? value, [double fallback = 0.0]) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

bool _boolValue(Object? value, [bool fallback = false]) {
  if (value is bool) return value;
  if (value is String) return value.toLowerCase().trim() == 'true';
  if (value is num) return value != 0;
  return fallback;
}

DateTime _dateValue(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  return DateTime.now();
}

// ==================== PAID COURSE CONFIG ====================
/// Configuration for a paid course listing
class PaidCourseConfig {
  const PaidCourseConfig({
    required this.courseId,
    required this.isPaid,
    required this.price,
    required this.currency,
    required this.discount,
    required this.discountType, // 'percentage' or 'fixed'
    required this.thumbnailUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  final String courseId;
  final bool isPaid;
  final double price;
  final String currency;
  final double discount;
  final String discountType; // 'percentage' or 'fixed'
  final String? thumbnailUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  double get discountedPrice {
    if (discountType == 'percentage') {
      return price * (1 - (discount / 100));
    }
    return (price - discount).clamp(0.0, double.infinity);
  }

  double get discountAmount {
    if (discountType == 'percentage') {
      return price * (discount / 100);
    }
    return discount;
  }

  bool get hasDiscount => discount > 0;

  factory PaidCourseConfig.free(String courseId) {
    final now = DateTime.now();
    return PaidCourseConfig(
      courseId: courseId,
      isPaid: false,
      price: 0,
      currency: 'USD',
      discount: 0,
      discountType: 'percentage',
      thumbnailUrl: null,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory PaidCourseConfig.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return PaidCourseConfig(
      courseId: data['courseId'] is String ? data['courseId'] as String : doc.id,
      isPaid: _boolValue(data['isPaid'], false),
      price: _doubleValue(data['price'], 0),
      currency: _stringValue(data['currency'], 'USD'),
      discount: _doubleValue(data['discount'], 0),
      discountType: _stringValue(data['discountType'], 'percentage'),
      thumbnailUrl: _stringValue(data['thumbnailUrl']).isEmpty
          ? null
          : _stringValue(data['thumbnailUrl']),
      createdAt: _dateValue(data['createdAt']),
      updatedAt: _dateValue(data['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'courseId': courseId,
      'isPaid': isPaid,
      'price': price,
      'currency': currency,
      'discount': discount,
      'discountType': discountType,
      if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty)
        'thumbnailUrl': thumbnailUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  PaidCourseConfig copyWith({
    String? courseId,
    bool? isPaid,
    double? price,
    String? currency,
    double? discount,
    String? discountType,
    String? thumbnailUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearThumbnail = false,
  }) {
    return PaidCourseConfig(
      courseId: courseId ?? this.courseId,
      isPaid: isPaid ?? this.isPaid,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      discount: discount ?? this.discount,
      discountType: discountType ?? this.discountType,
      thumbnailUrl: clearThumbnail ? null : (thumbnailUrl ?? this.thumbnailUrl),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// ==================== COURSE PURCHASE ====================
/// Records a student's purchase of a paid course
class CoursePurchase {
  const CoursePurchase({
    required this.purchaseId,
    required this.courseId,
    required this.studentId,
    required this.teacherId,
    required this.price,
    required this.discountAmount,
    required this.finalAmount,
    this.platformFee = 0,
    required this.currency,
    required this.purchasedAt,
    required this.enrollmentId,
    this.transactionReference,
    this.paymentMethod = 'skillforge_gateway',
    this.provider = '',
  });

  final String purchaseId;
  final String courseId;
  final String studentId;
  final String teacherId;
  final double price;
  final double discountAmount;

  /// Amount retained by SkillForge from this sale.
  final double platformFee;

  /// Net amount credited to the teacher after [platformFee].
  final double finalAmount;
  final String currency;
  final DateTime purchasedAt;
  final String enrollmentId;
  final String? transactionReference;
  final String paymentMethod;

  /// Checkout provider that produced the sale (`stripe`, `skillforge_demo`, …),
  /// written by the gateway as `provider`/`gateway`. Empty on legacy rows.
  final String provider;

  factory CoursePurchase.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return CoursePurchase(
      purchaseId: data['purchaseId'] is String ? data['purchaseId'] as String : doc.id,
      courseId: _stringValue(data['courseId']),
      studentId: _stringValue(data['studentId']),
      teacherId: _stringValue(data['teacherId']),
      price: _doubleValue(data['price']),
      discountAmount: _doubleValue(data['discountAmount']),
      finalAmount: _doubleValue(data['finalAmount']),
      platformFee: _doubleValue(data['platformFee']),
      currency: _stringValue(data['currency'], 'USD'),
      purchasedAt: _dateValue(data['purchasedAt']),
      enrollmentId: _stringValue(data['enrollmentId']),
      transactionReference:
          _stringValue(data['transactionReference']).isEmpty
              ? null
              : _stringValue(data['transactionReference']),
      paymentMethod: _stringValue(data['paymentMethod'], 'skillforge_gateway'),
      provider: _stringValue(data['provider']).isNotEmpty
          ? _stringValue(data['provider'])
          : _stringValue(data['gateway']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'purchaseId': purchaseId,
      'courseId': courseId,
      'studentId': studentId,
      'teacherId': teacherId,
      'price': price,
      'discountAmount': discountAmount,
      'finalAmount': finalAmount,
      'platformFee': platformFee,
      'currency': currency,
      'purchasedAt': Timestamp.fromDate(purchasedAt),
      'enrollmentId': enrollmentId,
      if (transactionReference != null && transactionReference!.isNotEmpty)
        'transactionReference': transactionReference,
      'paymentMethod': paymentMethod,
      if (provider.isNotEmpty) 'provider': provider,
    };
  }
}

// ==================== MARKETPLACE CONFIGURATION ====================
/// Admin-controlled marketplace settings
class MarketplaceConfig {
  const MarketplaceConfig({
    required this.maxPrice,
    required this.minPrice,
    required this.supportedCurrencies,
    required this.paidCoursesEnabled,
    required this.platformCommissionPercent,
    required this.createdAt,
    required this.updatedAt,
  });

  final double maxPrice;
  final double minPrice;
  final List<String> supportedCurrencies;
  final bool paidCoursesEnabled;
  final double platformCommissionPercent;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory MarketplaceConfig.defaults() {
    final now = DateTime.now();
    return MarketplaceConfig(
      maxPrice: 999.99,
      minPrice: 0.99,
      supportedCurrencies: ['USD', 'EUR', 'GBP', 'PKR', 'INR'],
      paidCoursesEnabled: true,
      platformCommissionPercent: 20,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory MarketplaceConfig.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return MarketplaceConfig(
      maxPrice: _doubleValue(data['maxPrice'], 999.99),
      minPrice: _doubleValue(data['minPrice'], 0.99),
      supportedCurrencies:
          data['supportedCurrencies'] is List
              ? List<String>.from(
                  (data['supportedCurrencies'] as List).map((e) => e.toString()),
                )
              : ['USD'],
      paidCoursesEnabled: _boolValue(data['paidCoursesEnabled'], true),
      platformCommissionPercent:
          _doubleValue(data['platformCommissionPercent'], 20),
      createdAt: _dateValue(data['createdAt']),
      updatedAt: _dateValue(data['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'maxPrice': maxPrice,
      'minPrice': minPrice,
      'supportedCurrencies': supportedCurrencies,
      'paidCoursesEnabled': paidCoursesEnabled,
      'platformCommissionPercent': platformCommissionPercent,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  MarketplaceConfig copyWith({
    double? maxPrice,
    double? minPrice,
    List<String>? supportedCurrencies,
    bool? paidCoursesEnabled,
    double? platformCommissionPercent,
    DateTime? updatedAt,
  }) {
    return MarketplaceConfig(
      maxPrice: maxPrice ?? this.maxPrice,
      minPrice: minPrice ?? this.minPrice,
      supportedCurrencies: supportedCurrencies ?? this.supportedCurrencies,
      paidCoursesEnabled: paidCoursesEnabled ?? this.paidCoursesEnabled,
      platformCommissionPercent:
          platformCommissionPercent ?? this.platformCommissionPercent,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool isValidPrice(double price) =>
      price >= minPrice && price <= maxPrice;
}

// ==================== PURCHASE VALIDATION RESULT ====================
class PurchaseValidationResult {
  const PurchaseValidationResult({
    required this.isValid,
    required this.message,
    this.errorCode,
  });

  final bool isValid;
  final String message;
  final String? errorCode;

  factory PurchaseValidationResult.success(String message) {
    return PurchaseValidationResult(
      isValid: true,
      message: message,
    );
  }

  factory PurchaseValidationResult.error(String message, [String? errorCode]) {
    return PurchaseValidationResult(
      isValid: false,
      message: message,
      errorCode: errorCode,
    );
  }
}

// ==================== PAYMENT PROCESSING RESULT ====================
class PaymentProcessingResult {
  const PaymentProcessingResult({
    required this.success,
    required this.message,
    this.transactionReference,
    this.errorCode,
  });

  final bool success;
  final String message;
  final String? transactionReference;
  final String? errorCode;

  factory PaymentProcessingResult.success(
    String message, [
    String? transactionReference,
  ]) {
    return PaymentProcessingResult(
      success: true,
      message: message,
      transactionReference: transactionReference,
    );
  }

  factory PaymentProcessingResult.failure(String message, [String? errorCode]) {
    return PaymentProcessingResult(
      success: false,
      message: message,
      errorCode: errorCode,
    );
  }
}
