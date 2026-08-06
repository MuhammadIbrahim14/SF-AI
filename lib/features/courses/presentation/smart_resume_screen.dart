import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/user_role.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';
import '../providers/resume_provider.dart';
import 'course_premium_widgets.dart';

class SmartResumeScreen extends ConsumerWidget {
  const SmartResumeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumeAsync = ref.watch(smartResumeProvider);
    final actionState = ref.watch(resumeActionProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return RoleFixedHeaderPage(
      role: UserRole.student,
      title: 'Career Identity',
      subtitle: 'Generate and refresh your verified smart resume snapshot.',
      showBackButton: true,
      onBack: () => context.canPop()
          ? context.pop()
          : context.goNamed(RouteNames.studentDashboard),
      scrollable: false,
      child: CoursePremiumBackground(
        child: resumeAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => CoursePremiumMessage(
            icon: Icons.error_outline_rounded,
            title: 'Identity system offline',
            message: error.toString(),
          ),
          data: (resume) {
            return CoursePremiumListView(
              maxWidth: 1000,
              children: [
                CourseHeroHeader(
                  icon: Icons.fingerprint_rounded,
                  title: 'Smart Resume Builder',
                  subtitle:
                      'A verified, deterministic snapshot of your employability based on your real LMS performance.',
                  trailing: FilledButton.icon(
                    onPressed: actionState.isLoading
                        ? null
                        : () => _generate(context, ref),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: actionState.isLoading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            resume == null
                                ? Icons.auto_awesome_rounded
                                : Icons.refresh_rounded,
                          ),
                    label: Text(
                      resume == null ? 'Generate Identity' : 'Refresh Snapshot',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                if (resume == null)
                  Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.05),
                          blurRadius: 40,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          child: Icon(
                            Icons.document_scanner_rounded,
                            size: 48,
                            color: AppColors.primary.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'No Verified Identity Found',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Complete assignments, projects, and grand tests to build your initial smart resume data.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 32),
                        FilledButton.icon(
                          onPressed: actionState.isLoading
                              ? null
                              : () => _generate(context, ref),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 20,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: const Icon(Icons.auto_awesome_rounded),
                          label: const Text(
                            'Generate Initial Snapshot',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  // Hero Score Card
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLowest
                          .withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.3,
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 40,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.3),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 120,
                                height: 120,
                                child: CircularProgressIndicator(
                                  value: (resume.resumeScore / 100).clamp(
                                    0.0,
                                    1.0,
                                  ),
                                  strokeWidth: 8,
                                  color: AppColors.primary,
                                  backgroundColor: AppColors.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  strokeCap: StrokeCap.round,
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    resume.resumeScore.toStringAsFixed(0),
                                    style: theme.textTheme.headlineMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.primary,
                                          height: 1.0,
                                        ),
                                  ),
                                  Text(
                                    'SCORE',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: theme.colorScheme.onSurfaceVariant,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 32),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: AppColors.success.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.verified_rounded,
                                          size: 12,
                                          color: AppColors.success,
                                        ),
                                        const SizedBox(width: 6),
                                        const Text(
                                          'VERIFIED METRIC',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                            color: AppColors.success,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Employability Score',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'This score represents the deterministic strength of your resume based on your verified skills, projects, and platform certifications.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Headline & Preview Card
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLowest
                          .withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.3,
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 40,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: theme.colorScheme.outlineVariant
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              child: Icon(
                                Icons.format_quote_rounded,
                                color: AppColors.primary.withValues(alpha: 0.8),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    resume.headline,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    resume.summary,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      height: 1.6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Divider(
                          color: theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.3,
                          ),
                        ),
                        const SizedBox(height: 24),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isMobile = constraints.maxWidth < 500;
                            return isMobile
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        'Document ready for rendering',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: theme
                                              .colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      FilledButton.icon(
                                        onPressed: () => context.pushNamed(
                                          RouteNames.studentResumePreview,
                                        ),
                                        style: FilledButton.styleFrom(
                                          padding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 24,
                                            vertical: 16,
                                          ),
                                          backgroundColor:
                                              AppColors.primary,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.visibility_rounded,
                                          size: 18,
                                        ),
                                        label: const Text(
                                          'Preview Layout',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Document ready for rendering',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: theme
                                              .colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      FilledButton.icon(
                                        onPressed: () => context.pushNamed(
                                          RouteNames.studentResumePreview,
                                        ),
                                        style: FilledButton.styleFrom(
                                          padding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 24,
                                            vertical: 16,
                                          ),
                                          backgroundColor:
                                              AppColors.primary,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.visibility_rounded,
                                          size: 18,
                                        ),
                                        label: const Text(
                                          'Preview Layout',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                          },
                        ),
                        const SizedBox(height: 24),
                        Divider(
                          color: theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.3,
                          ),
                        ),
                        const SizedBox(height: 24),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isMobile = constraints.maxWidth < 500;
                            return isMobile
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        'Document ready for rendering',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: theme
                                              .colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      FilledButton.icon(
                                        onPressed: () => context.pushNamed(
                                          RouteNames.studentResumePreview,
                                        ),
                                        style: FilledButton.styleFrom(
                                          padding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 24,
                                            vertical: 16,
                                          ),
                                          backgroundColor:
                                              AppColors.primary,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.visibility_rounded,
                                          size: 18,
                                        ),
                                        label: const Text(
                                          'Preview Layout',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Document ready for rendering',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: theme
                                              .colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      FilledButton.icon(
                                        onPressed: () => context.pushNamed(
                                          RouteNames.studentResumePreview,
                                        ),
                                        style: FilledButton.styleFrom(
                                          padding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 24,
                                            vertical: 16,
                                          ),
                                          backgroundColor:
                                              AppColors.primary,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.visibility_rounded,
                                          size: 18,
                                        ),
                                        label: const Text(
                                          'Preview Layout',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Bento Grid Sections
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 700;
                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  _BentoSection(
                                    title: 'Verified Skills',
                                    icon: Icons.bolt_rounded,
                                    color: AppColors.primary,
                                    emptyText: 'No verified skill scores yet.',
                                    items: resume.verifiedSkills
                                        .map(
                                          (s) =>
                                              '${s.skillName} • ${s.score.toStringAsFixed(0)}%',
                                        )
                                        .toList(),
                                  ),
                                  const SizedBox(height: 24),
                                  _BentoSection(
                                    title: 'Strengths',
                                    icon: Icons.trending_up_rounded,
                                    color: AppColors.success,
                                    emptyText:
                                        'Strengths appear after verified evidence exists.',
                                    items: resume.strengths,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: Column(
                                children: [
                                  _BentoSection(
                                    title: 'Certificates',
                                    icon: Icons.workspace_premium_rounded,
                                    color: Colors.amber,
                                    emptyText: 'No active certificates yet.',
                                    items: resume.certificates
                                        .map((c) => c.title)
                                        .toList(),
                                  ),
                                  const SizedBox(height: 24),
                                  _BentoSection(
                                    title: 'Areas for Growth',
                                    icon: Icons.lightbulb_outline_rounded,
                                    color: AppColors.warning,
                                    emptyText:
                                        'No improvement suggestions yet.',
                                    items: resume.improvementAreas,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      } else {
                        return Column(
                          children: [
                            _BentoSection(
                              title: 'Verified Skills',
                              icon: Icons.bolt_rounded,
                              color: AppColors.primary,
                              emptyText: 'No verified skill scores yet.',
                              items: resume.verifiedSkills
                                  .map(
                                    (s) =>
                                        '${s.skillName} • ${s.score.toStringAsFixed(0)}%',
                                  )
                                  .toList(),
                            ),
                            const SizedBox(height: 24),
                            _BentoSection(
                              title: 'Certificates',
                              icon: Icons.workspace_premium_rounded,
                              color: Colors.amber,
                              emptyText: 'No active certificates yet.',
                              items: resume.certificates
                                  .map((c) => c.title)
                                  .toList(),
                            ),
                            const SizedBox(height: 24),
                            _BentoSection(
                              title: 'Strengths',
                              icon: Icons.trending_up_rounded,
                              color: AppColors.success,
                              emptyText:
                                  'Strengths appear after verified evidence exists.',
                              items: resume.strengths,
                            ),
                            const SizedBox(height: 24),
                            _BentoSection(
                              title: 'Areas for Growth',
                              icon: Icons.lightbulb_outline_rounded,
                              color: AppColors.warning,
                              emptyText: 'No improvement suggestions yet.',
                              items: resume.improvementAreas,
                            ),
                          ],
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 40),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _generate(BuildContext context, WidgetRef ref) async {
    final success = await ref
        .read(resumeActionProvider.notifier)
        .generateMyResume();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Identity snapshot generated successfully.'
              : ref.read(resumeActionProvider.notifier).errorMessage ??
                    'Failed to generate identity snapshot.',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: success ? AppColors.success : AppColors.error,
      ),
    );
  }
}

class _BentoSection extends StatelessWidget {
  const _BentoSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.emptyText,
    required this.items,
  });

  final String title;
  final IconData icon;
  final Color color;
  final String emptyText;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.2)),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (items.isEmpty)
            Text(
              emptyText,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            )
          else if (isMobile && items.length > 3)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: items
                    .map((item) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _BentoPill(text: item, color: color),
                        ))
                    .toList(),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 12,
              children: items
                  .map((item) => _BentoPill(text: item, color: color))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _BentoPill extends StatelessWidget {
  const _BentoPill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
