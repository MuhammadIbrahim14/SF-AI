import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/pdf_export_provider.dart';
import '../providers/studio_provider.dart';
import '../data/models/smart_resume_model.dart';
import '../pdf/resume_design_config.dart';

class ResumeStudioScreen extends ConsumerStatefulWidget {
  const ResumeStudioScreen({super.key, required this.resume});

  final SmartResumeModel resume;

  @override
  ConsumerState<ResumeStudioScreen> createState() => _ResumeStudioScreenState();
}

class _ResumeStudioScreenState extends ConsumerState<ResumeStudioScreen> {
  @override
  Widget build(BuildContext context) {
    final exportState = ref.watch(pdfExportActionProvider);
    final config = ref.watch(resumeDesignConfigProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              _StudioHeader(
                onClose: () => Navigator.of(context).maybePop(),
                onReset: () => ref
                    .read(resumeDesignConfigProvider.notifier)
                    .updateConfig(ResumeDesignConfig.standard),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 980;
                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _PreviewPane(
                              resume: widget.resume,
                              config: config,
                            ),
                          ),
                          SizedBox(
                            width: 410,
                            child: _DesignPanel(
                              resume: widget.resume,
                              config: config,
                              scrollable: true,
                              onChanged: (config) => ref
                                  .read(resumeDesignConfigProvider.notifier)
                                  .updateConfig(config),
                            ),
                          ),
                        ],
                      );
                    }

                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      child: Column(
                        children: [
                          _PreviewPane(
                            resume: widget.resume,
                            config: config,
                            compact: true,
                          ),
                          const SizedBox(height: 18),
                          _DesignPanel(
                            resume: widget.resume,
                            config: config,
                            scrollable: false,
                            onChanged: (config) => ref
                                .read(resumeDesignConfigProvider.notifier)
                                .updateConfig(config),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 640;
                    final note = Text(
                      'Design changes are local only. Resume facts still come from your generated Smart Resume snapshot.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    );
                    final button = FilledButton.icon(
                      onPressed: exportState.isLoading
                          ? null
                          : () => _downloadStyledPdf(context),
                      icon: exportState.isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download_rounded),
                      label: const Text('Download styled PDF'),
                    );

                    if (compact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [note, const SizedBox(height: 12), button],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: note),
                        const SizedBox(width: 12),
                        button,
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _downloadStyledPdf(BuildContext context) async {
    final config = ref.read(resumeDesignConfigProvider);
    final success = await ref
        .read(pdfExportActionProvider.notifier)
        .exportResume(widget.resume, designConfig: config);
    if (!context.mounted) return;

    final message = success
        ? 'Styled Smart Resume PDF is ready.'
        : ref.read(pdfExportActionProvider.notifier).errorMessage ??
              'Unable to export styled Smart Resume PDF.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _StudioHeader extends StatelessWidget {
  const _StudioHeader({required this.onClose, required this.onReset});

  final VoidCallback onClose;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.studentPrimary, AppColors.studentSecondary],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.studentPrimary.withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(Icons.description_rounded),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Resume Studio',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  'Customize ATS-friendly presentation without changing facts.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.restart_alt_rounded, size: 18),
            label: const Text('Reset'),
          ),
          IconButton(
            tooltip: 'Close studio',
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _PreviewPane extends StatelessWidget {
  const _PreviewPane({
    required this.resume,
    required this.config,
    this.compact = false,
  });

  final SmartResumeModel resume;
  final ResumeDesignConfig config;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(compact ? 10 : 24),
      color: Colors.transparent,
      child: Center(
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: 595, // A4 portrait width at standard resolution
            height: 842, // A4 portrait height
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: _ResumePreviewPaper(resume: resume, config: config),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.55,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.text_snippet_rounded,
                        color: colorScheme.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Export uses selectable PDF text. Hidden sections are omitted from the styled PDF only.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResumePreviewPaper extends StatelessWidget {
  const _ResumePreviewPaper({required this.resume, required this.config});

  final SmartResumeModel resume;
  final ResumeDesignConfig config;

  @override
  Widget build(BuildContext context) {
    final style = _ResumePreviewStyle.fromConfig(config);
    final sections = _visiblePreviewSections(resume, config);

    return Container(
      decoration: BoxDecoration(
        color: style.paper,
        borderRadius: BorderRadius.circular(
          config.templateStyle == ResumeTemplateStyle.minimal ? 8 : 18,
        ),
        border: Border.all(color: style.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 32,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: config.templateStyle == ResumeTemplateStyle.minimal
                ? 5
                : 10,
            decoration: BoxDecoration(
              color: style.accent,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(
                  config.templateStyle == ResumeTemplateStyle.minimal ? 8 : 18,
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(_previewPadding(config)),
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
                                color: style.text,
                                fontSize: _previewTitleSize(config),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (resume.careerGoal.trim().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                resume.careerGoal,
                                style: TextStyle(
                                  color: style.muted,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: style.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: style.accent.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          'SCORE ${resume.resumeScore.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: style.accent,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      _MetricPill(
                        label: 'Skills',
                        value: resume.verifiedSkills.length.toString(),
                        style: style,
                      ),
                      _MetricPill(
                        label: 'Projects',
                        value: resume.projects.length.toString(),
                        style: style,
                      ),
                      _MetricPill(
                        label: 'Certificates',
                        value: resume.certificates.length.toString(),
                        style: style,
                      ),
                      _MetricPill(
                        label: 'Updated',
                        value: DateFormat('MMM d').format(resume.updatedAt),
                        style: style,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ...sections,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.label,
    required this.value,
    required this.style,
  });

  final String label;
  final String value;
  final _ResumePreviewStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: style.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: style.accent.withValues(alpha: 0.25)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: style.text,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PreviewSection extends StatelessWidget {
  const _PreviewSection({
    required this.title,
    required this.children,
    required this.style,
  });

  final String title;
  final List<Widget> children;
  final _ResumePreviewStyle style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: style.accent,
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Container(height: 1, color: style.border),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _DesignPanel extends StatelessWidget {
  const _DesignPanel({
    required this.resume,
    required this.config,
    required this.onChanged,
    required this.scrollable,
  });

  final SmartResumeModel resume;
  final ResumeDesignConfig config;
  final ValueChanged<ResumeDesignConfig> onChanged;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final panel = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Design Controls',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose layout, density, and which existing sections to export.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          _OptionSection<ResumeTemplateStyle>(
            title: 'Template',
            values: ResumeTemplateStyle.values,
            selected: config.templateStyle,
            onSelected: (value) =>
                onChanged(config.copyWith(templateStyle: value)),
            labelBuilder: (v) => _capitalize(v.name),
          ),
          _OptionSection<ResumeAccentColor>(
            title: 'Accent color',
            values: ResumeAccentColor.values,
            selected: config.accentColor,
            onSelected: (value) =>
                onChanged(config.copyWith(accentColor: value)),
            swatchBuilder: _accentForResumeColor,
          ),
          _OptionSection<ResumeTypographyStyle>(
            title: 'Typography',
            values: ResumeTypographyStyle.values,
            selected: config.typographyStyle,
            onSelected: (value) =>
                onChanged(config.copyWith(typographyStyle: value)),
          ),
          _OptionSection<ResumeDensity>(
            title: 'Spacing density',
            values: ResumeDensity.values,
            selected: config.density,
            onSelected: (value) => onChanged(config.copyWith(density: value)),
          ),
          _SectionOrderPanel(
            resume: resume,
            config: config,
            onChanged: onChanged,
          ),
        ],
      ),
    );

    if (!scrollable) return panel;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
      child: panel,
    );
  }
}

class _OptionSection<T extends Enum> extends StatelessWidget {
  const _OptionSection({
    required this.title,
    required this.values,
    required this.selected,
    required this.onSelected,
    this.swatchBuilder,
    this.labelBuilder,
  });

  final String title;
  final List<T> values;
  final T selected;
  final ValueChanged<T> onSelected;
  final Color Function(T value)? swatchBuilder;
  final String Function(T value)? labelBuilder;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: values.map((value) {
              final isSelected = selected == value;
              final swatchColor = swatchBuilder != null
                  ? swatchBuilder!(value)
                  : null;
              final label = labelBuilder != null
                  ? labelBuilder!(value)
                  : _capitalize(value.name);

              return InkWell(
                onTap: () => onSelected(value),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.1)
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(
                              context,
                            ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (swatchColor != null) ...[
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: swatchColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black12),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w600,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _SectionOrderPanel extends StatelessWidget {
  const _SectionOrderPanel({
    required this.resume,
    required this.config,
    required this.onChanged,
  });

  final SmartResumeModel resume;
  final ResumeDesignConfig config;
  final ValueChanged<ResumeDesignConfig> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sections',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          'Only sections with existing resume data are exported.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        ...config.sectionOrder.map((section) {
          final hasData = _hasSectionData(resume, section);
          final visible = config.visibleSections.contains(section);
          final index = config.sectionOrder.indexOf(section);
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.45),
              ),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: visible,
                  onChanged: hasData
                      ? (value) {
                          final sections = Set<ResumeSection>.of(
                            config.visibleSections,
                          );
                          if (value ?? false) {
                            sections.add(section);
                          } else {
                            sections.remove(section);
                          }
                          onChanged(config.copyWith(visibleSections: sections));
                        }
                      : null,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section.resumeLabel,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      if (!hasData)
                        Text(
                          'No existing data',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Move up',
                  onPressed: index == 0
                      ? null
                      : () => onChanged(
                          config.copyWith(
                            sectionOrder: _moveSection(
                              config.sectionOrder,
                              index,
                              index - 1,
                            ),
                          ),
                        ),
                  icon: const Icon(Icons.keyboard_arrow_up_rounded),
                ),
                IconButton(
                  tooltip: 'Move down',
                  onPressed: index == config.sectionOrder.length - 1
                      ? null
                      : () => onChanged(
                          config.copyWith(
                            sectionOrder: _moveSection(
                              config.sectionOrder,
                              index,
                              index + 1,
                            ),
                          ),
                        ),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

List<Widget> _visiblePreviewSections(
  SmartResumeModel resume,
  ResumeDesignConfig config,
) {
  final style = _ResumePreviewStyle.fromConfig(config);
  final sections = <Widget>[];

  for (final section in config.sectionOrder) {
    if (!config.visibleSections.contains(section)) continue;
    switch (section) {
      case ResumeSection.summary:
        if (resume.summary.trim().isNotEmpty) {
          sections.add(
            _PreviewSection(
              title: 'Professional Summary',
              style: style,
              children: [_PreviewText(resume.summary, style: style)],
            ),
          );
        }
      case ResumeSection.skills:
        if (resume.verifiedSkills.isNotEmpty) {
          sections.add(
            _PreviewSection(
              title: 'Skills',
              style: style,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: resume.verifiedSkills
                      .map(
                        (skill) => _PreviewChip(skill.skillName, style: style),
                      )
                      .toList(),
                ),
              ],
            ),
          );
        }
      case ResumeSection.projects:
        if (resume.projects.isNotEmpty) {
          sections.add(
            _PreviewSection(
              title: 'Projects',
              style: style,
              children: resume.projects
                  .map(
                    (project) => _PreviewText(
                      '${project.title} - ${project.score.toStringAsFixed(0)}%',
                      style: style,
                      weight: FontWeight.w800,
                    ),
                  )
                  .toList(),
            ),
          );
        }
      case ResumeSection.certificates:
        if (resume.certificates.isNotEmpty) {
          sections.add(
            _PreviewSection(
              title: 'Certificates',
              style: style,
              children: resume.certificates
                  .map((cert) => _PreviewText(cert.title, style: style))
                  .toList(),
            ),
          );
        }
      case ResumeSection.skillScores:
        if (resume.verifiedSkills.isNotEmpty) {
          sections.add(
            _PreviewSection(
              title: 'Skill Scores',
              style: style,
              children: resume.verifiedSkills
                  .map(
                    (skill) => _PreviewText(
                      '${skill.skillName}: ${skill.score.toStringAsFixed(0)}% ${skill.level}',
                      style: style,
                    ),
                  )
                  .toList(),
            ),
          );
        }
      case ResumeSection.strengths:
        if (resume.strengths.isNotEmpty) {
          sections.add(
            _PreviewSection(
              title: 'Strengths',
              style: style,
              children: resume.strengths
                  .map((item) => _PreviewText('- $item', style: style))
                  .toList(),
            ),
          );
        }
      case ResumeSection.education:
        if (resume.education.trim().isNotEmpty) {
          sections.add(
            _PreviewSection(
              title: 'Education',
              style: style,
              children: [_PreviewText(resume.education, style: style)],
            ),
          );
        }
      case ResumeSection.links:
        if (_hasSectionData(resume, ResumeSection.links)) {
          sections.add(
            _PreviewSection(
              title: 'Links',
              style: style,
              children: _resumeLinks(
                resume,
              ).map((link) => _PreviewText(link, style: style)).toList(),
            ),
          );
        }
      case ResumeSection.achievements:
        if (resume.achievements.isNotEmpty) {
          sections.add(
            _PreviewSection(
              title: 'Achievements',
              style: style,
              children: resume.achievements
                  .map(
                    (item) => _PreviewText(
                      item.description.trim().isEmpty
                          ? item.title
                          : '${item.title}: ${item.description}',
                      style: style,
                    ),
                  )
                  .toList(),
            ),
          );
        }
      case ResumeSection.improvementAreas:
        if (resume.improvementAreas.isNotEmpty) {
          sections.add(
            _PreviewSection(
              title: 'Improvement Areas',
              style: style,
              children: resume.improvementAreas
                  .map((item) => _PreviewText('- $item', style: style))
                  .toList(),
            ),
          );
        }
    }
  }

  return sections;
}

class _PreviewText extends StatelessWidget {
  const _PreviewText(
    this.text, {
    required this.style,
    this.weight = FontWeight.w600,
  });

  final String text;
  final _ResumePreviewStyle style;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        text,
        style: TextStyle(
          color: style.body,
          fontSize: 13,
          height: 1.45,
          fontWeight: weight,
        ),
      ),
    );
  }
}

class _PreviewChip extends StatelessWidget {
  const _PreviewChip(this.label, {required this.style});

  final String label;
  final _ResumePreviewStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: style.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: style.accent.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: style.text,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ResumePreviewStyle {
  const _ResumePreviewStyle({
    required this.accent,
    required this.paper,
    required this.text,
    required this.body,
    required this.muted,
    required this.border,
  });

  final Color accent;
  final Color paper;
  final Color text;
  final Color body;
  final Color muted;
  final Color border;

  factory _ResumePreviewStyle.fromConfig(ResumeDesignConfig config) {
    final accent = _accentForResumeColor(config.accentColor);
    return _ResumePreviewStyle(
      accent: accent,
      paper: Colors.white,
      text: const Color(0xFF101828),
      body: const Color(0xFF344054),
      muted: const Color(0xFF667085),
      border: config.templateStyle == ResumeTemplateStyle.minimal
          ? const Color(0xFFE5E7EB)
          : accent.withValues(alpha: 0.22),
    );
  }
}

Color _accentForResumeColor(ResumeAccentColor value) {
  return switch (value) {
    ResumeAccentColor.emerald => AppColors.companyPrimary,
    ResumeAccentColor.purple => AppColors.teacherPrimary,
    ResumeAccentColor.slate => const Color(0xFF334155),
    ResumeAccentColor.skillforgeBlue => AppColors.studentPrimary,
  };
}

double _previewPadding(ResumeDesignConfig config) {
  return switch (config.density) {
    ResumeDensity.compact => 24,
    ResumeDensity.comfortable => 42,
    ResumeDensity.balanced => 34,
  };
}

double _previewTitleSize(ResumeDesignConfig config) {
  return switch (config.typographyStyle) {
    ResumeTypographyStyle.compact => 22,
    ResumeTypographyStyle.bold => 28,
    ResumeTypographyStyle.classic => 25,
    ResumeTypographyStyle.modern => 26,
  };
}

bool _hasSectionData(SmartResumeModel resume, ResumeSection section) {
  return switch (section) {
    ResumeSection.summary => resume.summary.trim().isNotEmpty,
    ResumeSection.skills => resume.verifiedSkills.isNotEmpty,
    ResumeSection.projects => resume.projects.isNotEmpty,
    ResumeSection.certificates => resume.certificates.isNotEmpty,
    ResumeSection.skillScores => resume.verifiedSkills.isNotEmpty,
    ResumeSection.strengths => resume.strengths.isNotEmpty,
    ResumeSection.education => resume.education.trim().isNotEmpty,
    ResumeSection.links => resume.projects.any(
      (project) =>
          project.githubLink.trim().isNotEmpty ||
          project.liveDemoLink.trim().isNotEmpty,
    ),
    ResumeSection.achievements => resume.achievements.isNotEmpty,
    ResumeSection.improvementAreas => resume.improvementAreas.isNotEmpty,
  };
}

List<String> _resumeLinks(SmartResumeModel resume) {
  return resume.projects
      .expand(
        (project) => [
          if (project.githubLink.trim().isNotEmpty)
            '${project.title}: ${project.githubLink}',
          if (project.liveDemoLink.trim().isNotEmpty)
            '${project.title}: ${project.liveDemoLink}',
        ],
      )
      .toList();
}

List<ResumeSection> _moveSection(
  List<ResumeSection> sections,
  int from,
  int to,
) {
  final updated = List<ResumeSection>.of(sections);
  final item = updated.removeAt(from);
  updated.insert(to, item);
  return updated;
}

String _capitalize(String value) {
  if (value.isEmpty) return value;
  return value[0].toUpperCase() + value.substring(1).toLowerCase();
}
