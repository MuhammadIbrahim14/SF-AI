import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/models/legal_policy.dart';
import 'return_refund_policy_screen.dart';

class TermsOfServiceScreen extends ConsumerWidget {
  const TermsOfServiceScreen({super.key});

  static const fallback = [
    LegalSection(
      title: 'Using SkillForge AI',
      body:
          'SkillForge AI provides role-based tools for students, teachers, freelancers, companies, admins, and super admins. You agree to use the platform honestly, lawfully, and in a way that does not harm other users or the service.',
    ),
    LegalSection(
      title: 'User Responsibilities',
      body:
          'You are responsible for keeping your profile information accurate, using your own account, respecting other users, and avoiding misleading, abusive, illegal, or unsafe content.',
    ),
    LegalSection(
      title: 'Account Security',
      body:
          'You are responsible for protecting your password and device. If you enable App Lock, keep your PIN private. SkillForge AI will never ask you to share your password or PIN inside public messages.',
    ),
    LegalSection(
      title: 'Student Rules',
      body:
          'Students should provide truthful profile information, submit genuine applications, respect teachers and companies, and avoid copying or misrepresenting work.',
    ),
    LegalSection(
      title: 'Teacher Rules',
      body:
          'Teachers should provide accurate experience, specialization, and verification information. Teaching content, guidance, and communication should be professional and safe for learners.',
    ),
    LegalSection(
      title: 'Freelancer Rules',
      body:
          'Freelancers should present skills and portfolio links honestly, communicate professionally, and avoid false claims about experience, pricing, or work ownership.',
    ),
    LegalSection(
      title: 'Company Rules',
      body:
          'Companies should post legitimate jobs, provide accurate company details, review applications fairly, and avoid collecting unnecessary sensitive information from candidates.',
    ),
    LegalSection(
      title: 'Prohibited Activities',
      body:
          'Do not attempt unauthorized access, abuse Firebase or Cloudinary-backed features, upload harmful content, impersonate others, spam users, scrape data, bypass role restrictions, or use the platform for illegal activity.',
    ),
    LegalSection(
      title: 'Prohibited Content',
      body:
          'You must not upload, post, or transmit content that is illegal, harmful, abusive, harassing, defamatory, or otherwise objectionable. You must not upload images containing nudity, violence, or hate speech.',
    ),
    LegalSection(
      title: 'Intellectual Property',
      body:
          'The SkillForge AI name, branding, and original code are protected by intellectual property laws. Users retain rights to their own uploaded profile content, but grant SkillForge AI a license to display it within the app.',
    ),
    LegalSection(
      title: 'Account Termination',
      body:
          'Administrators may suspend or terminate your account without notice if you violate these terms, upload prohibited content, or misuse platform resources.',
    ),
    LegalSection(
      title: 'Disclaimer of Warranties',
      body:
          'SkillForge AI is provided "as is" without any warranty. We do not guarantee that the service will be uninterrupted, error-free, or completely secure.',
    ),
    LegalSection(
      title: 'Limitation of Liability',
      body:
          'In no event shall the creators or operators of SkillForge AI be liable for any indirect, incidental, or consequential damages arising from your use of the application.',
    ),
    LegalSection(
      title: 'Changes to Terms',
      body:
          'We reserve the right to modify these terms at any time. Continued use of the application after changes indicates your acceptance of the new terms.',
    ),
    LegalSection(
      title: 'Contact Information',
      body:
          'For terms questions, use the Contact Support option in the Profile Center or the official administrator/support channel provided by your SkillForge AI deployment.',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LegalDocumentScreen(
      title: 'Terms of Service',
      subtitle: 'Rules and responsibilities for using SkillForge AI.',
      icon: Icons.gavel_rounded,
      accent: AppColors.secondary,
      fallbackSections: fallback,
      selectSections: (p) => p.termsOfService,
    );
  }
}
