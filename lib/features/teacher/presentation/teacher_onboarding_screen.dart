import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/user_role.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/profile_image_picker.dart';
import '../../../core/theme/role_theme.dart';

/// Provider for teacher onboarding logic
final teacherOnboardingProvider =
    AsyncNotifierProvider<TeacherOnboardingNotifier, void>(
      TeacherOnboardingNotifier.new,
    );

class TeacherOnboardingNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> submitForm(Map<String, dynamic> data) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final saved = await ref
          .read(profileActionProvider.notifier)
          .saveProfile(
            role: UserRole.teacher,
            userData: const {'onboardingCompleted': true},
            roleData: data,
          );
      if (!saved) throw Exception('Failed to save teacher profile');
    });

    return !state.hasError;
  }
}

/// SkillForge AI — Teacher Onboarding
class TeacherOnboardingScreen extends ConsumerStatefulWidget {
  const TeacherOnboardingScreen({super.key});

  @override
  ConsumerState<TeacherOnboardingScreen> createState() =>
      _TeacherOnboardingScreenState();
}

class _TeacherOnboardingScreenState
    extends ConsumerState<TeacherOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleCtrl = TextEditingController();
  final _experienceCtrl = TextEditingController();
  final _industryCtrl = TextEditingController();
  final _subjectsCtrl = TextEditingController();
  final _skillsTaughtCtrl = TextEditingController();
  final _certificationsCtrl = TextEditingController();
  final _linkedinCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _experienceCtrl.dispose();
    _industryCtrl.dispose();
    _subjectsCtrl.dispose();
    _skillsTaughtCtrl.dispose();
    _certificationsCtrl.dispose();
    _linkedinCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final data = {
      'professionalTitle': _titleCtrl.text.trim(),
      'experienceYears': int.tryParse(_experienceCtrl.text.trim()) ?? 0,
      'industry': _industryCtrl.text.trim(),
      'subjects': _subjectsCtrl.text.split(',').map((e) => e.trim()).toList(),
      'skillsTaught': _skillsTaughtCtrl.text
          .split(',')
          .map((e) => e.trim())
          .toList(),
      'certifications': _certificationsCtrl.text
          .split(',')
          .map((e) => e.trim())
          .toList(),
      'linkedin': _linkedinCtrl.text.trim(),
      'bio': _bioCtrl.text.trim(),
      'verificationStatus': 'pending',
    };

    final success = await ref
        .read(teacherOnboardingProvider.notifier)
        .submitForm(data);

    if (!mounted) return;
    if (success) {
      context.goNamed(RouteNames.teacherDashboard);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to save profile. Try again.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading =
        ref.watch(teacherOnboardingProvider).isLoading ||
        ref.watch(profileActionProvider).isLoading;
    final user = ref.watch(currentUserProvider).value;
    final roleTheme = getRoleTheme(UserRole.teacher);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Profile Setup'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: () async {
              await ref.read(authNotifierProvider.notifier).signOut();
              if (context.mounted) {
                context.goNamed(RouteNames.login);
              }
            },
          ),
        ],
      ),
      body: LoadingOverlay(
        isLoading: isLoading,
        message: 'Building your teacher profile...',
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: ProfileImagePicker(
                        role: UserRole.teacher,
                        imageUrl: user?.profileImage,
                        fallbackText: user?.fullName ?? 'Teacher',
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildSectionHeader('Professional Identity', roleTheme),
                    CustomTextField(
                      controller: _titleCtrl,
                      label: 'Professional Title',
                      hint: 'e.g., Senior Data Scientist, English Professor',
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _experienceCtrl,
                      label: 'Years of Experience',
                      hint: 'e.g., 5',
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _industryCtrl,
                      label: 'Industry',
                      hint: 'e.g., Technology, Academia',
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),

                    const SizedBox(height: 32),
                    _buildSectionHeader('Teaching Details', roleTheme),
                    CustomTextField(
                      controller: _subjectsCtrl,
                      label: 'Subjects Taught',
                      hint: 'Comma separated (e.g., Math, Physics)',
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _skillsTaughtCtrl,
                      label: 'Specific Skills Taught',
                      hint: 'Comma separated (e.g., Flutter, UI Design)',
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _certificationsCtrl,
                      label: 'Certifications',
                      hint: 'Comma separated',
                    ),

                    const SizedBox(height: 32),
                    _buildSectionHeader('Profile details', roleTheme),
                    CustomTextField(
                      controller: _linkedinCtrl,
                      label: 'LinkedIn URL',
                      hint: 'https://linkedin.com/in/...',
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _bioCtrl,
                      label: 'Bio',
                      hint: 'Tell us about your teaching philosophy...',
                      maxLines: 4,
                    ),

                    const SizedBox(height: 48),
                    PrimaryButton(
                      text: 'Complete Profile',
                      icon: Icons.check_circle_outline,
                      onPressed: _submit,
                      isLoading: isLoading,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, RoleThemeColors roleTheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: roleTheme.secondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
