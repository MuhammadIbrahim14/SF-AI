import 'package:cloud_firestore/cloud_firestore.dart';

List<String> _stringList(Object? value) =>
    value is Iterable ? value.whereType<String>().toList() : const [];

int _intValue(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

double _doubleValue(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

class FreelancerModel {
  const FreelancerModel({
    required this.userId,
    this.professionalTitle = '',
    this.category = '',
    this.experienceYears = 0,
    this.services = const [],
    this.portfolio = '',
    this.linkedin = '',
    this.github = '',
    this.behance = '',
    this.dribbble = '',
    this.website = '',
    this.bio = '',
    this.skills = const [],
    this.portfolioLinks = const [],
    this.completedGigs = 0,
    this.rating = 0.0,
    this.hourlyRate = 0.0,
    this.earnings = 0.0,
  });

  final String userId;
  final String professionalTitle;
  final String category;
  final int experienceYears;
  final List<String> services;
  final String portfolio;
  final String linkedin;
  final String github;
  final String behance;
  final String dribbble;
  final String website;
  final String bio;
  final List<String> skills;
  final List<String> portfolioLinks;
  final int completedGigs;
  final double rating;
  final double hourlyRate;
  final double earnings;

  factory FreelancerModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return FreelancerModel(
      userId: doc.id,
      professionalTitle: data['professionalTitle'] is String
          ? data['professionalTitle'] as String
          : '',
      category: data['category'] is String ? data['category'] as String : '',
      experienceYears: _intValue(
        data['experienceYears'] ?? data['yearsOfExperience'],
      ),
      services: _stringList(data['services']),
      portfolio: data['portfolio'] is String ? data['portfolio'] as String : '',
      linkedin: data['linkedin'] is String ? data['linkedin'] as String : '',
      github: data['github'] is String ? data['github'] as String : '',
      behance: data['behance'] is String ? data['behance'] as String : '',
      dribbble: data['dribbble'] is String ? data['dribbble'] as String : '',
      website: data['website'] is String ? data['website'] as String : '',
      bio: data['bio'] is String ? data['bio'] as String : '',
      skills: _stringList(data['skills']).isNotEmpty
          ? _stringList(data['skills'])
          : _stringList(data['services']),
      portfolioLinks: _stringList(data['portfolioLinks']).isNotEmpty
          ? _stringList(data['portfolioLinks'])
          : data['portfolio'] is String &&
                (data['portfolio'] as String).trim().isNotEmpty
          ? [data['portfolio'] as String]
          : const [],
      completedGigs: _intValue(data['completedGigs']),
      rating: _doubleValue(data['rating']),
      hourlyRate: _doubleValue(data['hourlyRate']),
      earnings: _doubleValue(data['earnings']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'professionalTitle': professionalTitle,
      'category': category,
      'experienceYears': experienceYears,
      'services': services,
      'portfolio': portfolio,
      'linkedin': linkedin,
      'github': github,
      'behance': behance,
      'dribbble': dribbble,
      'website': website,
      'bio': bio,
      'skills': skills,
      'portfolioLinks': portfolioLinks,
      'completedGigs': completedGigs,
      'rating': rating,
      'hourlyRate': hourlyRate,
      'earnings': earnings,
    };
  }

  FreelancerModel copyWith({
    String? userId,
    String? professionalTitle,
    String? category,
    int? experienceYears,
    List<String>? services,
    String? portfolio,
    String? linkedin,
    String? github,
    String? behance,
    String? dribbble,
    String? website,
    String? bio,
    List<String>? skills,
    List<String>? portfolioLinks,
    int? completedGigs,
    double? rating,
    double? hourlyRate,
    double? earnings,
  }) {
    return FreelancerModel(
      userId: userId ?? this.userId,
      professionalTitle: professionalTitle ?? this.professionalTitle,
      category: category ?? this.category,
      experienceYears: experienceYears ?? this.experienceYears,
      services: services ?? this.services,
      portfolio: portfolio ?? this.portfolio,
      linkedin: linkedin ?? this.linkedin,
      github: github ?? this.github,
      behance: behance ?? this.behance,
      dribbble: dribbble ?? this.dribbble,
      website: website ?? this.website,
      bio: bio ?? this.bio,
      skills: skills ?? this.skills,
      portfolioLinks: portfolioLinks ?? this.portfolioLinks,
      completedGigs: completedGigs ?? this.completedGigs,
      rating: rating ?? this.rating,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      earnings: earnings ?? this.earnings,
    );
  }
}
