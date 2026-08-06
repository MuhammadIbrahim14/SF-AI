class ProfileCompletionResult {
  const ProfileCompletionResult({
    required this.missingFields,
    required this.completedFields,
    required this.totalFields,
    required this.profileCompletionPercentage,
  });

  final List<String> missingFields;
  final List<String> completedFields;
  final int totalFields;
  final int profileCompletionPercentage;

  bool get isComplete => profileCompletionPercentage == 100;
}

class _ProfileField {
  const _ProfileField(this.label, this.aliases);

  final String label;
  final List<String> aliases;
}

abstract final class ProfileCompletion {
  static const List<_ProfileField> _commonFields = [
    _ProfileField('Profile image', ['profileImage', 'photoUrl']),
    _ProfileField('Full name', ['fullName', 'name']),
    _ProfileField('Email address', ['email']),
    _ProfileField('Phone number', ['phone', 'phoneNumber']),
    _ProfileField('Gender', ['gender']),
    _ProfileField('Date of birth', ['dateOfBirth']),
    _ProfileField('Country', ['country']),
    _ProfileField('City', ['city']),
    _ProfileField('Bio', ['bio']),
  ];

  static const Map<String, List<_ProfileField>> _roleFields = {
    'student': [
      _ProfileField('Education level', ['educationLevel']),
      _ProfileField('Institute', ['institute', 'instituteName']),
      _ProfileField('Degree', ['degree']),
      _ProfileField('Field of study', ['fieldOfStudy']),
      _ProfileField('Graduation year', ['graduationYear']),
      _ProfileField('Skills', ['skills', 'currentSkills']),
      _ProfileField('Interested skills', ['interestedSkills']),
      _ProfileField('Career goal', ['careerGoal']),
    ],
    'teacher': [
      _ProfileField('Professional title', ['professionalTitle']),
      _ProfileField('Experience', ['experienceYears', 'yearsOfExperience']),
      _ProfileField('Industry', ['industry']),
      _ProfileField('Subjects', ['subjects']),
      _ProfileField('Skills taught', ['skillsTaught']),
      _ProfileField('Certifications', ['certifications']),
      _ProfileField('Specializations', ['specializations']),
    ],
    'freelancer': [
      _ProfileField('Professional title', ['professionalTitle']),
      _ProfileField('Category', ['category']),
      _ProfileField('Experience', ['experienceYears', 'yearsOfExperience']),
      _ProfileField('Services', ['services']),
      _ProfileField('Skills', ['skills']),
      _ProfileField('Hourly rate', ['hourlyRate']),
      _ProfileField('Portfolio', ['portfolioLinks', 'portfolio', 'website']),
    ],
    'company': [
      _ProfileField('Company name', ['companyName']),
      _ProfileField('Industry', ['industry']),
      _ProfileField('Company size', ['companySize', 'employees']),
      _ProfileField('Founded year', ['foundedYear']),
      _ProfileField('Website', ['website']),
      _ProfileField('Official email', ['officialEmail']),
      _ProfileField('Company phone', ['phoneNumber']),
      _ProfileField('Company description', ['description']),
    ],
  };

  static ProfileCompletionResult evaluate({
    required Map<String, dynamic> userData,
    required String role,
    required Map<String, dynamic> roleData,
  }) {
    final roleFields = _roleFields[role] ?? const <_ProfileField>[];
    final fields = [
      ..._commonFields.map((field) => (field, userData)),
      ...roleFields.map((field) => (field, roleData)),
    ];
    final completedFields = <String>[];
    final missingFields = <String>[];

    for (final entry in fields) {
      final field = entry.$1;
      final data = entry.$2;
      if (field.aliases.any((key) => _isComplete(data[key]))) {
        completedFields.add(field.label);
      } else {
        missingFields.add(field.label);
      }
    }

    final totalFields = fields.length;
    final percentage = totalFields == 0
        ? 0
        : ((completedFields.length / totalFields) * 100).round().clamp(0, 100);

    return ProfileCompletionResult(
      missingFields: List.unmodifiable(missingFields),
      completedFields: List.unmodifiable(completedFields),
      totalFields: totalFields,
      profileCompletionPercentage: percentage,
    );
  }

  static int calculate({
    required Map<String, dynamic> userData,
    required String role,
    required Map<String, dynamic> roleData,
  }) {
    return evaluate(
      userData: userData,
      role: role,
      roleData: roleData,
    ).profileCompletionPercentage;
  }

  static bool _isComplete(Object? value) {
    if (value == null) return false;
    if (value is String) return value.trim().isNotEmpty;
    if (value is bool) return value;
    if (value is num) return value > 0;
    if (value is Iterable) return value.any(_isComplete);
    return true;
  }
}
