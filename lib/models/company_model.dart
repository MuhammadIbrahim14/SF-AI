import 'package:cloud_firestore/cloud_firestore.dart';

String _stringValue(Object? value) => value is String ? value : '';

int _intValue(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

class CompanyModel {
  const CompanyModel({
    required this.userId,
    required this.companyName,
    this.industry = '',
    this.companySize = '',
    this.foundedYear = 0,
    this.website = '',
    this.linkedin = '',
    this.github = '',
    this.behance = '',
    this.dribbble = '',
    this.officialEmail = '',
    this.phoneNumber = '',
    this.description = '',
    this.logo = '',
    this.postedJobs = 0,
    this.employees = '',
  });

  final String userId;
  final String companyName;
  final String industry;
  final String companySize;
  final int foundedYear;
  final String website;
  final String linkedin;
  final String github;
  final String behance;
  final String dribbble;
  final String officialEmail;
  final String phoneNumber;
  final String description;
  final String logo;
  final int postedJobs;
  final String employees;

  factory CompanyModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return CompanyModel(
      userId: doc.id,
      companyName: _stringValue(data['companyName']),
      industry: _stringValue(data['industry']),
      companySize: _stringValue(data['companySize']).isNotEmpty
          ? _stringValue(data['companySize'])
          : _stringValue(data['employees']),
      foundedYear: _intValue(data['foundedYear']),
      website: _stringValue(data['website']),
      linkedin: _stringValue(data['linkedin']),
      github: _stringValue(data['github']),
      behance: _stringValue(data['behance']),
      dribbble: _stringValue(data['dribbble']),
      officialEmail: _stringValue(data['officialEmail']),
      phoneNumber: _stringValue(data['phoneNumber']),
      description: _stringValue(data['description']),
      logo: _stringValue(data['logo']),
      postedJobs: _intValue(data['postedJobs']),
      employees: _stringValue(data['employees']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'companyName': companyName,
      'industry': industry,
      'companySize': companySize,
      'foundedYear': foundedYear,
      'website': website,
      'linkedin': linkedin,
      'github': github,
      'behance': behance,
      'dribbble': dribbble,
      'officialEmail': officialEmail,
      'phoneNumber': phoneNumber,
      'description': description,
      'logo': logo,
      'postedJobs': postedJobs,
      'employees': employees,
    };
  }

  CompanyModel copyWith({
    String? userId,
    String? companyName,
    String? industry,
    String? companySize,
    int? foundedYear,
    String? website,
    String? linkedin,
    String? github,
    String? behance,
    String? dribbble,
    String? officialEmail,
    String? phoneNumber,
    String? description,
    String? logo,
    int? postedJobs,
    String? employees,
  }) {
    return CompanyModel(
      userId: userId ?? this.userId,
      companyName: companyName ?? this.companyName,
      industry: industry ?? this.industry,
      companySize: companySize ?? this.companySize,
      foundedYear: foundedYear ?? this.foundedYear,
      website: website ?? this.website,
      linkedin: linkedin ?? this.linkedin,
      github: github ?? this.github,
      behance: behance ?? this.behance,
      dribbble: dribbble ?? this.dribbble,
      officialEmail: officialEmail ?? this.officialEmail,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      description: description ?? this.description,
      logo: logo ?? this.logo,
      postedJobs: postedJobs ?? this.postedJobs,
      employees: employees ?? this.employees,
    );
  }
}
