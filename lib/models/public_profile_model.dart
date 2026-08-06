import 'package:cloud_firestore/cloud_firestore.dart';

List<String> _list(Object? value) {
  if (value is Iterable) {
    return value
        .map((item) => item?.toString() ?? '')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  if (value is String) {
    return value
        .split(RegExp(r'[\n,]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  return const <String>[];
}

String _string(Object? value, [String fallback = '']) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

DateTime _date(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  return DateTime.now();
}

bool _bool(Object? value) {
  if (value is bool) return value;
  if (value is String) return value.toLowerCase().trim() == 'true';
  return false;
}

class PublicProfileModel {
  const PublicProfileModel({
    required this.slug,
    required this.userId,
    required this.roleType,
    required this.displayName,
    required this.headline,
    required this.bio,
    required this.avatarUrl,
    required this.location,
    required this.skills,
    required this.verifiedSkills,
    required this.projects,
    required this.services,
    required this.coursesCreated,
    required this.certificates,
    required this.reviews,
    required this.socialLinks,
    required this.contactMode,
    required this.hireButtonEnabled,
    required this.publicVisible,
    required this.updatedAt,
  });

  final String slug;
  final String userId;
  final String roleType;
  final String displayName;
  final String headline;
  final String bio;
  final String avatarUrl;
  final String location;
  final List<String> skills;
  final List<String> verifiedSkills;
  final List<String> projects;
  final List<String> services;
  final List<String> coursesCreated;
  final List<String> certificates;
  final List<String> reviews;
  final List<String> socialLinks;
  final String contactMode;
  final bool hireButtonEnabled;
  final bool publicVisible;
  final DateTime updatedAt;

  factory PublicProfileModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return PublicProfileModel(
      slug: _string(data['slug'], doc.id),
      userId: _string(data['userId'], _string(data['ownerId'])),
      roleType: _string(data['roleType'], 'student'),
      displayName: _string(data['displayName'], 'SkillForge Member'),
      headline: _string(data['headline']),
      bio: _string(data['bio']),
      avatarUrl: _string(data['avatarUrl'], _string(data['photoUrl'])),
      location: _string(data['location']),
      skills: _list(data['skills']),
      verifiedSkills: _list(data['verifiedSkills']),
      projects: _list(data['projects']),
      services: _list(data['services']),
      coursesCreated: _list(data['coursesCreated']),
      certificates: _list(data['certificates']),
      reviews: _list(data['reviews']),
      socialLinks: _list(data['socialLinks']),
      contactMode: _string(data['contactMode'], 'platform'),
      hireButtonEnabled: _bool(data['hireButtonEnabled']),
      publicVisible: _bool(data['publicVisible'] ?? data['isPublic']),
      updatedAt: _date(data['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'slug': slug,
      'userId': userId,
      'ownerId': userId,
      'roleType': roleType,
      'displayName': displayName,
      'headline': headline,
      'bio': bio,
      'avatarUrl': avatarUrl,
      'photoUrl': avatarUrl,
      'location': location,
      'skills': skills,
      'verifiedSkills': verifiedSkills,
      'projects': projects,
      'services': services,
      'coursesCreated': coursesCreated,
      'certificates': certificates,
      'reviews': reviews,
      'socialLinks': socialLinks,
      'contactMode': contactMode,
      'hireButtonEnabled': hireButtonEnabled,
      'publicVisible': publicVisible,
      'isPublic': publicVisible,
      'source': 'portfolio_builder',
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

String publicProfileSlug(String input) {
  final slug = input
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return slug.isEmpty ? 'skillforge-profile' : slug;
}
