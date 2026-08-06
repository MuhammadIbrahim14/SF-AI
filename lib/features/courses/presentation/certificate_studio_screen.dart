import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/pdf_export_provider.dart';
import '../providers/studio_provider.dart';
import '../data/models/certificate_model.dart';
import '../pdf/certificate_design_config.dart';

class CertificateStudioScreen extends ConsumerStatefulWidget {
  const CertificateStudioScreen({super.key, required this.certificate});

  final CertificateModel certificate;

  @override
  ConsumerState<CertificateStudioScreen> createState() =>
      _CertificateStudioScreenState();
}

String _capitalize(String value) {
  if (value.isEmpty) return value;
  return value[0].toUpperCase() + value.substring(1).toLowerCase();
}

class _CertificateStudioScreenState
    extends ConsumerState<CertificateStudioScreen> {
  @override
  Widget build(BuildContext context) {
    final exportState = ref.watch(pdfExportActionProvider);
    final config = ref.watch(certificateDesignConfigProvider);
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
                    .read(certificateDesignConfigProvider.notifier)
                    .updateConfig(CertificateDesignConfig.standard),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 980;
                    final content = isWide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: _PreviewPane(
                                  certificate: widget.certificate,
                                  config: config,
                                ),
                              ),
                              SizedBox(
                                width: 390,
                                child: _DesignPanel(
                                  config: config,
                                  scrollable: true,
                                  onChanged: (config) => ref
                                      .read(
                                        certificateDesignConfigProvider
                                            .notifier,
                                      )
                                      .updateConfig(config),
                                ),
                              ),
                            ],
                          )
                        : SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            child: Column(
                              children: [
                                _PreviewPane(
                                  certificate: widget.certificate,
                                  config: config,
                                  compact: true,
                                ),
                                const SizedBox(height: 18),
                                _DesignPanel(
                                  config: config,
                                  scrollable: false,
                                  onChanged: (config) => ref
                                      .read(
                                        certificateDesignConfigProvider
                                            .notifier,
                                      )
                                      .updateConfig(config),
                                ),
                              ],
                            ),
                          );

                    return content;
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 640;
                    final note = Text(
                      'Design settings are local only. Verified certificate data is locked.',
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
    final config = ref.read(certificateDesignConfigProvider);
    final success = await ref
        .read(pdfExportActionProvider.notifier)
        .exportCertificate(widget.certificate, designConfig: config);
    if (!context.mounted) return;

    final message = success
        ? 'Styled certificate PDF is ready.'
        : ref.read(pdfExportActionProvider.notifier).errorMessage ??
              'Unable to export styled certificate PDF.';
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
            child: const Icon(Icons.workspace_premium_rounded),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Certificate Studio',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  'Customize appearance only. Verified fields stay locked.',
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
    required this.certificate,
    required this.config,
    this.compact = false,
  });

  final CertificateModel certificate;
  final CertificateDesignConfig config;
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
            width: 842, // A4 landscape width at standard resolution
            height: 595, // A4 landscape height
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: _CertificatePreviewCard(
                    certificate: certificate,
                    config: config,
                  ),
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
                        Icons.lock_rounded,
                        color: colorScheme.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Student, course, score, issue date, ID, and verification code are immutable.',
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

class _CertificatePreviewCard extends StatelessWidget {
  const _CertificatePreviewCard({
    required this.certificate,
    required this.config,
  });

  final CertificateModel certificate;
  final CertificateDesignConfig config;

  @override
  Widget build(BuildContext context) {
    final style = _PreviewStyle.fromConfig(config);
    final issueDate = DateFormat('MMMM d, yyyy').format(certificate.issuedAt);

    return Container(
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 32,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Stack(
        children: [
          if (config.watermarkIntensity != CertificateWatermarkIntensity.none)
            Center(
              child: Text(
                'SKILLFORGE',
                style: TextStyle(
                  color: style.watermark,
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 7,
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: style.paper,
              borderRadius: BorderRadius.circular(16),
              border: config.borderStyle == CertificateBorderStyle.none
                  ? null
                  : Border.all(color: style.accent, width: 3),
            ),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border:
                    config.borderStyle == CertificateBorderStyle.doubleLine ||
                        config.borderStyle == CertificateBorderStyle.elegant
                    ? Border.all(color: style.accent.withValues(alpha: 0.35))
                    : null,
              ),
              child: Column(
                children: [
                  _PreviewHeader(config: config, style: style),
                  const Spacer(),
                  Text(
                    _templateTitle(config.templateStyle),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: style.text,
                      fontSize: 22 * _typographyScale(config),
                      fontWeight: FontWeight.w900,
                      letterSpacing:
                          config.templateStyle ==
                              CertificateTemplateStyle.minimal
                          ? 2
                          : 4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    certificate.title.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: style.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _SmallPreviewText('This certifies that', style: style),
                  const SizedBox(height: 8),
                  Text(
                    certificate.studentName,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: style.text,
                      fontSize: 30 * _typographyScale(config),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SmallPreviewText('successfully completed', style: style),
                  const SizedBox(height: 8),
                  Text(
                    certificate.courseTitle,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: style.text,
                      fontSize: 17 * _typographyScale(config),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _PreviewScoreBadge(
                        label: 'Final',
                        value: '${certificate.finalScore.toStringAsFixed(0)}%',
                        style: style,
                      ),
                      _PreviewScoreBadge(
                        label: 'Grand Test',
                        value:
                            '${certificate.grandTestScore.toStringAsFixed(0)}%',
                        style: style,
                      ),
                      _PreviewScoreBadge(
                        label: 'Assignments',
                        value:
                            '${certificate.assignmentAverage.toStringAsFixed(0)}%',
                        style: style,
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _PreviewFooter(label: 'Issue Date', value: issueDate),
                      Icon(
                        Icons.verified_rounded,
                        color: certificate.isActive
                            ? style.accent
                            : Colors.redAccent,
                        size: 34,
                      ),
                      _PreviewFooter(
                        label: 'Verification',
                        value: certificate.verificationCode,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewHeader extends StatelessWidget {
  const _PreviewHeader({required this.config, required this.style});

  final CertificateDesignConfig config;
  final _PreviewStyle style;

  @override
  Widget build(BuildContext context) {
    final brand = Column(
      crossAxisAlignment: _brandAlignment(config.logoPosition),
      children: [
        Text(
          'SkillForge AI',
          style: TextStyle(
            color: style.accent,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
        Text(
          'Verified Learning Credential',
          style: TextStyle(
            color: style.muted,
            fontWeight: FontWeight.w700,
            fontSize: 9,
          ),
        ),
      ],
    );

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green.shade700,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'VERIFIED',
        style: TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
    );

    return switch (config.logoPosition) {
      CertificateLogoPosition.topCenter => Column(
        children: [brand, const SizedBox(height: 8), badge],
      ),
      CertificateLogoPosition.topRight => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [badge, brand],
      ),
      CertificateLogoPosition.topLeft => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [brand, badge],
      ),
    };
  }
}

class _SmallPreviewText extends StatelessWidget {
  const _SmallPreviewText(this.text, {required this.style});

  final String text;
  final _PreviewStyle style;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: style.muted,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _PreviewScoreBadge extends StatelessWidget {
  const _PreviewScoreBadge({
    required this.label,
    required this.value,
    required this.style,
  });

  final String label;
  final String value;
  final _PreviewStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: style.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: style.accent.withValues(alpha: 0.45)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: style.accent,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: style.muted,
              fontSize: 8,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewFooter extends StatelessWidget {
  const _PreviewFooter({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Column(
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10),
          ),
          const SizedBox(height: 3),
          Text(
            label.toUpperCase(),
            style: const TextStyle(fontSize: 7, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _DesignPanel extends StatelessWidget {
  const _DesignPanel({
    required this.config,
    required this.onChanged,
    required this.scrollable,
  });

  final CertificateDesignConfig config;
  final ValueChanged<CertificateDesignConfig> onChanged;
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
            'Choose the aesthetic elements for your credential.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 24),
          _OptionSection<CertificateTemplateStyle>(
            title: 'Layout Template',
            values: CertificateTemplateStyle.values,
            selected: config.templateStyle,
            onSelected: (value) =>
                onChanged(config.copyWith(templateStyle: value)),
            labelBuilder: (v) => v.name.toUpperCase(),
          ),
          _OptionSection<CertificateColorTheme>(
            title: 'Accent Color',
            values: CertificateColorTheme.values,
            selected: config.colorTheme,
            onSelected: (value) =>
                onChanged(config.copyWith(colorTheme: value)),
            swatchBuilder: _accentForColorTheme,
          ),
          _OptionSection<CertificateBorderStyle>(
            title: 'Border Style',
            values: CertificateBorderStyle.values,
            selected: config.borderStyle,
            onSelected: (value) =>
                onChanged(config.copyWith(borderStyle: value)),
          ),
          _OptionSection<CertificateBackgroundStyle>(
            title: 'Paper Style',
            values: CertificateBackgroundStyle.values,
            selected: config.backgroundStyle,
            onSelected: (value) =>
                onChanged(config.copyWith(backgroundStyle: value)),
          ),
          _OptionSection<CertificateTypographyStyle>(
            title: 'Typography',
            values: CertificateTypographyStyle.values,
            selected: config.typographyStyle,
            onSelected: (value) =>
                onChanged(config.copyWith(typographyStyle: value)),
          ),
          _OptionSection<CertificateWatermarkIntensity>(
            title: 'Watermark',
            values: CertificateWatermarkIntensity.values,
            selected: config.watermarkIntensity,
            onSelected: (value) =>
                onChanged(config.copyWith(watermarkIntensity: value)),
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

class _PreviewStyle {
  const _PreviewStyle({
    required this.accent,
    required this.background,
    required this.paper,
    required this.text,
    required this.muted,
    required this.watermark,
  });

  final Color accent;
  final Color background;
  final Color paper;
  final Color text;
  final Color muted;
  final Color watermark;

  factory _PreviewStyle.fromConfig(CertificateDesignConfig config) {
    final accent = _accentForColorTheme(config.colorTheme);
    final base = _PreviewStyle(
      accent: accent,
      background: const Color(0xFFF5F7FB),
      paper: Colors.white,
      text: const Color(0xFF1F2937),
      muted: const Color(0xFF6B7280),
      watermark: accent.withValues(alpha: _watermarkAlpha(config)),
    );

    return switch (config.backgroundStyle) {
      CertificateBackgroundStyle.darkLuxury => _PreviewStyle(
        accent: accent,
        background: const Color(0xFF080B12),
        paper: const Color(0xFF111827),
        text: Colors.white,
        muted: const Color(0xFFB9C0D4),
        watermark: Colors.white.withValues(alpha: _watermarkAlpha(config)),
      ),
      CertificateBackgroundStyle.parchment => _PreviewStyle(
        accent: accent,
        background: const Color(0xFFF8EBCB),
        paper: const Color(0xFFFFF7E5),
        text: const Color(0xFF241A0C),
        muted: const Color(0xFF7A5A24),
        watermark: accent.withValues(alpha: _watermarkAlpha(config)),
      ),
      CertificateBackgroundStyle.softGradient => base,
      CertificateBackgroundStyle.clean => base,
    };
  }
}

Color _accentForColorTheme(CertificateColorTheme value) {
  return switch (value) {
    CertificateColorTheme.skillforgeBlue => AppColors.studentPrimary,
    CertificateColorTheme.emerald => AppColors.companyPrimary,
    CertificateColorTheme.purple => AppColors.teacherPrimary,
    CertificateColorTheme.gold => const Color(0xFFD4AF37),
    CertificateColorTheme.monochrome => const Color(0xFF111827),
  };
}

String _templateTitle(CertificateTemplateStyle value) {
  return switch (value) {
    CertificateTemplateStyle.modern => 'SKILL CREDENTIAL',
    CertificateTemplateStyle.minimal => 'CERTIFICATE',
    CertificateTemplateStyle.luxury => 'CERTIFICATE OF EXCELLENCE',
    CertificateTemplateStyle.classic => 'CERTIFICATE OF ACHIEVEMENT',
  };
}

double _typographyScale(CertificateDesignConfig config) {
  return switch (config.typographyStyle) {
    CertificateTypographyStyle.modernSans => 0.96,
    CertificateTypographyStyle.formal => 1.02,
    CertificateTypographyStyle.bold => 1.08,
    CertificateTypographyStyle.classicSerif => 1,
  };
}

double _watermarkAlpha(CertificateDesignConfig config) {
  return switch (config.watermarkIntensity) {
    CertificateWatermarkIntensity.none => 0,
    CertificateWatermarkIntensity.subtle => 0.08,
    CertificateWatermarkIntensity.medium => 0.13,
    CertificateWatermarkIntensity.strong => 0.19,
  };
}

CrossAxisAlignment _brandAlignment(CertificateLogoPosition value) {
  return switch (value) {
    CertificateLogoPosition.topCenter => CrossAxisAlignment.center,
    CertificateLogoPosition.topRight => CrossAxisAlignment.end,
    CertificateLogoPosition.topLeft => CrossAxisAlignment.start,
  };
}
