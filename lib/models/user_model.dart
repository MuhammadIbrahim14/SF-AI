import 'package:cloud_firestore/cloud_firestore.dart';

import 'user_role.dart';

String _stringValue(Object? value, [String fallback = '']) =>
    value is String ? value : fallback;

List<String> _stringList(Object? value) {
  if (value is String && value.trim().isNotEmpty) return [value.trim()];
  if (value is Iterable) {
    return value
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  return const [];
}

int _intValue(Object? value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

bool _boolValue(Object? value, [bool fallback = false]) {
  if (value is bool) return value;
  if (value is String) return bool.tryParse(value) ?? fallback;
  return fallback;
}

DateTime? _dateValue(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  }
  return null;
}

/// SkillForge AI — User Data Model
/// Represents a user document stored in Firestore `users/{uid}`.
class UserAccountType {
  const UserAccountType._();

  static const String professional = 'professional';
  static const String customer = 'customer';

  static String normalize(String? value) {
    final normalized = (value ?? professional).trim().toLowerCase();
    return normalized == customer ? customer : professional;
  }
}

class UserModel {
  const UserModel({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.roles,
    this.primaryRole,
    this.accountType = UserAccountType.professional,
    required this.status,
    required this.createdAt,
    this.photoUrl,
    this.phone = '',
    this.gender = '',
    this.dateOfBirth,
    this.country = '',
    this.city = '',
    this.bio = '',
    this.profileCompleted = 0,
    this.onboardingCompleted = false,
    this.privacyAccepted = false,
    this.privacyAcceptedAt,
    this.termsAccepted = false,
    this.termsAcceptedAt,
    this.isSystemOwner = false,
    this.lastLogin,
    this.freelancerUnlocked = false,
    this.freelancerUnlockedAt,
  });

  final String uid;
  final String fullName;
  final String email;
  final List<String> roles;
  final String? primaryRole;
  final String accountType;
  final String status;
  final DateTime createdAt;
  final String? photoUrl;
  final String phone;
  final String gender;
  final DateTime? dateOfBirth;
  final String country;
  final String city;
  final String bio;
  final int profileCompleted;
  final bool onboardingCompleted;
  final bool privacyAccepted;
  final DateTime? privacyAcceptedAt;
  final bool termsAccepted;
  final DateTime? termsAcceptedAt;
  final bool isSystemOwner;
  final DateTime? lastLogin;
  final bool freelancerUnlocked;
  final DateTime? freelancerUnlockedAt;

  /// Factory: from Firestore Document
  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};

    // Backward compatibility: support legacy field `name`.
    final fullName = _stringValue(data['fullName'], _stringValue(data['name']));

    final roles = _stringList(data['roles']);
    final primaryRole = data['primaryRole'] is String
        ? (data['primaryRole'] as String).trim()
        : roles.isNotEmpty
        ? roles.first
        : null;
    final accountType = UserAccountType.normalize(
      data['accountType']?.toString(),
    );

    return UserModel(
      uid: doc.id,
      fullName: fullName,
      email: _stringValue(data['email']),
      roles: roles,
      primaryRole: primaryRole,
      accountType: accountType,
      status: _stringValue(data['status'], 'active'),
      createdAt: _dateValue(data['createdAt']) ?? DateTime.now(),
      photoUrl: data['profileImage'] is String
          ? data['profileImage'] as String
          : data['photoUrl'] is String
          ? data['photoUrl'] as String
          : null,
      phone: _stringValue(data['phone'], _stringValue(data['phoneNumber'])),
      gender: _stringValue(data['gender']),
      dateOfBirth: _dateValue(data['dateOfBirth']),
      country: _stringValue(data['country']),
      city: _stringValue(data['city']),
      bio: _stringValue(data['bio']),
      profileCompleted: _intValue(data['profileCompleted']),
      onboardingCompleted: _boolValue(data['onboardingCompleted']),
      privacyAccepted: _boolValue(data['privacyAccepted']),
      privacyAcceptedAt: _dateValue(data['privacyAcceptedAt']),
      termsAccepted: _boolValue(data['termsAccepted']),
      termsAcceptedAt: _dateValue(data['termsAcceptedAt']),
      isSystemOwner: _boolValue(data['isSystemOwner']),
      lastLogin: _dateValue(data['lastLogin']),
      freelancerUnlocked: _boolValue(data['freelancerUnlocked']),
      freelancerUnlockedAt: _dateValue(data['freelancerUnlockedAt']),
    );
  }

  /// Factory: from JSON Map
  factory UserModel.fromJson(Map<String, dynamic> json) {
    final fullName = _stringValue(json['fullName'], _stringValue(json['name']));

    final roles = _stringList(json['roles']);
    final primaryRole = json['primaryRole'] is String
        ? (json['primaryRole'] as String).trim()
        : roles.isNotEmpty
        ? roles.first
        : null;
    final accountType = UserAccountType.normalize(
      json['accountType']?.toString(),
    );

    return UserModel(
      uid: _stringValue(json['uid']),
      fullName: fullName,
      email: _stringValue(json['email']),
      roles: roles,
      primaryRole: primaryRole,
      accountType: accountType,
      status: _stringValue(json['status'], 'active'),
      createdAt: _dateValue(json['createdAt']) ?? DateTime.now(),
      photoUrl: json['profileImage'] is String
          ? json['profileImage'] as String
          : json['photoUrl'] is String
          ? json['photoUrl'] as String
          : null,
      phone: _stringValue(json['phone'], _stringValue(json['phoneNumber'])),
      gender: _stringValue(json['gender']),
      dateOfBirth: _dateValue(json['dateOfBirth']),
      country: _stringValue(json['country']),
      city: _stringValue(json['city']),
      bio: _stringValue(json['bio']),
      profileCompleted: _intValue(json['profileCompleted']),
      onboardingCompleted: _boolValue(json['onboardingCompleted']),
      privacyAccepted: _boolValue(json['privacyAccepted']),
      privacyAcceptedAt: _dateValue(json['privacyAcceptedAt']),
      termsAccepted: _boolValue(json['termsAccepted']),
      termsAcceptedAt: _dateValue(json['termsAcceptedAt']),
      isSystemOwner: _boolValue(json['isSystemOwner']),
      lastLogin: _dateValue(json['lastLogin']),
      freelancerUnlocked: _boolValue(json['freelancerUnlocked']),
      freelancerUnlockedAt: _dateValue(json['freelancerUnlockedAt']),
    );
  }

  /// Serialization
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'fullName': fullName,
      'email': email,
      'roles': roles,
      'primaryRole': primaryRole,
      'accountType': accountType,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'profileImage': photoUrl,
      'photoUrl': photoUrl,
      'phone': phone,
      'gender': gender,
      if (dateOfBirth != null) 'dateOfBirth': Timestamp.fromDate(dateOfBirth!),
      'country': country,
      'city': city,
      'bio': bio,
      'profileCompleted': profileCompleted,
      'onboardingCompleted': onboardingCompleted,
      'privacyAccepted': privacyAccepted,
      if (privacyAcceptedAt != null)
        'privacyAcceptedAt': Timestamp.fromDate(privacyAcceptedAt!),
      'termsAccepted': termsAccepted,
      if (termsAcceptedAt != null)
        'termsAcceptedAt': Timestamp.fromDate(termsAcceptedAt!),
      'isSystemOwner': isSystemOwner,
      if (lastLogin != null) 'lastLogin': Timestamp.fromDate(lastLogin!),
      'freelancerUnlocked': freelancerUnlocked,
      if (freelancerUnlockedAt != null)
        'freelancerUnlockedAt': Timestamp.fromDate(freelancerUnlockedAt!),
    };
  }

  /// Copy With
  UserModel copyWith({
    String? uid,
    String? fullName,
    String? email,
    List<String>? roles,
    String? primaryRole,
    String? accountType,
    String? status,
    DateTime? createdAt,
    String? photoUrl,
    String? phone,
    String? gender,
    DateTime? dateOfBirth,
    String? country,
    String? city,
    String? bio,
    int? profileCompleted,
    bool? onboardingCompleted,
    bool? privacyAccepted,
    DateTime? privacyAcceptedAt,
    bool? termsAccepted,
    DateTime? termsAcceptedAt,
    bool? isSystemOwner,
    DateTime? lastLogin,
    bool? freelancerUnlocked,
    DateTime? freelancerUnlockedAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      roles: roles ?? this.roles,
      primaryRole: primaryRole ?? this.primaryRole,
      accountType: UserAccountType.normalize(accountType ?? this.accountType),
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      photoUrl: photoUrl ?? this.photoUrl,
      phone: phone ?? this.phone,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      country: country ?? this.country,
      city: city ?? this.city,
      bio: bio ?? this.bio,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      privacyAccepted: privacyAccepted ?? this.privacyAccepted,
      privacyAcceptedAt: privacyAcceptedAt ?? this.privacyAcceptedAt,
      termsAccepted: termsAccepted ?? this.termsAccepted,
      termsAcceptedAt: termsAcceptedAt ?? this.termsAcceptedAt,
      isSystemOwner: isSystemOwner ?? this.isSystemOwner,
      lastLogin: lastLogin ?? this.lastLogin,
      freelancerUnlocked: freelancerUnlocked ?? this.freelancerUnlocked,
      freelancerUnlockedAt: freelancerUnlockedAt ?? this.freelancerUnlockedAt,
    );
  }

  /// Convenience Getters

  /// Whether the user has selected at least one role.
  bool get hasRole => primaryRole != null && primaryRole!.trim().isNotEmpty;

  bool get isCustomerAccount =>
      UserAccountType.normalize(accountType) == UserAccountType.customer;

  bool get isProfessionalAccount =>
      UserAccountType.normalize(accountType) == UserAccountType.professional;

  String? get profileImage => photoUrl;

  /// Returns the primary [UserRole] enum value, or null.
  UserRole? get primaryRoleEnum => UserRole.fromString(primaryRole);

  /// Bridge unlock or native freelancer role present.
  bool get canUseFreelancerMode =>
      freelancerUnlocked || _hasNormalizedRole('freelancer');

  bool get isSuperAdmin => _hasNormalizedRole('superadmin');

  bool get isAdmin =>
      _hasNormalizedRole('admin') || _hasNormalizedRole('superadmin');

  bool get hasAdminRecoveryAccess => isSystemOwner || isSuperAdmin;

  bool get canBypassMaintenance => isSystemOwner || isAdmin;

  bool _hasNormalizedRole(String role) {
    if (_normalizeRole(primaryRole) == role) return true;
    return roles.any((value) => _normalizeRole(value) == role);
  }

  @override
  String toString() =>
      'UserModel(uid: $uid, fullName: $fullName, primaryRole: $primaryRole)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModel &&
          runtimeType == other.runtimeType &&
          uid == other.uid;

  @override
  int get hashCode => uid.hashCode;
}

String _normalizeRole(String? role) {
  return (role ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
}
