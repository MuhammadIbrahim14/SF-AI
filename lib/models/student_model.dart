import 'package:cloud_firestore/cloud_firestore.dart';

List<String> _stringList(Object? value) =>
    value is Iterable ? value.whereType<String>().toList() : const [];

int _intValue(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

class StudentModel {
  const StudentModel({
    required this.userId,
    this.educationLevel = '',
    this.institute = '',
    this.degree = '',
    this.fieldOfStudy = '',
    this.graduationYear = 0,
    this.skills = const [],
    this.interestedSkills = const [],
    this.careerGoal = '',
    this.linkedin = '',
    this.github = '',
    this.behance = '',
    this.dribbble = '',
    this.portfolioWebsite = '',
    this.learningProgress = 0,
    this.enrolledCourses = const [],
    this.completedCourses = 0,
    this.interests = const [],
  });

  final String userId;
  final String educationLevel;
  final String institute;
  final String degree;
  final String fieldOfStudy;
  final int graduationYear;
  final List<String> skills;
  final List<String> interestedSkills;
  final String careerGoal;
  final String linkedin;
  final String github;
  final String behance;
  final String dribbble;
  final String portfolioWebsite;
  final int learningProgress;
  final List<String> enrolledCourses;
  final int completedCourses;
  final List<String> interests;

  factory StudentModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return StudentModel(
      userId: doc.id,
      educationLevel: data['educationLevel'] is String
          ? data['educationLevel'] as String
          : '',
      institute: data['institute'] is String
          ? data['institute'] as String
          : data['instituteName'] is String
          ? data['instituteName'] as String
          : '',
      degree: data['degree'] is String ? data['degree'] as String : '',
      fieldOfStudy: data['fieldOfStudy'] is String
          ? data['fieldOfStudy'] as String
          : '',
      graduationYear: _intValue(data['graduationYear']),
      skills: _stringList(data['skills']).isNotEmpty
          ? _stringList(data['skills'])
          : _stringList(data['currentSkills']),
      interestedSkills: _stringList(data['interestedSkills']),
      careerGoal: data['careerGoal'] is String
          ? data['careerGoal'] as String
          : '',
      linkedin: data['linkedin'] is String ? data['linkedin'] as String : '',
      github: data['github'] is String ? data['github'] as String : '',
      behance: data['behance'] is String ? data['behance'] as String : '',
      dribbble: data['dribbble'] is String ? data['dribbble'] as String : '',
      portfolioWebsite: data['portfolioWebsite'] is String
          ? data['portfolioWebsite'] as String
          : data['portfolio'] is String
          ? data['portfolio'] as String
          : '',
      learningProgress: _intValue(data['learningProgress']),
      enrolledCourses: _stringList(data['enrolledCourses']),
      completedCourses: _intValue(data['completedCourses']),
      interests: _stringList(data['interests']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'educationLevel': educationLevel,
      'institute': institute,
      'degree': degree,
      'fieldOfStudy': fieldOfStudy,
      'graduationYear': graduationYear,
      'skills': skills,
      'interestedSkills': interestedSkills,
      'careerGoal': careerGoal,
      'linkedin': linkedin,
      'github': github,
      'behance': behance,
      'dribbble': dribbble,
      'portfolioWebsite': portfolioWebsite,
      'learningProgress': learningProgress,
      'enrolledCourses': enrolledCourses,
      'completedCourses': completedCourses,
      'interests': interests,
    };
  }

  StudentModel copyWith({
    String? userId,
    String? educationLevel,
    String? institute,
    String? degree,
    String? fieldOfStudy,
    int? graduationYear,
    List<String>? skills,
    List<String>? interestedSkills,
    String? careerGoal,
    String? linkedin,
    String? github,
    String? behance,
    String? dribbble,
    String? portfolioWebsite,
    int? learningProgress,
    List<String>? enrolledCourses,
    int? completedCourses,
    List<String>? interests,
  }) {
    return StudentModel(
      userId: userId ?? this.userId,
      educationLevel: educationLevel ?? this.educationLevel,
      institute: institute ?? this.institute,
      degree: degree ?? this.degree,
      fieldOfStudy: fieldOfStudy ?? this.fieldOfStudy,
      graduationYear: graduationYear ?? this.graduationYear,
      skills: skills ?? this.skills,
      interestedSkills: interestedSkills ?? this.interestedSkills,
      careerGoal: careerGoal ?? this.careerGoal,
      linkedin: linkedin ?? this.linkedin,
      github: github ?? this.github,
      behance: behance ?? this.behance,
      dribbble: dribbble ?? this.dribbble,
      portfolioWebsite: portfolioWebsite ?? this.portfolioWebsite,
      learningProgress: learningProgress ?? this.learningProgress,
      enrolledCourses: enrolledCourses ?? this.enrolledCourses,
      completedCourses: completedCourses ?? this.completedCourses,
      interests: interests ?? this.interests,
    );
  }
}
