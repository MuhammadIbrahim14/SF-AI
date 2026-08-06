import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/user_role.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/admin_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../../../shared/widgets/profile_image_picker.dart';
import '../../../shared/widgets/responsive_pair.dart';

/// SkillForge AI — Premium Role Selection Screen
/// Full-screen immersive onboarding with glassmorphism cards and glow effects.
/// Now features a Step 3 for Profile Setup tailored to the selected role,
/// saving all data to Firestore.
class RoleSelectionScreen extends ConsumerStatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  ConsumerState<RoleSelectionScreen> createState() =>
      _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends ConsumerState<RoleSelectionScreen>
    with TickerProviderStateMixin {
  UserRole? _selectedRole;
  int _step = 1;
  bool _isSaving = false;

  final _detailsFormKey = GlobalKey<FormState>();
  final _profileFormKey = GlobalKey<FormState>();

  final _fullNameCtrl = TextEditingController();
  final _additionalNoteCtrl = TextEditingController();

  // Student controllers
  final _studentEduLevelCtrl = TextEditingController();
  final _studentInstituteCtrl = TextEditingController();
  final _studentFieldOfStudyCtrl = TextEditingController();
  final _studentGradYearCtrl = TextEditingController();
  final _studentCurrentSkillsCtrl = TextEditingController();
  final _studentInterestedSkillsCtrl = TextEditingController();
  final _studentCareerGoalCtrl = TextEditingController();
  final _studentLinkedinCtrl = TextEditingController();
  final _studentGithubCtrl = TextEditingController();
  final _studentPortfolioCtrl = TextEditingController();

  // Teacher controllers
  final _teacherTitleCtrl = TextEditingController();
  final _teacherExperienceCtrl = TextEditingController();
  final _teacherIndustryCtrl = TextEditingController();
  final _teacherSubjectsCtrl = TextEditingController();
  final _teacherSkillsTaughtCtrl = TextEditingController();
  final _teacherCertificationsCtrl = TextEditingController();
  final _teacherLinkedinCtrl = TextEditingController();
  final _teacherBioCtrl = TextEditingController();

  // Freelancer controllers
  final _freelancerTitleCtrl = TextEditingController();
  final _freelancerCategoryCtrl = TextEditingController();
  final _freelancerExperienceCtrl = TextEditingController();
  final _freelancerServicesCtrl = TextEditingController();
  final _freelancerHourlyRateCtrl = TextEditingController();
  final _freelancerPortfolioCtrl = TextEditingController();
  final _freelancerLinkedinCtrl = TextEditingController();
  final _freelancerBioCtrl = TextEditingController();

  // Company controllers
  final _companyNameCtrl = TextEditingController();
  final _companyIndustryCtrl = TextEditingController();
  final _companySizeCtrl = TextEditingController();
  final _companyFoundedYearCtrl = TextEditingController();
  final _companyWebsiteCtrl = TextEditingController();
  final _companyEmailCtrl = TextEditingController();
  final _companyPhoneCtrl = TextEditingController();
  final _companyDescriptionCtrl = TextEditingController();

  late final AnimationController _headerController;
  late final Animation<double> _headerFade;
  late final Animation<Offset> _headerSlide;
  late final AnimationController _cardsController;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();

    // Header entrance animation
    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _headerFade = CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOut,
    );
    _headerSlide = Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _headerController,
            curve: Curves.easeOutCubic,
          ),
        );

    // Cards staggered entrance
    _cardsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Subtle continuous pulse for selected card glow
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _headerController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _cardsController.forward();
    });
  }

  @override
  void dispose() {
    _headerController.dispose();
    _cardsController.dispose();
    _pulseController.dispose();
    _fullNameCtrl.dispose();
    _additionalNoteCtrl.dispose();

    _studentEduLevelCtrl.dispose();
    _studentInstituteCtrl.dispose();
    _studentFieldOfStudyCtrl.dispose();
    _studentGradYearCtrl.dispose();
    _studentCurrentSkillsCtrl.dispose();
    _studentInterestedSkillsCtrl.dispose();
    _studentCareerGoalCtrl.dispose();
    _studentLinkedinCtrl.dispose();
    _studentGithubCtrl.dispose();
    _studentPortfolioCtrl.dispose();

    _teacherTitleCtrl.dispose();
    _teacherExperienceCtrl.dispose();
    _teacherIndustryCtrl.dispose();
    _teacherSubjectsCtrl.dispose();
    _teacherSkillsTaughtCtrl.dispose();
    _teacherCertificationsCtrl.dispose();
    _teacherLinkedinCtrl.dispose();
    _teacherBioCtrl.dispose();

    _freelancerTitleCtrl.dispose();
    _freelancerCategoryCtrl.dispose();
    _freelancerExperienceCtrl.dispose();
    _freelancerServicesCtrl.dispose();
    _freelancerHourlyRateCtrl.dispose();
    _freelancerPortfolioCtrl.dispose();
    _freelancerLinkedinCtrl.dispose();
    _freelancerBioCtrl.dispose();

    _companyNameCtrl.dispose();
    _companyIndustryCtrl.dispose();
    _companySizeCtrl.dispose();
    _companyFoundedYearCtrl.dispose();
    _companyWebsiteCtrl.dispose();
    _companyEmailCtrl.dispose();
    _companyPhoneCtrl.dispose();
    _companyDescriptionCtrl.dispose();

    super.dispose();
  }

  Future<void> _handleContinue() async {
    if (_step == 1) {
      if (_selectedRole == null) return;
      setState(() => _step = 2);
      return;
    }

    if (_step == 2) {
      if (_selectedRole == null) return;
      if (!_detailsFormKey.currentState!.validate()) return;
      setState(() => _step = 3);
      return;
    }

    // Step 3
    if (_selectedRole == null) return;
    if (!_profileFormKey.currentState!.validate()) return;

    try {
      setState(() => _isSaving = true);

      Map<String, dynamic> specificData = {};

      if (_selectedRole == UserRole.student) {
        specificData = {
          'educationLevel': _studentEduLevelCtrl.text.trim(),
          'institute': _studentInstituteCtrl.text.trim(),
          'fieldOfStudy': _studentFieldOfStudyCtrl.text.trim(),
          'graduationYear': _studentGradYearCtrl.text.trim(),
          'skills': _studentCurrentSkillsCtrl.text
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(),
          'interestedSkills': _studentInterestedSkillsCtrl.text
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(),
          'careerGoal': _studentCareerGoalCtrl.text.trim(),
          'linkedin': _studentLinkedinCtrl.text.trim(),
          'github': _studentGithubCtrl.text.trim(),
          'portfolioWebsite': _studentPortfolioCtrl.text.trim(),
        };
      } else if (_selectedRole == UserRole.teacher) {
        specificData = {
          'professionalTitle': _teacherTitleCtrl.text.trim(),
          'experienceYears':
              int.tryParse(_teacherExperienceCtrl.text.trim()) ?? 0,
          'industry': _teacherIndustryCtrl.text.trim(),
          'subjects': _teacherSubjectsCtrl.text
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(),
          'skillsTaught': _teacherSkillsTaughtCtrl.text
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(),
          'certifications': _teacherCertificationsCtrl.text
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(),
          'linkedin': _teacherLinkedinCtrl.text.trim(),
          'bio': _teacherBioCtrl.text.trim(),
          'verificationStatus': 'pending',
        };
      } else if (_selectedRole == UserRole.freelancer) {
        specificData = {
          'professionalTitle': _freelancerTitleCtrl.text.trim(),
          'category': _freelancerCategoryCtrl.text.trim(),
          'experienceYears':
              int.tryParse(_freelancerExperienceCtrl.text.trim()) ?? 0,
          'services': _freelancerServicesCtrl.text
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(),
          'hourlyRate':
              double.tryParse(_freelancerHourlyRateCtrl.text.trim()) ?? 0.0,
          'portfolio': _freelancerPortfolioCtrl.text.trim(),
          'linkedin': _freelancerLinkedinCtrl.text.trim(),
          'bio': _freelancerBioCtrl.text.trim(),
        };
      } else if (_selectedRole == UserRole.company) {
        specificData = {
          'companyName': _companyNameCtrl.text.trim(),
          'industry': _companyIndustryCtrl.text.trim(),
          'companySize': _companySizeCtrl.text.trim(),
          'foundedYear': int.tryParse(_companyFoundedYearCtrl.text.trim()) ?? 0,
          'website': _companyWebsiteCtrl.text.trim(),
          'officialEmail': _companyEmailCtrl.text.trim(),
          'phoneNumber': _companyPhoneCtrl.text.trim(),
          'description': _companyDescriptionCtrl.text.trim(),
          'verificationStatus': 'pending',
        };
      }

      final detailsData = {
        'fullName': _fullNameCtrl.text.trim(),
        'additionalNote': _additionalNoteCtrl.text.trim(),
        'roles': [_selectedRole!.name],
        'primaryRole': _selectedRole!.name,
        'onboardingCompleted': true,
      };

      final saved = await ref
          .read(profileActionProvider.notifier)
          .saveProfile(
            role: _selectedRole!,
            userData: detailsData,
            roleData: specificData,
          );
      if (!saved) {
        throw Exception(
          ref.read(profileActionProvider.notifier).errorMessage ??
              'Unable to save profile.',
        );
      }

      if (mounted) {
        final dashboardRouteName = switch (_selectedRole!) {
          UserRole.student => RouteNames.studentDashboard,
          UserRole.teacher => RouteNames.teacherDashboard,
          UserRole.freelancer => RouteNames.freelancerDashboard,
          UserRole.company => RouteNames.companyDashboard,
          _ => RouteNames.roleSelection,
        };
        context.goNamed(dashboardRouteName);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save profile: ${e.toString()}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  /// Per-role gradient colors for visual distinction.
  static const _roleGradients = <UserRole, List<Color>>{
    UserRole.student: [AppColors.studentPrimary, AppColors.studentSecondary],
    UserRole.teacher: [AppColors.teacherPrimary, AppColors.teacherSecondary],
    UserRole.freelancer: [
      AppColors.freelancerPrimary,
      AppColors.freelancerSecondary,
    ],
    UserRole.company: [AppColors.companyPrimary, AppColors.companySecondary],
  };

  /// Per-role emoji/icon accent (subtle background decoration).
  static const _roleEmoji = <UserRole, String>{
    UserRole.student: '🎓',
    UserRole.teacher: '📚',
    UserRole.freelancer: '🚀',
    UserRole.company: '🏢',
  };

  @override
  Widget build(BuildContext context) {
    final roleState = ref.watch(roleNotifierProvider);
    final isLoading =
        roleState.isLoading ||
        ref.watch(profileActionProvider).isLoading ||
        _isSaving;
    final user = ref.watch(currentUserProvider).value;
    final platformSettings = ref.watch(platformSettingsProvider).value;
    final availableRoles = UserRole.selectableRoles.where((role) {
      if (role == UserRole.teacher) {
        return platformSettings?.teacherSignupEnabled ?? true;
      }
      if (role == UserRole.company) {
        return platformSettings?.companySignupEnabled ?? true;
      }
      return true;
    }).toList();
    if (_selectedRole != null && !availableRoles.contains(_selectedRole)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedRole = null);
      });
    }
    final size = MediaQuery.of(context).size;
    final primaryColor = _selectedRole != null
        ? _roleGradients[_selectedRole!]![0]
        : AppColors.primary;

    return Scaffold(
      body: LoadingOverlay(
        isLoading: isLoading,
        message: 'Setting up your profile...',
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF060A18), Color(0xFF0A0F1F), Color(0xFF0E142A)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Stack(
            children: [
              // ─── Ambient Background Orbs ─────────────────────────
              _AmbientOrb(
                top: -60,
                right: -40,
                size: 200,
                color: primaryColor.withValues(alpha: 0.08),
              ),
              _AmbientOrb(
                bottom: 100,
                left: -60,
                size: 180,
                color: AppColors.secondary.withValues(alpha: 0.06),
              ),
              _AmbientOrb(
                top: size.height * 0.4,
                right: -30,
                size: 140,
                color: AppColors.accent.withValues(alpha: 0.05),
              ),

              // ─── Main Content ─────────────────────────────────────
              SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Align(
                        alignment: Alignment.topRight,
                        child: IconButton(
                          icon: const Icon(
                            Icons.logout_rounded,
                            color: Colors.white70,
                          ),
                          tooltip: 'Logout',
                          onPressed: () async {
                            await ref
                                .read(authNotifierProvider.notifier)
                                .signOut();
                            if (context.mounted) {
                              context.goNamed(RouteNames.login);
                            }
                          },
                        ),
                      ),
                    ),

                    // ─── Header ──────────────────────────────────────
                    SlideTransition(
                      position: _headerSlide,
                      child: FadeTransition(
                        opacity: _headerFade,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: Column(
                            children: [
                              // Step indicator
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: primaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: primaryColor.withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: _selectedRole != null
                                            ? LinearGradient(
                                                colors:
                                                    _roleGradients[_selectedRole!]!,
                                              )
                                            : AppColors.primaryGradient,
                                      ),
                                      child: Center(
                                        child: Text(
                                          '$_step',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Step $_step of 3',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: primaryColor,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.5,
                                          ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 24),

                              // Title
                              ShaderMask(
                                shaderCallback: (bounds) => LinearGradient(
                                  colors: [
                                    Colors.white,
                                    primaryColor.withValues(alpha: 0.7),
                                  ],
                                ).createShader(bounds),
                                child: Text(
                                  _step == 1
                                      ? 'Who Are You?'
                                      : _step == 2
                                      ? 'Your Details'
                                      : 'Profile Setup',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineLarge
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.5,
                                      ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _step == 1
                                    ? 'Choose your role to personalize\nyour SkillForge experience'
                                    : _step == 2
                                    ? 'Confirm your full name and optional bio to get started'
                                    : 'Tell us about your professional background, skills, and goals',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: AppColors.textTertiary,
                                      height: 1.5,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ─── Body (Step 1 / Step 2 / Step 3) ───────────────
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: _step == 1
                            ? ListView.separated(
                                key: const ValueKey('step1'),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                physics: const BouncingScrollPhysics(),
                                itemCount: availableRoles.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 14),
                                itemBuilder: (context, index) {
                                  final role = availableRoles[index];
                                  final isSelected = _selectedRole == role;
                                  final colors = _roleGradients[role]!;
                                  final emoji = _roleEmoji[role]!;

                                  // Staggered entrance animation
                                  final start = index * 0.2;
                                  final end = (start + 0.4).clamp(0.0, 1.0);
                                  final slideAnim =
                                      Tween<Offset>(
                                        begin: const Offset(0, 0.4),
                                        end: Offset.zero,
                                      ).animate(
                                        CurvedAnimation(
                                          parent: _cardsController,
                                          curve: Interval(
                                            start,
                                            end,
                                            curve: Curves.easeOutCubic,
                                          ),
                                        ),
                                      );
                                  final fadeAnim =
                                      Tween<double>(
                                        begin: 0.0,
                                        end: 1.0,
                                      ).animate(
                                        CurvedAnimation(
                                          parent: _cardsController,
                                          curve: Interval(
                                            start,
                                            end,
                                            curve: Curves.easeOut,
                                          ),
                                        ),
                                      );

                                  return SlideTransition(
                                    position: slideAnim,
                                    child: FadeTransition(
                                      opacity: fadeAnim,
                                      child: _PremiumRoleCard(
                                        role: role,
                                        isSelected: isSelected,
                                        gradientColors: colors,
                                        emoji: emoji,
                                        pulseController: _pulseController,
                                        onTap: () => setState(
                                          () => _selectedRole = role,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              )
                            : _step == 2
                            ? SingleChildScrollView(
                                key: const ValueKey('step2'),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                child: Form(
                                  key: _detailsFormKey,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 8),
                                      Text(
                                        'Step 2/3 — Your details',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              color: primaryColor,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(height: 14),
                                      Text(
                                        'Confirm your name and add an optional note. We’ll use this for your profile.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: AppColors.textTertiary,
                                              height: 1.4,
                                            ),
                                      ),
                                      const SizedBox(height: 18),
                                      TextFormField(
                                        controller: _fullNameCtrl,
                                        decoration: InputDecoration(
                                          labelText: 'Full name',
                                          labelStyle: const TextStyle(
                                            color: AppColors.textSecondary,
                                          ),
                                          hintText: 'Enter your full name',
                                          filled: true,
                                          fillColor: AppColors.card,
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            borderSide: BorderSide(
                                              color: AppColors.cardBorder,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            borderSide: BorderSide(
                                              color: primaryColor,
                                              width: 1.5,
                                            ),
                                          ),
                                        ),
                                        validator: (v) {
                                          if (v == null || v.trim().isEmpty) {
                                            return 'Name is required';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 14),
                                      TextFormField(
                                        controller: _additionalNoteCtrl,
                                        decoration: InputDecoration(
                                          labelText:
                                              'Additional note (optional)',
                                          hintText:
                                              'e.g., what you want to achieve',
                                          filled: true,
                                          fillColor: AppColors.card,
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            borderSide: BorderSide(
                                              color: AppColors.cardBorder,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            borderSide: BorderSide(
                                              color: primaryColor,
                                              width: 1.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                    ],
                                  ),
                                ),
                              )
                            : SingleChildScrollView(
                                key: const ValueKey('step3'),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                child: Form(
                                  key: _profileFormKey,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 8),
                                      Text(
                                        'Step 3/3 — ${_selectedRole!.label} Profile Setup',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              color: primaryColor,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(height: 14),
                                      Text(
                                        'Please fill in your details to finish setting up your profile.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: AppColors.textTertiary,
                                              height: 1.4,
                                            ),
                                      ),
                                      const SizedBox(height: 18),
                                      Center(
                                        child: ProfileImagePicker(
                                          role: _selectedRole!,
                                          imageUrl: user?.profileImage,
                                          fallbackText:
                                              _fullNameCtrl.text.trim().isEmpty
                                              ? user?.fullName ??
                                                    _selectedRole!.label
                                              : _fullNameCtrl.text.trim(),
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      _buildStep3Form(_selectedRole!),
                                      const SizedBox(height: 24),
                                    ],
                                  ),
                                ),
                              ),
                      ),
                    ),

                    // ─── Bottom CTA + Previous ────────────────────────
                    Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                          child: SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: TextButton.icon(
                              onPressed: isLoading
                                  ? null
                                  : () {
                                      if (_step == 3) {
                                        setState(() => _step = 2);
                                        return;
                                      }
                                      if (_step == 2) {
                                        setState(() => _step = 1);
                                        return;
                                      }
                                      // Step 1: go back to splash/onboarding
                                      context.goNamed(RouteNames.appOnboarding);
                                    },
                              icon: const Icon(Icons.chevron_left_rounded),
                              label: Text(
                                _step > 1 ? 'Previous' : 'Back',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                        _buildBottomCTA(context, isLoading),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep3Form(UserRole role) {
    final accentColor = _roleGradients[role]![0];
    return switch (role) {
      UserRole.student => _buildStudentForm(accentColor),
      UserRole.teacher => _buildTeacherForm(accentColor),
      UserRole.freelancer => _buildFreelancerForm(accentColor),
      UserRole.company => _buildCompanyForm(accentColor),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _buildSectionHeader(String title, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0, top: 8.0),
      child: Text(
        title,
        style: TextStyle(
          color: accentColor,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildStudentForm(Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Education', accentColor),
        CustomTextField(
          controller: _studentEduLevelCtrl,
          label: 'Education Level',
          hint: "e.g., Bachelor's, Master's, High School",
          prefixIcon: Icons.school_rounded,
          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _studentInstituteCtrl,
          label: 'Institute Name',
          hint: 'Where do you study?',
          prefixIcon: Icons.business_rounded,
          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _studentFieldOfStudyCtrl,
          label: 'Field of Study',
          hint: 'e.g., Computer Science',
          prefixIcon: Icons.book_rounded,
          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _studentGradYearCtrl,
          label: 'Graduation Year',
          hint: 'e.g., 2024',
          prefixIcon: Icons.calendar_today_rounded,
          keyboardType: TextInputType.number,
          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 24),
        _buildSectionHeader('Skills & Goals', accentColor),
        CustomTextField(
          controller: _studentCurrentSkillsCtrl,
          label: 'Current Skills',
          hint: 'Comma separated (e.g., Python, UI Design)',
          prefixIcon: Icons.psychology_rounded,
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _studentInterestedSkillsCtrl,
          label: 'Interested Skills',
          hint: 'What do you want to learn?',
          prefixIcon: Icons.lightbulb_rounded,
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _studentCareerGoalCtrl,
          label: 'Career Goal',
          hint: 'e.g., Become a full-stack developer',
          prefixIcon: Icons.explore_rounded,
        ),
        const SizedBox(height: 24),
        _buildSectionHeader('Portfolio & Links (Optional)', accentColor),
        CustomTextField(
          controller: _studentLinkedinCtrl,
          label: 'LinkedIn URL',
          hint: 'https://linkedin.com/in/...',
          prefixIcon: Icons.link_rounded,
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _studentGithubCtrl,
          label: 'GitHub URL',
          hint: 'https://github.com/...',
          prefixIcon: Icons.code_rounded,
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _studentPortfolioCtrl,
          label: 'Portfolio Website',
          hint: 'https://yourwebsite.com',
          prefixIcon: Icons.language_rounded,
        ),
      ],
    );
  }

  Widget _buildTeacherForm(Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Professional Identity', accentColor),
        CustomTextField(
          controller: _teacherTitleCtrl,
          label: 'Professional Title',
          hint: 'e.g., Senior Data Scientist, English Professor',
          prefixIcon: Icons.work_rounded,
          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _teacherExperienceCtrl,
          label: 'Years of Experience',
          hint: 'e.g., 5',
          prefixIcon: Icons.timeline_rounded,
          keyboardType: TextInputType.number,
          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _teacherIndustryCtrl,
          label: 'Industry',
          hint: 'e.g., Technology, Academia',
          prefixIcon: Icons.business_center_rounded,
          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 24),
        _buildSectionHeader('Teaching Details', accentColor),
        CustomTextField(
          controller: _teacherSubjectsCtrl,
          label: 'Subjects Taught',
          hint: 'Comma separated (e.g., Math, Physics)',
          prefixIcon: Icons.menu_book_rounded,
          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _teacherSkillsTaughtCtrl,
          label: 'Specific Skills Taught',
          hint: 'Comma separated (e.g., Flutter, UI Design)',
          prefixIcon: Icons.star_rounded,
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _teacherCertificationsCtrl,
          label: 'Certifications',
          hint: 'Comma separated',
          prefixIcon: Icons.badge_rounded,
        ),
        const SizedBox(height: 24),
        _buildSectionHeader('Profile details', accentColor),
        CustomTextField(
          controller: _teacherLinkedinCtrl,
          label: 'LinkedIn URL',
          hint: 'https://linkedin.com/in/...',
          prefixIcon: Icons.link_rounded,
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _teacherBioCtrl,
          label: 'Bio',
          hint: 'Tell us about your teaching philosophy...',
          prefixIcon: Icons.history_rounded,
          maxLines: 4,
        ),
      ],
    );
  }

  Widget _buildFreelancerForm(Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Professional Identity', accentColor),
        CustomTextField(
          controller: _freelancerTitleCtrl,
          label: 'Professional Title',
          hint: 'e.g., UI/UX Designer, React Developer',
          prefixIcon: Icons.work_rounded,
          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _freelancerCategoryCtrl,
          label: 'Category',
          hint: 'e.g., Design, Software Development',
          prefixIcon: Icons.category_rounded,
          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _freelancerExperienceCtrl,
          label: 'Years of Experience',
          hint: 'e.g., 3',
          prefixIcon: Icons.timeline_rounded,
          keyboardType: TextInputType.number,
          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 24),
        _buildSectionHeader('Services & Rates', accentColor),
        CustomTextField(
          controller: _freelancerServicesCtrl,
          label: 'Services Offered',
          hint: 'Comma separated (e.g., Web Design, App Dev)',
          prefixIcon: Icons.design_services_rounded,
          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _freelancerHourlyRateCtrl,
          label: 'Hourly Rate (\$)',
          hint: 'e.g., 50.00',
          prefixIcon: Icons.attach_money_rounded,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 24),
        _buildSectionHeader('Portfolio & Bio', accentColor),
        CustomTextField(
          controller: _freelancerPortfolioCtrl,
          label: 'Portfolio URL',
          hint: 'https://yourportfolio.com',
          prefixIcon: Icons.language_rounded,
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _freelancerLinkedinCtrl,
          label: 'LinkedIn URL',
          hint: 'https://linkedin.com/in/...',
          prefixIcon: Icons.link_rounded,
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _freelancerBioCtrl,
          label: 'Bio',
          hint: 'Tell clients why they should hire you...',
          prefixIcon: Icons.description_rounded,
          maxLines: 4,
        ),
      ],
    );
  }

  Widget _buildCompanyForm(Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Company Details', accentColor),
        CustomTextField(
          controller: _companyNameCtrl,
          label: 'Company Name',
          hint: 'e.g., Tech Innovators Inc.',
          prefixIcon: Icons.business_rounded,
          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _companyIndustryCtrl,
          label: 'Industry',
          hint: 'e.g., Software, Finance, Healthcare',
          prefixIcon: Icons.domain_rounded,
          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        ResponsivePair(
          first: CustomTextField(
            controller: _companySizeCtrl,
            label: 'Company Size',
            hint: 'e.g., 50-200',
            prefixIcon: Icons.people_rounded,
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
          second: CustomTextField(
            controller: _companyFoundedYearCtrl,
            label: 'Founded Year',
            hint: 'e.g., 2015',
            prefixIcon: Icons.calendar_today_rounded,
            keyboardType: TextInputType.number,
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionHeader('Contact Information', accentColor),
        CustomTextField(
          controller: _companyWebsiteCtrl,
          label: 'Website',
          hint: 'https://company.com',
          prefixIcon: Icons.language_rounded,
          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _companyEmailCtrl,
          label: 'Official Email',
          hint: 'contact@company.com',
          prefixIcon: Icons.email_rounded,
          keyboardType: TextInputType.emailAddress,
          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _companyPhoneCtrl,
          label: 'Phone Number',
          hint: '+1 (555) 000-0000',
          prefixIcon: Icons.phone_rounded,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 24),
        _buildSectionHeader('About', accentColor),
        CustomTextField(
          controller: _companyDescriptionCtrl,
          label: 'Company Description',
          hint: 'What does your company do?',
          prefixIcon: Icons.info_rounded,
          maxLines: 4,
          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
        ),
      ],
    );
  }

  Widget _buildBottomCTA(BuildContext context, bool isLoading) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF060A18).withValues(alpha: 0.0),
            const Color(0xFF060A18).withValues(alpha: 0.8),
            const Color(0xFF060A18),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: double.infinity,
        height: 58,
        decoration: BoxDecoration(
          gradient: _selectedRole != null
              ? LinearGradient(
                  colors: _roleGradients[_selectedRole!]!,
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: _selectedRole == null
              ? (Theme.of(context).brightness == Brightness.dark
                    ? AppColors.cardLight
                    : Colors.white)
              : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _selectedRole != null
              ? [
                  BoxShadow(
                    color: _roleGradients[_selectedRole!]![0].withValues(
                      alpha: 0.4,
                    ),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _selectedRole != null && !isLoading ? _handleContinue : null,
            borderRadius: BorderRadius.circular(16),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _selectedRole != null
                              ? _step == 3
                                    ? 'Complete Profile Setup'
                                    : 'Continue as ${_selectedRole!.label}'
                              : 'Select a role to continue',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: _selectedRole != null
                                    ? Colors.white
                                    : AppColors.textDisabled,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                        ),
                        if (_selectedRole != null) ...[
                          const SizedBox(width: 10),
                          Icon(
                            _step == 3
                                ? Icons.check_circle_outline_rounded
                                : Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Premium Role Card
// ─────────────────────────────────────────────────────────────────────────────

class _PremiumRoleCard extends StatelessWidget {
  const _PremiumRoleCard({
    required this.role,
    required this.isSelected,
    required this.gradientColors,
    required this.emoji,
    required this.pulseController,
    required this.onTap,
  });

  final UserRole role;
  final bool isSelected;
  final List<Color> gradientColors;
  final String emoji;
  final AnimationController pulseController;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = gradientColors[0];

    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: pulseController,
        builder: (context, child) {
          final pulseValue = isSelected
              ? 0.15 + (pulseController.value * 0.15)
              : 0.0;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              // Glassmorphism background
              color: isSelected
                  ? primary.withValues(alpha: 0.08)
                  : AppColors.card.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isSelected
                    ? primary.withValues(alpha: 0.5)
                    : AppColors.cardBorder.withValues(alpha: 0.4),
                width: isSelected ? 1.5 : 1,
              ),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: primary.withValues(alpha: pulseValue),
                    blurRadius: 30,
                    spreadRadius: 2,
                  ),
                // Subtle depth shadow always present
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: child,
          );
        },
        child: Row(
          children: [
            // ─── Icon Container ─────────────────────────────────
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: isSelected
                    ? LinearGradient(
                        colors: gradientColors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isSelected
                    ? null
                    : (Theme.of(context).brightness == Brightness.dark
                          ? AppColors.cardLight
                          : Colors.white),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: primary.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Background emoji (subtle)
                  if (!isSelected)
                    Opacity(
                      opacity: 0.15,
                      child: Text(emoji, style: const TextStyle(fontSize: 28)),
                    ),
                  Icon(
                    role.icon,
                    size: 28,
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),

            // ─── Text Content ────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    role.label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: isSelected ? primary : AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    role.description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isSelected
                          ? primary.withValues(alpha: 0.7)
                          : AppColors.textTertiary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            // ─── Selection Indicator ─────────────────────────────
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isSelected
                    ? LinearGradient(
                        colors: gradientColors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isSelected ? null : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? Colors.transparent
                      : AppColors.textTertiary.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ambient Background Orb
// ─────────────────────────────────────────────────────────────────────────────

class _AmbientOrb extends StatelessWidget {
  const _AmbientOrb({
    this.top,
    this.bottom,
    this.left,
    this.right,
    required this.size,
    required this.color,
  });

  final double? top;
  final double? bottom;
  final double? left;
  final double? right;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0.0)],
          ),
        ),
      ),
    );
  }
}
