import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/models/legal_policy.dart';
import 'return_refund_policy_screen.dart';

class PrivacyPolicyScreen extends ConsumerWidget {
  const PrivacyPolicyScreen({super.key});

  static const fallback = [
    LegalSection(
      title: 'Information We Collect',
      body:
          'SkillForge AI collects the information needed to create and manage your account, including your name, email address, selected role, profile details, onboarding answers, and activity connected to jobs, applications, verification, and account settings.',
    ),
    LegalSection(
      title: 'How We Use Information',
      body:
          'We use your information to authenticate your account, show the correct role dashboard, maintain profile completion, support job and application workflows, provide admin safety controls, and keep the platform reliable.',
    ),
    LegalSection(
      title: 'Profile Data',
      body:
          'Profile data may include your image URL, bio, phone, location, education, experience, skills, company details, portfolio links, and role-specific fields. This data is stored in Cloud Firestore under your user and role profile documents.',
    ),
    LegalSection(
      title: 'Image Uploads',
      body:
          'Profile images are uploaded to Cloudinary. SkillForge AI stores the returned Cloudinary image URL in Cloud Firestore. The app does not store a Cloudinary API secret in the Flutter client.',
    ),
    LegalSection(
      title: 'Authentication',
      body:
          'Firebase Authentication is used for email and password sign in. Firebase manages authentication credentials. SkillForge AI stores profile and account status data separately in Cloud Firestore.',
    ),
    LegalSection(
      title: 'Data Security',
      body:
          'We use Firebase Authentication, Cloud Firestore security rules, local secure storage for App Lock data, and role-based routing to reduce unauthorized access. No system can be guaranteed completely secure, so users should protect their password and device.',
    ),
    LegalSection(
      title: 'User Rights',
      body:
          'You may review and update much of your profile information from the Profile Center. You may also request correction or deletion of account information through the available support or administrator channel for your deployment.',
    ),
    LegalSection(
      title: 'Account Deletion',
      body:
          'Account deletion is handled by request. Some records may need to remain for safety, audit, dispute, legal, or operational reasons. Uploaded images may require separate removal from Cloudinary depending on the deletion process used by the platform operator.',
    ),
    LegalSection(
      title: 'Technologies Used',
      body:
          'SkillForge AI is built with Flutter and Riverpod. It uses Firebase Authentication, Cloud Firestore, and Cloudinary for the features described in this policy.',
    ),
    LegalSection(
      title: 'Contact Information',
      body:
          'For privacy questions, use the Contact Support option in the Profile Center or contact the official administrator/support channel provided by your SkillForge AI deployment.',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LegalDocumentScreen(
      title: 'Privacy Policy',
      subtitle: 'How SkillForge AI collects, uses, and protects your data.',
      icon: Icons.shield_outlined,
      accent: AppColors.primary,
      fallbackSections: fallback,
      selectSections: (p) => p.privacyPolicy,
    );
  }
}
