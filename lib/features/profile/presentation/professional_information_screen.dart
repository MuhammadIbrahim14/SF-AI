import 'package:flutter/material.dart';

import '../../../models/user_role.dart';
import '../../../core/theme/role_theme.dart';
import 'widgets/profile_section_scaffold.dart';

class ProfessionalInformationScreen extends StatelessWidget {
  const ProfessionalInformationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ProfileSectionScaffold(
      title: 'Professional Information',
      subtitle:
          'Role-specific experience and professional details from your profile.',
      builder: (context, profile) {
        final data = profile.details;
        final rows = _rowsForRole(profile.role, data);
        final roleTheme = getRoleTheme(profile.role);

        return ProfileInfoCard(
          title: '${profile.role.label} Profile',
          icon: profile.role.icon,
          accentColor: roleTheme.primary,
          children: rows
              .map((row) => ProfileInfoRow(label: row.$1, value: row.$2))
              .toList(),
        );
      },
    );
  }
}

List<(String, Object?)> _rowsForRole(UserRole role, Map<String, dynamic> data) {
  return switch (role) {
    UserRole.student => [
      ('Education', data['educationLevel']),
      ('Institute', data['institute']),
      ('Degree', data['degree']),
      ('Field of Study', data['fieldOfStudy']),
      ('Graduation Year', data['graduationYear']),
    ],
    UserRole.teacher => [
      ('Experience', _years(data['experienceYears'])),
      ('Specialization', _joined(data['specializations'] ?? data['subjects'])),
      ('Certifications', _joined(data['certifications'])),
    ],
    UserRole.freelancer => [
      ('Services', _joined(data['services'])),
      ('Hourly Rate', _currency(data['hourlyRate'])),
      ('Experience', _years(data['experienceYears'])),
    ],
    UserRole.company => [
      ('Company Name', data['companyName']),
      ('Industry', data['industry']),
      ('Company Size', data['companySize']),
      ('Website', data['website']),
      ('Description', data['description']),
    ],
    _ => const [],
  };
}

String _joined(Object? value) {
  if (value is Iterable) {
    return value.map((item) => item.toString()).join(', ');
  }
  return value?.toString() ?? '';
}

String _years(Object? value) {
  final number = value is num ? value.toInt() : int.tryParse('$value') ?? 0;
  return number == 0 ? '' : '$number years';
}

String _currency(Object? value) {
  final number = value is num ? value.toDouble() : double.tryParse('$value');
  return number == null || number == 0
      ? ''
      : '\$${number.toStringAsFixed(number.truncateToDouble() == number ? 0 : 2)}/hr';
}
