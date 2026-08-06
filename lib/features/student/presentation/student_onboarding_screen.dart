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

/// Provider for student onboarding logic
final studentOnboardingProvider =
    AsyncNotifierProvider<StudentOnboardingNotifier, void>(
      StudentOnboardingNotifier.new,
    );

class StudentOnboardingNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> submitForm(Map<String, dynamic> data) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final saved = await ref
          .read(profileActionProvider.notifier)
          .saveProfile(
            role: UserRole.student,
            userData: const {'onboardingCompleted': true},
            roleData: data,
          );
      if (!saved) throw Exception('Failed to save student profile');
    });

    return !state.hasError;
  }
}

/// SkillForge AI — Student Onboarding
class StudentOnboardingScreen extends ConsumerStatefulWidget {
  const StudentOnboardingScreen({super.key});

  @override
  ConsumerState<StudentOnboardingScreen> createState() =>
      _StudentOnboardingScreenState();
}

class _StudentOnboardingScreenState
    extends ConsumerState<StudentOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();

  // Step 1
  final _educationLevelCtrl = TextEditingController();
  final _instituteCtrl = TextEditingController();
  final _fieldOfStudyCtrl = TextEditingController();
  final _graduationYearCtrl = TextEditingController();

  // Step 2
  final _currentSkillsCtrl = TextEditingController();
  final _interestedSkillsCtrl = TextEditingController();
  final _careerGoalCtrl = TextEditingController();

  // Step 3
  final _linkedinCtrl = TextEditingController();
  final _githubCtrl = TextEditingController();
  final _portfolioCtrl = TextEditingController();

  @override
  void dispose() {
    _educationLevelCtrl.dispose();
    _instituteCtrl.dispose();
    _fieldOfStudyCtrl.dispose();
    _graduationYearCtrl.dispose();
    _currentSkillsCtrl.dispose();
    _interestedSkillsCtrl.dispose();
    _careerGoalCtrl.dispose();
    _linkedinCtrl.dispose();
    _githubCtrl.dispose();
    _portfolioCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final data = {
      'educationLevel': _educationLevelCtrl.text.trim(),
      'institute': _instituteCtrl.text.trim(),
      'fieldOfStudy': _fieldOfStudyCtrl.text.trim(),
      'graduationYear': _graduationYearCtrl.text.trim(),
      'skills': _splitValues(_currentSkillsCtrl.text),
      'interestedSkills': _splitValues(_interestedSkillsCtrl.text),
      'careerGoal': _careerGoalCtrl.text.trim(),
      'linkedin': _linkedinCtrl.text.trim(),
      'github': _githubCtrl.text.trim(),
      'portfolioWebsite': _portfolioCtrl.text.trim(),
    };

    final success = await ref
        .read(studentOnboardingProvider.notifier)
        .submitForm(data);

    if (!mounted) return;
    if (success) {
      context.goNamed(RouteNames.studentDashboard);
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
        ref.watch(studentOnboardingProvider).isLoading ||
        ref.watch(profileActionProvider).isLoading;
    final user = ref.watch(currentUserProvider).value;
    final roleTheme = getRoleTheme(UserRole.student);

    return Scaffold(
      appBar: AppBar(
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
        message: 'Building your student profile...',
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
                        role: UserRole.student,
                        imageUrl: user?.profileImage,
                        fallbackText: user?.fullName ?? 'Student',
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildSectionHeader('Step 1: Education', roleTheme),
                    CustomTextField(
                      controller: _educationLevelCtrl,
                      label: 'Education Level',
                      hint: 'e.g., Bachelor\'s, Master\'s, High School',
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _instituteCtrl,
                      label: 'Institute Name',
                      hint: 'Where do you study?',
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _fieldOfStudyCtrl,
                      label: 'Field of Study',
                      hint: 'e.g., Computer Science',
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _graduationYearCtrl,
                      label: 'Graduation Year',
                      hint: 'e.g., 2024',
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),

                    const SizedBox(height: 32),
                    _buildSectionHeader('Step 2: Skills & Goals', roleTheme),
                    CustomTextField(
                      controller: _currentSkillsCtrl,
                      label: 'Current Skills',
                      hint: 'Comma separated (e.g., Python, UI Design)',
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _interestedSkillsCtrl,
                      label: 'Interested Skills',
                      hint: 'What do you want to learn?',
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _careerGoalCtrl,
                      label: 'Career Goal',
                      hint: 'e.g., Become a full-stack developer',
                    ),

                    const SizedBox(height: 32),
                    _buildSectionHeader(
                      'Step 3: Portfolio (Optional)',
                      roleTheme,
                    ),
                    CustomTextField(
                      controller: _linkedinCtrl,
                      label: 'LinkedIn URL',
                      hint: 'https://linkedin.com/in/...',
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _githubCtrl,
                      label: 'GitHub URL',
                      hint: 'https://github.com/...',
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _portfolioCtrl,
                      label: 'Portfolio Website',
                      hint: 'https://yourwebsite.com',
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
          color: roleTheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  List<String> _splitValues(String value) {
    return value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
}
