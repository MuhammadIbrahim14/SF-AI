import 'package:flutter/material.dart';
import '../../models/user_role.dart';
import 'app_colors.dart';

class RoleThemeColors {
  final Color primary;
  final Color secondary;
  final LinearGradient gradient;

  const RoleThemeColors({
    required this.primary,
    required this.secondary,
    required this.gradient,
  });
}

RoleThemeColors getRoleTheme(UserRole role) {
  switch (role) {
    case UserRole.student:
      return const RoleThemeColors(
        primary: AppColors.studentPrimary,
        secondary: AppColors.studentSecondary,
        gradient: LinearGradient(
          colors: [AppColors.studentPrimary, AppColors.studentSecondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      );
    case UserRole.teacher:
      return const RoleThemeColors(
        primary: AppColors.teacherPrimary,
        secondary: AppColors.teacherSecondary,
        gradient: LinearGradient(
          colors: [AppColors.teacherPrimary, AppColors.teacherSecondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      );
    case UserRole.company:
      return const RoleThemeColors(
        primary: AppColors.companyPrimary,
        secondary: AppColors.companySecondary,
        gradient: LinearGradient(
          colors: [AppColors.companyPrimary, AppColors.companySecondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      );
    case UserRole.freelancer:
      return const RoleThemeColors(
        primary: AppColors.freelancerPrimary,
        secondary: AppColors.freelancerSecondary,
        gradient: LinearGradient(
          colors: [AppColors.freelancerPrimary, AppColors.freelancerSecondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      );
    case UserRole.admin:
      return const RoleThemeColors(
        primary: AppColors.adminPrimary,
        secondary: AppColors.adminSecondary,
        gradient: LinearGradient(
          colors: [AppColors.adminPrimary, AppColors.adminSecondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      );
    case UserRole.superAdmin:
      return const RoleThemeColors(
        primary: AppColors.superAdminPrimary,
        secondary: AppColors.superAdminSecondary,
        gradient: LinearGradient(
          colors: [AppColors.superAdminPrimary, AppColors.superAdminSecondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      );
  }
}
