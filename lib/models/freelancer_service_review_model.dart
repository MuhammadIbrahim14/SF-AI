import 'package:cloud_firestore/cloud_firestore.dart';

String _stringValue(Object? value, [String fallback = '']) {
  return value is String ? value : fallback;
}

int _intValue(Object? value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

bool _boolValue(Object? value, [bool fallback = true]) {
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

class FreelancerServiceReviewModel {
  const FreelancerServiceReviewModel({
    required this.reviewId,
    required this.serviceRequestId,
    required this.serviceId,
    required this.freelancerId,
    required this.clientId,
    required this.clientName,
    required this.rating,
    required this.comment,
    required this.createdAt,
    required this.updatedAt,
    required this.isVisible,
    required this.serviceTitle,
  });

  final String reviewId;
  final String serviceRequestId;
  final String serviceId;
  final String freelancerId;
  final String clientId;
  final String clientName;
  final int rating;
  final String comment;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isVisible;
  final String? serviceTitle;

  factory FreelancerServiceReviewModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return FreelancerServiceReviewModel(
      reviewId: _stringValue(data['reviewId'], doc.id),
      serviceRequestId: _stringValue(data['serviceRequestId'], doc.id),
      serviceId: _stringValue(data['serviceId']),
      freelancerId: _stringValue(data['freelancerId']),
      clientId: _stringValue(data['clientId']),
      clientName: _stringValue(data['clientName'], 'SkillForge Client'),
      rating: _intValue(data['rating'], 5).clamp(1, 5),
      comment: _stringValue(data['comment']),
      createdAt: _dateValue(data['createdAt']),
      updatedAt: _dateValue(data['updatedAt']),
      isVisible: _boolValue(data['isVisible']),
      serviceTitle: data['serviceTitle'] is String
          ? data['serviceTitle'] as String
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reviewId': reviewId,
      'serviceRequestId': serviceRequestId,
      'serviceId': serviceId,
      'freelancerId': freelancerId,
      'clientId': clientId,
      'clientName': clientName,
      'rating': rating.clamp(1, 5),
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isVisible': isVisible,
      if ((serviceTitle ?? '').trim().isNotEmpty) 'serviceTitle': serviceTitle,
    };
  }

  FreelancerServiceReviewModel copyWith({
    String? reviewId,
    String? serviceRequestId,
    String? serviceId,
    String? freelancerId,
    String? clientId,
    String? clientName,
    int? rating,
    String? comment,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isVisible,
    String? serviceTitle,
  }) {
    return FreelancerServiceReviewModel(
      reviewId: reviewId ?? this.reviewId,
      serviceRequestId: serviceRequestId ?? this.serviceRequestId,
      serviceId: serviceId ?? this.serviceId,
      freelancerId: freelancerId ?? this.freelancerId,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isVisible: isVisible ?? this.isVisible,
      serviceTitle: serviceTitle ?? this.serviceTitle,
    );
  }
}

class ReviewSummary {
  const ReviewSummary({required this.averageRating, required this.reviewCount});

  final double averageRating;
  final int reviewCount;

  bool get hasReviews => reviewCount > 0;

  static const empty = ReviewSummary(averageRating: 0, reviewCount: 0);
}
