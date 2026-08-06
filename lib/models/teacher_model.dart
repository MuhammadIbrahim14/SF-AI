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

class TeacherModel {
  const TeacherModel({
    required this.userId,
    this.professionalTitle = '',
    this.experienceYears = 0,
    this.industry = '',
    this.subjects = const [],
    this.skillsTaught = const [],
    this.certifications = const [],
    this.linkedin = '',
    this.github = '',
    this.behance = '',
    this.dribbble = '',
    this.website = '',
    this.specializations = const [],
    this.coursesCreated = 0,
    this.totalStudents = 0,
    this.rating = 0.0,
    this.bio = '',
  });

  final String userId;
  final String professionalTitle;
  final int experienceYears;
  final String industry;
  final List<String> subjects;
  final List<String> skillsTaught;
  final List<String> certifications;
  final String linkedin;
  final String github;
  final String behance;
  final String dribbble;
  final String website;
  final List<String> specializations;
  final int coursesCreated;
  final int totalStudents;
  final double rating;
  final String bio;

  factory TeacherModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return TeacherModel(
      userId: doc.id,
      professionalTitle: data['professionalTitle'] is String
          ? data['professionalTitle'] as String
          : '',
      experienceYears: _intValue(
        data['experienceYears'] ?? data['yearsOfExperience'],
      ),
      industry: data['industry'] is String ? data['industry'] as String : '',
      subjects: _stringList(data['subjects']),
      skillsTaught: _stringList(data['skillsTaught']),
      certifications: _stringList(data['certifications']),
      linkedin: data['linkedin'] is String ? data['linkedin'] as String : '',
      github: data['github'] is String ? data['github'] as String : '',
      behance: data['behance'] is String ? data['behance'] as String : '',
      dribbble: data['dribbble'] is String ? data['dribbble'] as String : '',
      website: data['website'] is String ? data['website'] as String : '',
      specializations: _stringList(data['specializations']).isNotEmpty
          ? _stringList(data['specializations'])
          : _stringList(data['subjects']),
      coursesCreated: _intValue(data['coursesCreated']),
      totalStudents: _intValue(data['totalStudents']),
      rating: _doubleValue(data['rating']),
      bio: data['bio'] is String ? data['bio'] as String : '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'professionalTitle': professionalTitle,
      'experienceYears': experienceYears,
      'industry': industry,
      'subjects': subjects,
      'skillsTaught': skillsTaught,
      'certifications': certifications,
      'linkedin': linkedin,
      'github': github,
      'behance': behance,
      'dribbble': dribbble,
      'website': website,
      'specializations': specializations,
      'coursesCreated': coursesCreated,
      'totalStudents': totalStudents,
      'rating': rating,
      'bio': bio,
    };
  }

  TeacherModel copyWith({
    String? userId,
    String? professionalTitle,
    int? experienceYears,
    String? industry,
    List<String>? subjects,
    List<String>? skillsTaught,
    List<String>? certifications,
    String? linkedin,
    String? github,
    String? behance,
    String? dribbble,
    String? website,
    List<String>? specializations,
    int? coursesCreated,
    int? totalStudents,
    double? rating,
    String? bio,
  }) {
    return TeacherModel(
      userId: userId ?? this.userId,
      professionalTitle: professionalTitle ?? this.professionalTitle,
      experienceYears: experienceYears ?? this.experienceYears,
      industry: industry ?? this.industry,
      subjects: subjects ?? this.subjects,
      skillsTaught: skillsTaught ?? this.skillsTaught,
      certifications: certifications ?? this.certifications,
      linkedin: linkedin ?? this.linkedin,
      github: github ?? this.github,
      behance: behance ?? this.behance,
      dribbble: dribbble ?? this.dribbble,
      website: website ?? this.website,
      specializations: specializations ?? this.specializations,
      coursesCreated: coursesCreated ?? this.coursesCreated,
      totalStudents: totalStudents ?? this.totalStudents,
      rating: rating ?? this.rating,
      bio: bio ?? this.bio,
    );
  }
}
