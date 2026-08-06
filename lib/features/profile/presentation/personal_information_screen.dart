import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/route_names.dart';
import '../../../models/user_role.dart';
import '../../../core/theme/role_theme.dart';
import '../../../shared/widgets/avatar_widget.dart';
import 'widgets/profile_section_scaffold.dart';

class PersonalInformationScreen extends StatelessWidget {
  const PersonalInformationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ProfileSectionScaffold(
      title: 'Personal Information',
      subtitle:
          'Your identity and contact details from your SkillForge AI account.',
      builder: (context, profile) {
        final user = profile.user;
        final details = profile.details;
        final roleTheme = getRoleTheme(profile.role);
        final displayName = profile.role == UserRole.company
            ? profileDisplayValue(details['companyName']) == 'Not added'
                  ? user.fullName
                  : details['companyName'].toString()
            : user.fullName;
        final initial = displayName.trim().isEmpty
            ? 'U'
            : displayName.trim()[0].toUpperCase();
        final roleBio = switch (profile.role) {
          UserRole.company => details['description'],
          _ => details['bio'],
        };
        final phone = user.phone.isNotEmpty
            ? user.phone
            : details['phoneNumber'];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Hero(
                tag: 'profile-avatar-${profile.role.name}',
                child: AvatarWidget(
                  imageUrl: user.profileImage,
                  radius: 54,
                  fallbackText: initial,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: FilledButton.tonalIcon(
                onPressed: () =>
                    context.pushNamed(_editRouteName(profile.role)),
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Edit Information'),
              ),
            ),
            const SizedBox(height: 24),
            ProfileInfoCard(
              title: 'Identity',
              icon: Icons.badge_outlined,
              accentColor: roleTheme.primary,
              children: [
                ProfileInfoRow(label: 'Full Name', value: user.fullName),
                ProfileInfoRow(label: 'Email', value: user.email),
                ProfileInfoRow(label: 'Phone', value: phone),
                ProfileInfoRow(label: 'Gender', value: user.gender),
                ProfileInfoRow(
                  label: 'Date of Birth',
                  value: user.dateOfBirth == null
                      ? null
                      : DateFormat.yMMMMd().format(user.dateOfBirth!),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ProfileInfoCard(
              title: 'Location & About',
              icon: Icons.public_rounded,
              accentColor: roleTheme.primary,
              children: [
                ProfileInfoRow(label: 'Country', value: user.country),
                ProfileInfoRow(label: 'City', value: user.city),
                ProfileInfoRow(
                  label: 'Bio',
                  value: user.bio.isNotEmpty ? user.bio : roleBio,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

String _editRouteName(UserRole role) {
  return switch (role) {
    UserRole.student => RouteNames.studentEditProfile,
    UserRole.teacher => RouteNames.teacherEditProfile,
    UserRole.freelancer => RouteNames.freelancerEditProfile,
    UserRole.company => RouteNames.companyEditProfile,
    _ => RouteNames.dashboard,
  };
}
