import 'package:flutter/material.dart';

/// SkillForge AI — User Role Enumeration
/// Defines all supported roles within the platform ecosystem.
enum UserRole {
  student(
    label: 'Student',
    description: 'Learn new skills and grow your career',
    icon: Icons.school_rounded,
  ),
  teacher(
    label: 'Teacher',
    description: 'Share knowledge and mentor others',
    icon: Icons.cast_for_education_rounded,
  ),
  freelancer(
    label: 'Freelancer',
    description: 'Offer services and build your portfolio',
    icon: Icons.work_rounded,
  ),
  company(
    label: 'Company',
    description: 'Hire talent and manage your team',
    icon: Icons.business_rounded,
  ),
  admin(
    label: 'Admin',
    description: 'Manage platform operations',
    icon: Icons.admin_panel_settings_rounded,
  ),
  superAdmin(
    label: 'Super Admin',
    description: 'Full platform control',
    icon: Icons.security_rounded,
  );

  const UserRole({
    required this.label,
    required this.description,
    required this.icon,
  });

  final String label;
  final String description;
  final IconData icon;

  /// Roles selectable during onboarding (excludes admin tiers).
  static List<UserRole> get selectableRoles => [
    student,
    teacher,
    freelancer,
    company,
  ];

  /// Converts a string value to [UserRole]. Returns null if not found.
  static UserRole? fromString(String? value) {
    if (value == null) return null;
    final normalized = value.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]+'),
      '',
    );
    if (normalized == 'superadmin') return UserRole.superAdmin;
    return UserRole.values
        .where((role) => role.name.toLowerCase() == normalized)
        .firstOrNull;
  }
}
