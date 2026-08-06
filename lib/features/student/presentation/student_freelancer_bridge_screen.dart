import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/router/route_names.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/user_role.dart';
import '../../../models/verified_skill_model.dart';
import '../../../providers/user_provider.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';
import '../../profile/providers/public_profile_provider.dart';
import '../providers/student_freelancer_bridge_provider.dart';

class StudentFreelancerBridgeScreen extends ConsumerStatefulWidget {
  const StudentFreelancerBridgeScreen({super.key});

  @override
  ConsumerState<StudentFreelancerBridgeScreen> createState() =>
      _StudentFreelancerBridgeScreenState();
}

class _StudentFreelancerBridgeScreenState
    extends ConsumerState<StudentFreelancerBridgeScreen> {
  final _headlineController = TextEditingController();
  final _bioController = TextEditingController();
  final _categoryController = TextEditingController(
    text: 'Flutter Development',
  );
  final _publicSkillIds = <String>{};

  @override
  void dispose() {
    _headlineController.dispose();
    _bioController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skillsAsync = ref.watch(verifiedStudentSkillsProvider);
    final readinessAsync = ref.watch(freelancerReadinessProvider);
    final actionState = ref.watch(freelancerShowcaseActionProvider);
    final user = ref.watch(currentUserProvider).value;
    final publicProfile = ref.watch(myPublicProfileProvider).value;
    final unlocked = user?.freelancerUnlocked == true;
    final freelancerMode =
        user?.primaryRoleEnum == UserRole.freelancer;

    return RoleFixedHeaderPage(
      role: UserRole.student,
      title: 'Freelancer Bridge',
      subtitle:
          'Meet the Ready threshold, unlock freelancer capability, then toggle modes.',
      showBackButton: true,
      onBack: () => context.canPop()
          ? context.pop()
          : context.goNamed(RouteNames.studentDashboard),
      scrollable: false,
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(verifiedStudentSkillsProvider);
          ref.invalidate(freelancerReadinessProvider);
          ref.invalidate(myPublicProfileProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
          children: [
            _ModeToggleCard(
              unlocked: unlocked,
              freelancerMode: freelancerMode,
              switching: ref.watch(roleNotifierProvider).isLoading,
              onToggle: (toFreelancer) => _switchMode(toFreelancer),
            ),
            const SizedBox(height: 18),
            readinessAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => _InfoCard(
                title: 'Readiness unavailable',
                message: error.toString(),
              ),
              data: (readiness) => _ReadinessCard(readiness: readiness),
            ),
            const SizedBox(height: 18),
            if (unlocked) ...[
              _UnlockedActionsCard(
                hasPublicProfile: publicProfile != null,
                publicSlug: publicProfile?.slug,
                freelancerMode: freelancerMode,
                onPreview: () => _previewPublicProfile(publicProfile?.slug),
                onCreateService: () {
                  if (!freelancerMode) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Switch to Freelancer mode to create paid services.',
                        ),
                      ),
                    );
                    return;
                  }
                  context.pushNamed(RouteNames.freelancerServiceCreate);
                },
              ),
              const SizedBox(height: 18),
            ],
            skillsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _InfoCard(
                title: 'Verified skills unavailable',
                message: error.toString(),
              ),
              data: (skills) {
                final eligible =
                    readinessAsync.asData?.value.isEligible ?? false;
                return _BridgeForm(
                  skills: skills,
                  actionState: actionState,
                  publicSkillIds: _publicSkillIds,
                  headlineController: _headlineController,
                  bioController: _bioController,
                  categoryController: _categoryController,
                  canActivate: eligible && !unlocked,
                  alreadyUnlocked: unlocked,
                  onToggleSkill: (skillId, selected) {
                    setState(() {
                      if (selected) {
                        _publicSkillIds.add(skillId);
                      } else {
                        _publicSkillIds.remove(skillId);
                      }
                    });
                  },
                  onSyncSkills: () async {
                    final success = await ref
                        .read(freelancerShowcaseActionProvider.notifier)
                        .syncVerifiedSkills(skills);
                    if (!context.mounted) return;
                    final error = ref
                        .read(freelancerShowcaseActionProvider.notifier)
                        .errorMessage;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? 'Verified skills synced.'
                              : (error ?? 'Unable to sync verified skills.'),
                        ),
                      ),
                    );
                  },
                  onActivate: (eligible || unlocked)
                      ? () => _activate(context, ref, skills)
                      : () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Complete the Ready checklist before activating.',
                              ),
                            ),
                          );
                        },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _switchMode(bool toFreelancer) async {
    final target = toFreelancer ? UserRole.freelancer : UserRole.student;
    final success = await ref
        .read(roleNotifierProvider.notifier)
        .setPrimaryRoleOnly(target);
    if (!mounted) return;
    if (!success) {
      final error = ref.read(roleNotifierProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error?.toString() ?? 'Unable to switch mode.'),
        ),
      );
      return;
    }
    if (toFreelancer) {
      context.goNamed(RouteNames.freelancerDashboard);
    } else {
      context.goNamed(RouteNames.studentDashboard);
    }
  }

  Future<void> _previewPublicProfile(String? slug) async {
    final trimmed = slug?.trim() ?? '';
    if (trimmed.isEmpty) {
      context.pushNamed(RouteNames.portfolioBuilder);
      return;
    }
    final settings = ref.read(portfolioSettingsProvider).asData?.value;
    final url = buildPortfolioUrl(
      trimmed,
      baseUrl: settings?.portfolioBaseUrl,
    );
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      context.pushNamed(RouteNames.portfolioBuilder);
    }
  }

  Future<void> _activate(
    BuildContext context,
    WidgetRef ref,
    List<VerifiedSkillModel> skills,
  ) async {
    final alreadyUnlocked =
        ref.read(currentUserProvider).value?.freelancerUnlocked == true;
    final eligibility = ref.read(freelancerReadinessProvider).asData?.value;
    if (!alreadyUnlocked && eligibility?.isEligible != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete the Ready checklist before activating.'),
        ),
      );
      return;
    }
    final publicSkills = skills
        .where((skill) => _publicSkillIds.contains(skill.skillId))
        .toList();
    if (publicSkills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one public skill.')),
      );
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Activate Freelancer Bridge?'),
        content: const Text(
          'This publishes your showcase and unlocks freelancer capability. '
          'Your student role and LMS data stay intact. Mode stays Student until you toggle.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Activate'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final success = await ref
        .read(freelancerShowcaseActionProvider.notifier)
        .activateShowcase(
          headline: _headlineController.text,
          bio: _bioController.text,
          serviceCategory: _categoryController.text,
          publicSkills: publicSkills,
        );
    if (!context.mounted) return;
    final error = ref.read(freelancerShowcaseActionProvider.notifier).errorMessage;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Showcase activated. Freelancer capability unlocked — stay in Student mode or switch when ready.'
              : (error ?? _friendlyActivateError(ref.read(freelancerShowcaseActionProvider).error)),
        ),
      ),
    );
  }

  String _friendlyActivateError(Object? error) {
    if (error is AppException) return error.message;
    final text = error?.toString() ?? '';
    if (text.contains('permission-denied') ||
        text.toLowerCase().contains('permission')) {
      return 'Permission denied while activating showcase. Check your session and try again.';
    }
    if (text.isNotEmpty) return text;
    return 'Unable to activate showcase.';
  }
}

class _ModeToggleCard extends StatelessWidget {
  const _ModeToggleCard({
    required this.unlocked,
    required this.freelancerMode,
    required this.switching,
    required this.onToggle,
  });

  final bool unlocked;
  final bool freelancerMode;
  final bool switching;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Learning / Freelancer Mode',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            unlocked
                ? 'Unlocked. Toggle primary role without creating a second account.'
                : 'Disabled until you Activate Showcase and unlock freelancer capability.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Student'), icon: Icon(Icons.school_rounded)),
              ButtonSegment(
                value: true,
                label: Text('Freelancer'),
                icon: Icon(Icons.work_rounded),
              ),
            ],
            selected: {freelancerMode},
            onSelectionChanged: !unlocked || switching
                ? null
                : (values) => onToggle(values.first),
          ),
        ],
      ),
    );
  }
}

class _UnlockedActionsCard extends StatelessWidget {
  const _UnlockedActionsCard({
    required this.hasPublicProfile,
    required this.publicSlug,
    required this.freelancerMode,
    required this.onPreview,
    required this.onCreateService,
  });

  final bool hasPublicProfile;
  final String? publicSlug;
  final bool freelancerMode;
  final VoidCallback onPreview;
  final VoidCallback onCreateService;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Unlocked workspace',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            hasPublicProfile
                ? 'Public showcase is live${publicSlug == null || publicSlug!.isEmpty ? '' : ' · /$publicSlug'}.'
                : 'Showcase unlock recorded. Preview opens Portfolio Builder if the public link is not ready.',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: onPreview,
                icon: const Icon(Icons.visibility_rounded),
                label: const Text('Preview public profile'),
              ),
              FilledButton.icon(
                onPressed: onCreateService,
                icon: const Icon(Icons.add_business_rounded),
                label: Text(
                  freelancerMode
                      ? 'Create paid service'
                      : 'Create paid service (switch mode)',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReadinessCard extends StatelessWidget {
  const _ReadinessCard({required this.readiness});

  final FreelancerReadinessModel readiness;

  @override
  Widget build(BuildContext context) {
    final score = readiness.score.clamp(0, 100).toDouble();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  readiness.isEligible
                      ? 'Ready · ${score.round()}%'
                      : 'Not eligible yet · ${score.round()}%',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Chip(
                avatar: Icon(
                  readiness.isEligible
                      ? Icons.verified_rounded
                      : Icons.hourglass_top_rounded,
                  size: 18,
                ),
                label: Text(readiness.isEligible ? 'Eligible' : 'In progress'),
                backgroundColor: readiness.isEligible
                    ? Colors.green.withValues(alpha: 0.15)
                    : AppColors.studentPrimary.withValues(alpha: 0.1),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '“Ready” means you passed the internal ${FreelancerEligibilityThresholds.copyLabel} gate — not literal 100% perfection.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: score / 100),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Metric('Verified skills', readiness.verifiedSkillCount),
              _Metric('Projects', readiness.completedProjectCount),
              _Metric('Profile', readiness.profileCompletion.round()),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Checklist',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          for (final check in readiness.checks)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                check.passed
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: check.passed ? Colors.green : null,
              ),
              title: Text(check.label),
              subtitle: Text(check.detail),
            ),
          if (readiness.checks.isEmpty)
            for (final item in readiness.recommendations)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.arrow_forward_rounded),
                title: Text(item),
              ),
        ],
      ),
    );
  }
}

/// Copy helper so UI and service stay aligned on the Ready wording.
class FreelancerEligibilityThresholds {
  static const copyLabel = '85% Ready';
}

class _BridgeForm extends StatelessWidget {
  const _BridgeForm({
    required this.skills,
    required this.actionState,
    required this.publicSkillIds,
    required this.headlineController,
    required this.bioController,
    required this.categoryController,
    required this.canActivate,
    required this.alreadyUnlocked,
    required this.onToggleSkill,
    required this.onSyncSkills,
    required this.onActivate,
  });

  final List<VerifiedSkillModel> skills;
  final AsyncValue<void> actionState;
  final Set<String> publicSkillIds;
  final TextEditingController headlineController;
  final TextEditingController bioController;
  final TextEditingController categoryController;
  final bool canActivate;
  final bool alreadyUnlocked;
  final void Function(String skillId, bool selected) onToggleSkill;
  final VoidCallback onSyncSkills;
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    final loading = actionState.isLoading;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            alreadyUnlocked ? 'Update public showcase' : 'Public Showcase Setup',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: headlineController,
            decoration: const InputDecoration(
              labelText: 'Public headline',
              hintText: 'e.g. Junior Flutter Developer with Firebase skills',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: bioController,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Public bio',
              hintText: 'Write what clients can hire you for.',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: categoryController,
            decoration: const InputDecoration(labelText: 'Service category'),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (skills.isEmpty)
                const Text(
                  'No verified skills yet. Complete graded work first.',
                )
              else
                for (final skill in skills)
                  FilterChip(
                    selected: publicSkillIds.contains(skill.skillId),
                    label: Text('${skill.skillName} ${skill.score.round()}%'),
                    onSelected: loading
                        ? null
                        : (selected) => onToggleSkill(skill.skillId, selected),
                  ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: loading ? null : onSyncSkills,
                icon: const Icon(Icons.verified_rounded),
                label: const Text('Sync Verified Skills'),
              ),
              FilledButton.icon(
                onPressed: loading || (!canActivate && !alreadyUnlocked)
                    ? null
                    : onActivate,
                icon: const Icon(Icons.public_rounded),
                label: Text(
                  alreadyUnlocked
                      ? 'Re-publish Showcase'
                      : canActivate
                      ? 'Activate Showcase'
                      : 'Activate (complete checklist)',
                ),
              ),
            ],
          ),
          if (!canActivate && !alreadyUnlocked) ...[
            const SizedBox(height: 10),
            Text(
              'Activate stays locked until every Ready checklist item passes.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: const Icon(Icons.check_circle_rounded, size: 18),
      label: Text('$label: $value'),
      backgroundColor: AppColors.studentPrimary.withValues(alpha: 0.1),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(context),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.info_outline_rounded),
        title: Text(title),
        subtitle: Text(message),
      ),
    );
  }
}

BoxDecoration _cardDecoration(BuildContext context) {
  final theme = Theme.of(context);
  return BoxDecoration(
    color: theme.colorScheme.surfaceContainerLow,
    borderRadius: BorderRadius.circular(24),
    border: Border.all(
      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
    ),
  );
}
