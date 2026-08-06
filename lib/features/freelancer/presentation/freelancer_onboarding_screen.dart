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
import '../../marketplace_ai/models/marketplace_ai_draft_models.dart';

/// Provider for freelancer onboarding logic
final freelancerOnboardingProvider =
    AsyncNotifierProvider<FreelancerOnboardingNotifier, void>(
      FreelancerOnboardingNotifier.new,
    );

class FreelancerOnboardingNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> submitForm(Map<String, dynamic> data) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final saved = await ref
          .read(profileActionProvider.notifier)
          .saveProfile(
            role: UserRole.freelancer,
            userData: const {'onboardingCompleted': true},
            roleData: data,
          );
      if (!saved) throw Exception('Failed to save freelancer profile');
    });

    return !state.hasError;
  }
}

/// SkillForge AI — Freelancer Onboarding
class FreelancerOnboardingScreen extends ConsumerStatefulWidget {
  const FreelancerOnboardingScreen({super.key});

  @override
  ConsumerState<FreelancerOnboardingScreen> createState() =>
      _FreelancerOnboardingScreenState();
}

class _FreelancerOnboardingScreenState
    extends ConsumerState<FreelancerOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _experienceCtrl = TextEditingController();
  final _servicesCtrl = TextEditingController();
  final _hourlyRateCtrl = TextEditingController();
  final _portfolioCtrl = TextEditingController();
  final _linkedinCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final pending = MarketplaceAiPendingApply.profile;
      if (pending == null || pending.isEmpty) return;
      MarketplaceAiPendingApply.profile = null;
      final draft = MarketplaceProfileDraft.fromMap(pending);
      setState(() {
        if (draft.professionalTitle.trim().isNotEmpty) {
          _titleCtrl.text = draft.professionalTitle.trim();
        }
        if (draft.category.trim().isNotEmpty) {
          _categoryCtrl.text = draft.category.trim();
        }
        if (draft.services.trim().isNotEmpty) {
          _servicesCtrl.text = draft.services.trim();
        }
        if (draft.bio.trim().isNotEmpty) {
          _bioCtrl.text = draft.bio.trim();
        }
        if (draft.hourlyRate != null && draft.hourlyRate! > 0) {
          _hourlyRateCtrl.text = draft.hourlyRate!.toStringAsFixed(0);
        }
        if (draft.portfolioLinks.isNotEmpty) {
          _portfolioCtrl.text = draft.portfolioLinks.first;
        }
      });
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _categoryCtrl.dispose();
    _experienceCtrl.dispose();
    _servicesCtrl.dispose();
    _hourlyRateCtrl.dispose();
    _portfolioCtrl.dispose();
    _linkedinCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final data = {
      'professionalTitle': _titleCtrl.text.trim(),
      'category': _categoryCtrl.text.trim(),
      'experienceYears': int.tryParse(_experienceCtrl.text.trim()) ?? 0,
      'services': _servicesCtrl.text.split(',').map((e) => e.trim()).toList(),
      'hourlyRate': double.tryParse(_hourlyRateCtrl.text.trim()) ?? 0.0,
      'portfolio': _portfolioCtrl.text.trim(),
      'linkedin': _linkedinCtrl.text.trim(),
      'bio': _bioCtrl.text.trim(),
    };

    final success = await ref
        .read(freelancerOnboardingProvider.notifier)
        .submitForm(data);

    if (!mounted) return;
    if (success) {
      context.goNamed(RouteNames.freelancerDashboard);
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
        ref.watch(freelancerOnboardingProvider).isLoading ||
        ref.watch(profileActionProvider).isLoading;
    final user = ref.watch(currentUserProvider).value;
    final roleTheme = getRoleTheme(UserRole.freelancer);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Freelancer Profile Setup'),
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
        message: 'Building your freelancer profile...',
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
                        role: UserRole.freelancer,
                        imageUrl: user?.profileImage,
                        fallbackText: user?.fullName ?? 'Freelancer',
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildSectionHeader('Professional Identity', roleTheme),
                    CustomTextField(
                      controller: _titleCtrl,
                      label: 'Professional Title',
                      hint: 'e.g., UI/UX Designer, React Developer',
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _categoryCtrl,
                      label: 'Category',
                      hint: 'e.g., Design, Software Development',
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _experienceCtrl,
                      label: 'Years of Experience',
                      hint: 'e.g., 3',
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),

                    const SizedBox(height: 32),
                    _buildSectionHeader('Services & Rates', roleTheme),
                    CustomTextField(
                      controller: _servicesCtrl,
                      label: 'Services Offered',
                      hint: 'Comma separated (e.g., Web Design, App Dev)',
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _hourlyRateCtrl,
                      label: 'Hourly Rate (\$)',
                      hint: 'e.g., 50.00',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),

                    const SizedBox(height: 32),
                    _buildSectionHeader('Portfolio & Bio', roleTheme),
                    CustomTextField(
                      controller: _portfolioCtrl,
                      label: 'Portfolio URL',
                      hint: 'https://yourportfolio.com',
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _linkedinCtrl,
                      label: 'LinkedIn URL',
                      hint: 'https://linkedin.com/in/...',
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _bioCtrl,
                      label: 'Bio',
                      hint: 'Tell clients why they should hire you...',
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
          color: roleTheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
