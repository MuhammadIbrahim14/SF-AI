import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:intl/intl.dart';

import '../../../app/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/user_role.dart';
import '../../../providers/pdf_export_provider.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';
import '../data/models/smart_resume_model.dart';
import '../pdf/resume_design_config.dart';
import '../providers/resume_provider.dart';
import '../providers/studio_provider.dart';
import 'course_premium_widgets.dart';
import 'resume_studio_screen.dart';

class ResumePreviewScreen extends ConsumerWidget {
  const ResumePreviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumeAsync = ref.watch(smartResumeProvider);
    final designConfig = ref.watch(resumeDesignConfigProvider);
    final resumeForAction = resumeAsync.value;
    final exportState = ref.watch(pdfExportActionProvider);

    return RoleFixedHeaderPage(
      role: UserRole.student,
      title: 'Resume Layout',
      subtitle: 'Preview your verified auto-generated resume.',
      showBackButton: true,
      onBack: () => context.canPop()
          ? context.pop()
          : context.goNamed(RouteNames.studentResume),
      actions: resumeForAction == null
          ? null
          : [
              OutlinedButton.icon(
                onPressed: exportState.isLoading
                    ? null
                    : () => _openResumeStudio(context, resumeForAction),
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: const Text('Customize'),
              ),
              FilledButton.icon(
                onPressed: exportState.isLoading
                    ? null
                    : () => _exportResumePdf(
                        context,
                        ref,
                        resumeForAction,
                        designConfig,
                      ),
                icon: exportState.isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_rounded, size: 18),
                label: const Text('Download PDF'),
              ),
            ],
      scrollable: false,
      child: CoursePremiumBackground(
        child: resumeAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => CoursePremiumMessage(
            icon: Icons.error_outline_rounded,
            title: 'Resume unavailable',
            message: error.toString(),
          ),
          data: (resume) {
            if (resume == null) {
              return CoursePremiumMessage(
                icon: Icons.document_scanner_outlined,
                title: 'No snapshot generated',
                message:
                    'Return to the builder to generate your smart resume snapshot first.',
                actionLabel: 'Return to Builder',
                onAction: () => context.goNamed(RouteNames.studentResume),
              );
            }

            return CoursePremiumListView(
              maxWidth: 900,
              children: [
                FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: 595,
                    child: _ResumePaper(resume: resume, config: designConfig),
                  ),
                ),
                const SizedBox(height: 24),
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'This document is auto-generated deterministically from your verified SkillForge activity.\nUse Download PDF to export an ATS-friendly copy.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            );
          },
        ),
      ),
    );
  }
}

Future<void> _exportResumePdf(
  BuildContext context,
  WidgetRef ref,
  SmartResumeModel resume,
  ResumeDesignConfig designConfig,
) async {
  final success = await ref
      .read(pdfExportActionProvider.notifier)
      .exportResume(resume, designConfig: designConfig);
  if (!context.mounted) return;

  final message = success
      ? 'Smart Resume PDF is ready.'
      : ref.read(pdfExportActionProvider.notifier).errorMessage ??
            'Unable to export Smart Resume PDF.';
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

void _openResumeStudio(BuildContext context, SmartResumeModel resume) {
  FocusManager.instance.primaryFocus?.unfocus();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    final size = MediaQuery.sizeOf(context);
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(
            horizontal: size.width < 700 ? 8 : 32,
            vertical: size.height < 700 ? 8 : 24,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 1180,
              maxHeight: size.height * 0.92,
            ),
            child: ResumeStudioScreen(resume: resume),
          ),
        );
      },
    );
  });
}

class _ResumePaper extends StatelessWidget {
  const _ResumePaper({required this.resume, required this.config});

  final SmartResumeModel resume;
  final ResumeDesignConfig config;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: config.templateStyle == ResumeTemplateStyle.minimal
                ? 6
                : 12,
            decoration: BoxDecoration(
              color: _accentColorFor(config.accentColor),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(11),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            resume.headline.trim().isEmpty
                                ? 'Verified Smart Resume'
                                : resume.headline,
                            style: TextStyle(
                              fontFamily: _fontFamilyFor(
                                config.typographyStyle,
                              ),
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _accentColorFor(
                                config.accentColor,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _accentColorFor(
                                  config.accentColor,
                                ).withValues(alpha: 0.2),
                              ),
                            ),
                            child: Text(
                              'SCORE ${resume.resumeScore.toStringAsFixed(0)}',
                              style: TextStyle(
                                color: _accentColorFor(config.accentColor),
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _StatBadge(
                      label: 'Skills',
                      value: resume.verifiedSkills.length.toString(),
                      config: config,
                    ),
                    _StatBadge(
                      label: 'Projects',
                      value: resume.projects.length.toString(),
                      config: config,
                    ),
                    _StatBadge(
                      label: 'Certificates',
                      value: resume.certificates.length.toString(),
                      config: config,
                    ),
                    _StatBadge(
                      label: 'Updated',
                      value: DateFormat('MMM d').format(resume.updatedAt),
                      config: config,
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                ..._visiblePreviewSections(resume, config, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({
    required this.label,
    required this.value,
    required this.config,
  });

  final String label;
  final String value;
  final ResumeDesignConfig config;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = _accentColorFor(config.accentColor);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252525) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

Color _accentColorFor(ResumeAccentColor color) {
  return switch (color) {
    ResumeAccentColor.skillforgeBlue => const Color(0xFF2563EB),
    ResumeAccentColor.emerald => const Color(0xFF059669),
    ResumeAccentColor.purple => const Color(0xFF7C3AED),
    ResumeAccentColor.slate => const Color(0xFF475569),
  };
}

String _fontFamilyFor(ResumeTypographyStyle style) {
  return switch (style) {
    ResumeTypographyStyle.modern => 'Segoe UI',
    ResumeTypographyStyle.classic => 'Georgia',
    ResumeTypographyStyle.compact => 'Arial',
    ResumeTypographyStyle.bold => 'Impact',
  };
}

List<Widget> _visiblePreviewSections(
  SmartResumeModel resume,
  ResumeDesignConfig config,
  bool isDark,
) {
  final sections = <Widget>[];
  final accent = _accentColorFor(config.accentColor);

  Widget sectionTitle(String text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            color: accent,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 1,
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  for (final section in config.sectionOrder) {
    if (!config.visibleSections.contains(section)) continue;

    switch (section) {
      case ResumeSection.summary:
        if (resume.summary.trim().isNotEmpty) {
          sections.addAll([
            sectionTitle('Professional Summary'),
            Text(
              resume.summary,
              style: TextStyle(
                height: 1.6,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 32),
          ]);
        }
      case ResumeSection.skills:
        if (resume.verifiedSkills.isNotEmpty) {
          sections.addAll([
            sectionTitle('Verified Skills'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: resume.verifiedSkills
                  .map((s) => _SkillChip(skill: s))
                  .toList(),
            ),
            const SizedBox(height: 32),
          ]);
        }
      case ResumeSection.projects:
        if (resume.projects.isNotEmpty) {
          sections.addAll([
            sectionTitle('Projects'),
            ...resume.projects.map((p) => _ProjectTile(project: p)),
            const SizedBox(height: 32),
          ]);
        }
      case ResumeSection.certificates:
        if (resume.certificates.isNotEmpty) {
          sections.addAll([
            sectionTitle('Certificates'),
            ...resume.certificates.map((c) => _CertificateTile(certificate: c)),
            const SizedBox(height: 32),
          ]);
        }
      case ResumeSection.skillScores:
        if (resume.verifiedSkills.isNotEmpty) {
          sections.addAll([
            sectionTitle('Skill Scores'),
            ...resume.verifiedSkills.map((s) => _SkillScoreTile(skill: s)),
            const SizedBox(height: 32),
          ]);
        }
      case ResumeSection.strengths:
        if (resume.strengths.isNotEmpty) {
          sections.addAll([
            sectionTitle('Strengths'),
            ...resume.strengths.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '•',
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s,
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ]);
        }
      case ResumeSection.education:
        if (resume.education.trim().isNotEmpty) {
          sections.addAll([
            sectionTitle('Education'),
            Text(
              resume.education,
              style: TextStyle(
                height: 1.6,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 32),
          ]);
        }
      case ResumeSection.links:
        if (resume.projects.any(
          (p) =>
              p.githubLink.trim().isNotEmpty ||
              p.liveDemoLink.trim().isNotEmpty,
        )) {
          final links = resume.projects
              .expand(
                (p) => [
                  if (p.githubLink.trim().isNotEmpty)
                    '${p.title}: ${p.githubLink}',
                  if (p.liveDemoLink.trim().isNotEmpty)
                    '${p.title}: ${p.liveDemoLink}',
                ],
              )
              .toList();

          sections.addAll([
            sectionTitle('Links'),
            ...links.map(
              (link) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  link,
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black87,
                    decoration: TextDecoration.underline,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ]);
        }
      case ResumeSection.achievements:
        if (resume.achievements.isNotEmpty) {
          sections.addAll([
            sectionTitle('Achievements'),
            ...resume.achievements.map((item) {
              final text = item.description.trim().isEmpty
                  ? item.title
                  : '${item.title}: ${item.description}';
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  text,
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black87,
                    fontSize: 13,
                  ),
                ),
              );
            }),
            const SizedBox(height: 32),
          ]);
        }
      case ResumeSection.improvementAreas:
        if (resume.improvementAreas.isNotEmpty) {
          sections.addAll([
            sectionTitle('Improvement Areas'),
            ...resume.improvementAreas.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '•',
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ]);
        }
    }
  }
  return sections;
}

class _SkillScoreTile extends StatelessWidget {
  const _SkillScoreTile({required this.skill});
  final ResumeSkill skill;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              skill.skillName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          Text(
            '${skill.score.toStringAsFixed(0)}%',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _SkillChip extends StatelessWidget {
  const _SkillChip({required this.skill});
  final ResumeSkill skill;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        skill.skillName,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _ProjectTile extends StatelessWidget {
  const _ProjectTile({required this.project});
  final ResumeProject project;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  project.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'GRADE: ${project.score.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ),
          if (project.skills.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              project.skills.join(' • '),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: AppColors.studentPrimary,
              ),
            ),
          ],
          const SizedBox(height: 8),
          if (project.description.trim().isNotEmpty)
            Text(
              project.description,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87,
                fontSize: 14,
                height: 1.5,
              ),
            ),
        ],
      ),
    );
  }
}

class _CertificateTile extends StatelessWidget {
  const _CertificateTile({required this.certificate});
  final ResumeCertificate certificate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.workspace_premium_rounded,
            size: 20,
            color: Colors.amber.shade600,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  certificate.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${certificate.courseTitle} • ID: ${certificate.verificationCode}',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
