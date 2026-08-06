import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/models/legal_policy.dart';
import 'return_refund_policy_screen.dart';

class AccountDeletionPolicyScreen extends ConsumerWidget {
  const AccountDeletionPolicyScreen({super.key});

  static const fallback = [
    LegalSection(
      title: 'How to Request Deletion',
      body:
          'Use the Contact Support option in the Profile Center or contact the official administrator/support channel for your SkillForge AI deployment. Include the email address connected to the account so the operator can verify the request.',
    ),
    LegalSection(
      title: 'What Happens Next',
      body:
          'A platform operator should verify the account owner, review active jobs, applications, verification records, audit logs, and role data, then process the request according to the project policy for that deployment.',
    ),
    LegalSection(
      title: 'What Data May Be Deleted',
      body:
          'Deletion may include your Firebase Authentication account, user profile, role profile, profile image URL, and other account-linked records where removal is safe and supported.',
    ),
    LegalSection(
      title: 'What Data May Remain',
      body:
          'Some records may remain when needed for safety, audit logs, dispute handling, fraud prevention, platform integrity, or legal/operational reasons. The current app does not claim automatic full deletion of every related record.',
    ),
    LegalSection(
      title: 'Uploaded Content',
      body:
          'Profile images are uploaded to Cloudinary and the Cloudinary URL is stored in Cloud Firestore. Image removal from Cloudinary may require administrator action or a backend deletion workflow.',
    ),
    LegalSection(
      title: 'How Long It May Take',
      body:
          'Deletion timing depends on verification and operational review. Until a dedicated automated deletion workflow is implemented, requests should be handled manually by the platform operator.',
    ),
    LegalSection(
      title: 'Before You Request Deletion',
      body:
          'If you only need to change your name, profile image, role information, or preferences, use Profile Center instead of deleting the account.',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LegalDocumentScreen(
      title: 'Account Deletion Policy',
      subtitle: 'What deletion means in the current SkillForge AI app.',
      icon: Icons.person_remove_alt_1_rounded,
      accent: AppColors.error,
      fallbackSections: fallback,
      selectSections: (p) => p.accountDeletion,
    );
  }
}
