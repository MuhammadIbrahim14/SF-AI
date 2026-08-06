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
import '../../../shared/widgets/responsive_pair.dart';

/// Provider for company onboarding logic
final companyOnboardingProvider =
    AsyncNotifierProvider<CompanyOnboardingNotifier, void>(
      CompanyOnboardingNotifier.new,
    );

class CompanyOnboardingNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> submitForm(Map<String, dynamic> data) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final saved = await ref
          .read(profileActionProvider.notifier)
          .saveProfile(
            role: UserRole.company,
            userData: const {'onboardingCompleted': true},
            roleData: {...data, 'verificationStatus': 'pending'},
          );
      if (!saved) throw Exception('Failed to save company profile');
    });

    return !state.hasError;
  }
}

/// SkillForge AI — Company Onboarding
class CompanyOnboardingScreen extends ConsumerStatefulWidget {
  const CompanyOnboardingScreen({super.key});

  @override
  ConsumerState<CompanyOnboardingScreen> createState() =>
      _CompanyOnboardingScreenState();
}

class _CompanyOnboardingScreenState
    extends ConsumerState<CompanyOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _industryCtrl = TextEditingController();
  final _sizeCtrl = TextEditingController();
  final _foundedYearCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _industryCtrl.dispose();
    _sizeCtrl.dispose();
    _foundedYearCtrl.dispose();
    _websiteCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final data = {
      'companyName': _nameCtrl.text.trim(),
      'industry': _industryCtrl.text.trim(),
      'companySize': _sizeCtrl.text.trim(),
      'foundedYear': int.tryParse(_foundedYearCtrl.text.trim()) ?? 0,
      'website': _websiteCtrl.text.trim(),
      'officialEmail': _emailCtrl.text.trim(),
      'phoneNumber': _phoneCtrl.text.trim(),
      'description': _descriptionCtrl.text.trim(),
    };

    final success = await ref
        .read(companyOnboardingProvider.notifier)
        .submitForm(data);

    if (!mounted) return;
    if (success) {
      context.goNamed(RouteNames.companyDashboard);
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
        ref.watch(companyOnboardingProvider).isLoading ||
        ref.watch(profileActionProvider).isLoading;
    final user = ref.watch(currentUserProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Company Profile Setup'),
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
        message: 'Setting up company profile...',
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
                        role: UserRole.company,
                        imageUrl: user?.profileImage,
                        fallbackText: user?.fullName ?? 'Company',
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildSectionHeader('Company Details'),
                    CustomTextField(
                      controller: _nameCtrl,
                      label: 'Company Name',
                      hint: 'e.g., Tech Innovators Inc.',
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _industryCtrl,
                      label: 'Industry',
                      hint: 'e.g., Software, Finance, Healthcare',
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    ResponsivePair(
                      first: CustomTextField(
                        controller: _sizeCtrl,
                        label: 'Company Size',
                        hint: 'e.g., 50-200',
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      second: CustomTextField(
                        controller: _foundedYearCtrl,
                        label: 'Founded Year',
                        hint: 'e.g., 2015',
                        keyboardType: TextInputType.number,
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                    ),

                    const SizedBox(height: 32),
                    _buildSectionHeader('Contact Information'),
                    CustomTextField(
                      controller: _websiteCtrl,
                      label: 'Website',
                      hint: 'https://company.com',
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _emailCtrl,
                      label: 'Official Email',
                      hint: 'contact@company.com',
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _phoneCtrl,
                      label: 'Phone Number',
                      hint: '+1 (555) 000-0000',
                      keyboardType: TextInputType.phone,
                    ),

                    const SizedBox(height: 32),
                    _buildSectionHeader('About'),
                    CustomTextField(
                      controller: _descriptionCtrl,
                      label: 'Company Description',
                      hint: 'What does your company do?',
                      maxLines: 5,
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),

                    const SizedBox(height: 48),
                    PrimaryButton(
                      text: 'Submit Profile',
                      icon: Icons.business_rounded,
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
