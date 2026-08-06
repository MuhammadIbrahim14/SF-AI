import 'package:cloud_firestore/cloud_firestore.dart';

String _stringValue(Object? value, [String fallback = '']) {
  return value is String ? value : fallback;
}

double _doubleValue(Object? value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
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

List<Map<String, dynamic>> _mapList(Object? value) {
  if (value is Iterable) {
    return value
        .whereType<Map>()
        .map(
          (item) => item.map((key, value) => MapEntry(key.toString(), value)),
        )
        .toList();
  }
  return const <Map<String, dynamic>>[];
}

class ResumeSkill {
  const ResumeSkill({
    required this.skillName,
    required this.score,
    required this.level,
  });

  final String skillName;
  final double score;
  final String level;

  factory ResumeSkill.fromJson(Map<String, dynamic> json) {
    return ResumeSkill(
      skillName: _stringValue(json['skillName']),
      score: _doubleValue(json['score']).clamp(0, 100).toDouble(),
      level: _stringValue(json['level'], 'Beginner'),
    );
  }

  Map<String, dynamic> toJson() {
    return {'skillName': skillName, 'score': score, 'level': level};
  }
}

class ResumeCertificate {
  const ResumeCertificate({
    required this.certificateId,
    required this.title,
    required this.courseTitle,
    required this.certificateType,
    required this.score,
    required this.issuedAt,
    required this.verificationCode,
  });

  final String certificateId;
  final String title;
  final String courseTitle;
  final String certificateType;
  final double score;
  final DateTime issuedAt;
  final String verificationCode;

  factory ResumeCertificate.fromJson(Map<String, dynamic> json) {
    return ResumeCertificate(
      certificateId: _stringValue(json['certificateId']),
      title: _stringValue(json['title']),
      courseTitle: _stringValue(json['courseTitle']),
      certificateType: _stringValue(json['certificateType']),
      score: _doubleValue(json['score']).clamp(0, 100).toDouble(),
      issuedAt: _dateValue(json['issuedAt']),
      verificationCode: _stringValue(json['verificationCode']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'certificateId': certificateId,
      'title': title,
      'courseTitle': courseTitle,
      'certificateType': certificateType,
      'score': score,
      'issuedAt': Timestamp.fromDate(issuedAt),
      'verificationCode': verificationCode,
    };
  }
}

class ResumeProject {
  const ResumeProject({
    required this.assignmentId,
    required this.courseId,
    required this.title,
    required this.description,
    required this.githubLink,
    required this.liveDemoLink,
    required this.score,
    required this.feedback,
    required this.skills,
  });

  final String assignmentId;
  final String courseId;
  final String title;
  final String description;
  final String githubLink;
  final String liveDemoLink;
  final double score;
  final String feedback;
  final List<String> skills;

  factory ResumeProject.fromJson(Map<String, dynamic> json) {
    return ResumeProject(
      assignmentId: _stringValue(json['assignmentId']),
      courseId: _stringValue(json['courseId']),
      title: _stringValue(json['title']),
      description: _stringValue(json['description']),
      githubLink: _stringValue(json['githubLink']),
      liveDemoLink: _stringValue(json['liveDemoLink']),
      score: _doubleValue(json['score']).clamp(0, 100).toDouble(),
      feedback: _stringValue(json['feedback']),
      skills: _stringList(json['skills']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'assignmentId': assignmentId,
      'courseId': courseId,
      'title': title,
      'description': description,
      'githubLink': githubLink,
      'liveDemoLink': liveDemoLink,
      'score': score,
      'feedback': feedback,
      'skills': skills,
    };
  }
}

class ResumeAchievement {
  const ResumeAchievement({required this.title, required this.description});

  final String title;
  final String description;

  factory ResumeAchievement.fromJson(Map<String, dynamic> json) {
    return ResumeAchievement(
      title: _stringValue(json['title']),
      description: _stringValue(json['description']),
    );
  }

  Map<String, dynamic> toJson() {
    return {'title': title, 'description': description};
  }
}

class SmartResumeModel {
  const SmartResumeModel({
    required this.resumeId,
    required this.studentId,
    required this.headline,
    required this.summary,
    required this.careerGoal,
    required this.education,
    required this.verifiedSkills,
    required this.certificates,
    required this.projects,
    required this.achievements,
    required this.strengths,
    required this.improvementAreas,
    required this.resumeScore,
    required this.lastGeneratedAt,
    required this.updatedAt,
  });

  final String resumeId;
  final String studentId;
  final String headline;
  final String summary;
  final String careerGoal;
  final String education;
  final List<ResumeSkill> verifiedSkills;
  final List<ResumeCertificate> certificates;
  final List<ResumeProject> projects;
  final List<ResumeAchievement> achievements;
  final List<String> strengths;
  final List<String> improvementAreas;
  final double resumeScore;
  final DateTime lastGeneratedAt;
  final DateTime updatedAt;

  bool get hasVerifiedData =>
      verifiedSkills.isNotEmpty ||
      certificates.isNotEmpty ||
      projects.isNotEmpty ||
      achievements.isNotEmpty;

  factory SmartResumeModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return SmartResumeModel(
      resumeId: _stringValue(data['resumeId'], doc.id),
      studentId: _stringValue(data['studentId'], doc.id),
      headline: _stringValue(data['headline']),
      summary: _stringValue(data['summary']),
      careerGoal: _stringValue(data['careerGoal']),
      education: _stringValue(data['education']),
      verifiedSkills: _mapList(
        data['verifiedSkills'],
      ).map(ResumeSkill.fromJson).toList(),
      certificates: _mapList(
        data['certificates'],
      ).map(ResumeCertificate.fromJson).toList(),
      projects: _mapList(data['projects']).map(ResumeProject.fromJson).toList(),
      achievements: _mapList(
        data['achievements'],
      ).map(ResumeAchievement.fromJson).toList(),
      strengths: _stringList(data['strengths']),
      improvementAreas: _stringList(data['improvementAreas']),
      resumeScore: _doubleValue(data['resumeScore']).clamp(0, 100).toDouble(),
      lastGeneratedAt: _dateValue(data['lastGeneratedAt']),
      updatedAt: _dateValue(data['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'resumeId': resumeId,
      'studentId': studentId,
      'headline': headline,
      'summary': summary,
      'careerGoal': careerGoal,
      'education': education,
      'verifiedSkills': verifiedSkills.map((skill) => skill.toJson()).toList(),
      'certificates': certificates
          .map((certificate) => certificate.toJson())
          .toList(),
      'projects': projects.map((project) => project.toJson()).toList(),
      'achievements': achievements
          .map((achievement) => achievement.toJson())
          .toList(),
      'strengths': strengths,
      'improvementAreas': improvementAreas,
      'resumeScore': resumeScore.clamp(0, 100),
      'lastGeneratedAt': Timestamp.fromDate(lastGeneratedAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  SmartResumeModel copyWith({
    String? resumeId,
    String? studentId,
    String? headline,
    String? summary,
    String? careerGoal,
    String? education,
    List<ResumeSkill>? verifiedSkills,
    List<ResumeCertificate>? certificates,
    List<ResumeProject>? projects,
    List<ResumeAchievement>? achievements,
    List<String>? strengths,
    List<String>? improvementAreas,
    double? resumeScore,
    DateTime? lastGeneratedAt,
    DateTime? updatedAt,
  }) {
    return SmartResumeModel(
      resumeId: resumeId ?? this.resumeId,
      studentId: studentId ?? this.studentId,
      headline: headline ?? this.headline,
      summary: summary ?? this.summary,
      careerGoal: careerGoal ?? this.careerGoal,
      education: education ?? this.education,
      verifiedSkills: verifiedSkills ?? this.verifiedSkills,
      certificates: certificates ?? this.certificates,
      projects: projects ?? this.projects,
      achievements: achievements ?? this.achievements,
      strengths: strengths ?? this.strengths,
      improvementAreas: improvementAreas ?? this.improvementAreas,
      resumeScore: resumeScore ?? this.resumeScore,
      lastGeneratedAt: lastGeneratedAt ?? this.lastGeneratedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
