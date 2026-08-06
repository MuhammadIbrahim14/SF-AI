import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/route_names.dart';
import '../../../models/user_role.dart';
import '../../../providers/pdf_export_provider.dart';
import '../../../shared/widgets/role_fixed_header_page.dart';
import '../data/models/certificate_model.dart';
import '../pdf/certificate_design_config.dart';
import '../providers/certificate_provider.dart';
import '../providers/studio_provider.dart';
import 'certificate_studio_screen.dart';

class CertificateDetailScreen extends ConsumerWidget {
  const CertificateDetailScreen({super.key, required this.certificateId});

  final String certificateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final certificateAsync = ref.watch(
      certificateDetailProvider(certificateId),
    );
    final certificateForAction = certificateAsync.value;
    final exportState = ref.watch(pdfExportActionProvider);
    final theme = Theme.of(context);
    final designConfig = ref.watch(certificateDesignConfigProvider);

    return RoleFixedHeaderPage(
      role: UserRole.student,
      title: 'Verified Credential',
      subtitle:
          'Inspect certificate details, score evidence, and credential ID.',
      showBackButton: true,
      onBack: () => context.canPop()
          ? context.pop()
          : context.goNamed(RouteNames.studentCertificates),
      actions: certificateForAction == null
          ? null
          : [
              LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = MediaQuery.of(context).size.width < 700;
                  if (isMobile) {
                    return PopupMenuButton(
                      icon: const Icon(Icons.more_vert_rounded),
                      itemBuilder: (ctx) => [
                        PopupMenuItem(
                          onTap: () => _openCertificateStudio(
                            context,
                            certificateForAction,
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.tune_rounded, size: 18),
                              SizedBox(width: 12),
                              Text('Customize'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          onTap: () => _exportCertificatePdf(
                            context,
                            ref,
                            certificateForAction,
                            designConfig,
                          ),
                          child: Row(
                            children: [
                              if (exportState.isLoading)
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              else
                                const Icon(Icons.download_rounded, size: 18),
                              const SizedBox(width: 12),
                              const Text('Download PDF'),
                            ],
                          ),
                        ),
                      ],
                    );
                  }
                  return SizedBox.shrink();
                },
              ),
              if (MediaQuery.of(context).size.width >= 700) ...[
                OutlinedButton.icon(
                  onPressed: exportState.isLoading
                      ? null
                      : () =>
                            _openCertificateStudio(context, certificateForAction),
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: const Text('Customize'),
                ),
                FilledButton.icon(
                  onPressed: exportState.isLoading
                      ? null
                      : () => _exportCertificatePdf(
                          context,
                          ref,
                          certificateForAction,
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
            ],
      scrollable: false,
      child: ColoredBox(
        color: Colors.transparent,
        child: certificateAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Error: $error')),
          data: (certificate) {
            if (certificate == null) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.block_rounded,
                      size: 64,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Certificate Unavailable',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This credential may have been removed or revoked.',
                    ),
                  ],
                ),
              );
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: constraints.maxWidth > 1000
                        ? (constraints.maxWidth - 1000) / 2
                        : 24,
                    vertical: 32,
                  ),
                  child: Column(
                    children: [
                      FittedBox(
                        fit: BoxFit.contain,
                        child: SizedBox(
                          width: 842,
                          child: _PremiumDocumentViewer(
                            certificate: certificate,
                            config: designConfig,
                          ),
                        ),
                      ),

                      if (!certificate.isActive &&
                          certificate.revokeReason.trim().isNotEmpty) ...[
                        const SizedBox(height: 40),
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.red.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.red,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'CREDENTIAL REVOKED',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: Colors.red,
                                        letterSpacing: 2,
                                        fontSize: 18,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      certificate.revokeReason,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.red,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 60),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

void _openCertificateStudio(
  BuildContext context,
  CertificateModel certificate,
) {
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
            child: CertificateStudioScreen(certificate: certificate),
          ),
        );
      },
    );
  });
}

Future<void> _exportCertificatePdf(
  BuildContext context,
  WidgetRef ref,
  CertificateModel certificate,
  CertificateDesignConfig designConfig,
) async {
  final success = await ref
      .read(pdfExportActionProvider.notifier)
      .exportCertificate(certificate, designConfig: designConfig);
  if (!context.mounted) return;

  final message = success
      ? 'Certificate PDF is ready.'
      : ref.read(pdfExportActionProvider.notifier).errorMessage ??
            'Unable to export certificate PDF.';
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class _PremiumDocumentViewer extends StatelessWidget {
  const _PremiumDocumentViewer({
    required this.certificate,
    required this.config,
  });

  final CertificateModel certificate;
  final CertificateDesignConfig config;

  @override
  Widget build(BuildContext context) {
    final style = _PreviewStyle.fromConfig(config);
    final isActive = certificate.isActive;

    // A classic, rich paper look for the document
    final textColor = style.text;
    final accentColor = isActive ? style.accent : Colors.grey.shade500;

    return AspectRatio(
      aspectRatio: 1.414, // A4 Landscape ratio
      child: Container(
        decoration: BoxDecoration(
          color: style.background,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 40,
              spreadRadius: 5,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Internal Padding & Border
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.8),
                      width: 8,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.4),
                          width: 2,
                        ),
                      ),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isActive
                                ? Icons.account_balance_rounded
                                : Icons.block_rounded,
                            size: 40,
                            color: accentColor,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _templateTitle(config.templateStyle),
                            style: TextStyle(
                              fontFamily: _fontFamilyFor(
                                config.typographyStyle,
                              ),
                              fontWeight: FontWeight.w900,
                              fontSize:
                                  32 * _titleScaleFor(config.typographyStyle),
                              letterSpacing:
                                  config.templateStyle ==
                                      CertificateTemplateStyle.minimal
                                  ? 3
                                  : 6,
                              color: textColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            certificate.title.toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              letterSpacing: 4,
                              color: accentColor,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          const Spacer(),

                          Text(
                            'THIS IS TO CERTIFY THAT',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              letterSpacing: 2,
                              color: textColor.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            certificate.studentName,
                            style: TextStyle(
                              fontFamily: 'Georgia',
                              fontWeight: FontWeight.bold,
                              fontSize: 48,
                              color: textColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'HAS SUCCESSFULLY COMPLETED',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              letterSpacing: 2,
                              color: textColor.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            certificate.courseTitle,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 24,
                              color: textColor,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 24),
                          Wrap(
                            spacing: 24,
                            runSpacing: 16,
                            alignment: WrapAlignment.center,
                            children: [
                              _DocBadge(
                                label: 'OVERALL SCORE',
                                value:
                                    '${certificate.finalScore.toStringAsFixed(0)}%',
                                accentColor: accentColor,
                                textColor: textColor,
                              ),
                              _DocBadge(
                                label: 'GRAND TEST',
                                value:
                                    '${certificate.grandTestScore.toStringAsFixed(0)}%',
                                accentColor: accentColor,
                                textColor: textColor,
                              ),
                              _DocBadge(
                                label: 'ASSIGNMENTS',
                                value:
                                    '${certificate.assignmentAverage.toStringAsFixed(0)}%',
                                accentColor: accentColor,
                                textColor: textColor,
                              ),
                            ],
                          ),

                          const Spacer(),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // Left side - Date
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    DateFormat(
                                      'MMMM d, yyyy',
                                    ).format(certificate.issuedAt),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: textColor,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    height: 1,
                                    width: 140,
                                    color: textColor.withValues(alpha: 0.5),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'DATE OF ISSUE',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: textColor.withValues(alpha: 0.5),
                                      fontSize: 10,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),

                              // Center - Seal
                              if (isActive)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: accentColor,
                                      width: 2,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.verified_rounded,
                                    size: 40,
                                    color: accentColor,
                                  ),
                                )
                              else
                                const SizedBox(),

                              // Right side - ID
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        certificate.verificationCode,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontFamily: 'monospace',
                                          color: textColor,
                                          fontSize: 16,
                                          letterSpacing: 2,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      InkWell(
                                        onTap: () async {
                                          await Clipboard.setData(
                                            ClipboardData(
                                              text:
                                                  certificate.verificationCode,
                                            ),
                                          );
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Verification ID copied.',
                                              ),
                                            ),
                                          );
                                        },
                                        child: Icon(
                                          Icons.copy_rounded,
                                          size: 16,
                                          color: accentColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    height: 1,
                                    width: 180,
                                    color: textColor.withValues(alpha: 0.5),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'SECURE CREDENTIAL ID',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: textColor.withValues(alpha: 0.5),
                                      fontSize: 10,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _templateTitle(CertificateTemplateStyle style) {
  return switch (style) {
    CertificateTemplateStyle.modern => 'CERTIFICATE OF COMPLETION',
    CertificateTemplateStyle.classic => 'CERTIFICATE OF ACHIEVEMENT',
    CertificateTemplateStyle.minimal => 'VERIFIED CREDENTIAL',
    CertificateTemplateStyle.luxury => 'CERTIFICATE OF EXCELLENCE',
  };
}

String _fontFamilyFor(CertificateTypographyStyle style) {
  return switch (style) {
    CertificateTypographyStyle.classicSerif => 'Georgia',
    CertificateTypographyStyle.modernSans => 'Segoe UI',
    CertificateTypographyStyle.formal => 'Times New Roman',
    CertificateTypographyStyle.bold => 'Impact',
  };
}

double _titleScaleFor(CertificateTypographyStyle style) {
  return switch (style) {
    CertificateTypographyStyle.classicSerif => 1.0,
    CertificateTypographyStyle.modernSans => 0.95,
    CertificateTypographyStyle.formal => 1.0,
    CertificateTypographyStyle.bold => 1.1,
  };
}

class _PreviewStyle {
  const _PreviewStyle({
    required this.background,
    required this.accent,
    required this.text,
    required this.watermark,
  });

  final Color background;
  final Color accent;
  final Color text;
  final Color watermark;

  factory _PreviewStyle.fromConfig(CertificateDesignConfig config) {
    // We map the config values to actual colors.
    // In a real app you might want to share this with the PDF builder or match closely.
    final accent = switch (config.colorTheme) {
      CertificateColorTheme.gold => const Color(0xFFD4AF37),
      CertificateColorTheme.skillforgeBlue => const Color(0xFF2563EB),
      CertificateColorTheme.emerald => const Color(0xFF047857),
      CertificateColorTheme.purple => const Color(0xFF7C3AED),
      CertificateColorTheme.monochrome => const Color(0xFF171717),
    };

    final isDark =
        config.backgroundStyle == CertificateBackgroundStyle.darkLuxury;

    return _PreviewStyle(
      background: isDark ? const Color(0xFF161616) : const Color(0xFFFAFAFA),
      accent: accent,
      text: isDark ? Colors.white : const Color(0xFF222222),
      watermark: isDark
          ? const Color(0xFF222222)
          : Colors.black.withValues(alpha: 0.03),
    );
  }
}

class _DocBadge extends StatelessWidget {
  const _DocBadge({
    required this.label,
    required this.value,
    required this.accentColor,
    required this.textColor,
  });
  final String label;
  final String value;
  final Color accentColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: accentColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
            color: textColor.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}
