import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/models/certificate_model.dart';
import 'certificate_design_config.dart';

class CertificatePdfBuilder {
  const CertificatePdfBuilder._();

  static Future<Uint8List> build(
    CertificateModel certificate, {
    CertificateDesignConfig designConfig = CertificateDesignConfig.standard,
  }) async {
    final document = pw.Document(
      title: 'SkillForge Certificate - ${certificate.studentName}',
      author: 'SkillForge AI',
      creator: 'SkillForge AI',
      subject: certificate.title,
      keywords: 'SkillForge, certificate, credential, verification',
    );

    final palette = _paletteFor(designConfig);
    final issueDate = DateFormat('MMMM d, yyyy').format(certificate.issuedAt);
    final statusLabel = certificate.isActive ? 'VERIFIED' : 'REVOKED';
    final statusColor = certificate.isActive
        ? PdfColors.green700
        : PdfColors.red700;

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(34),
        build: (context) {
          return pw.Container(
            color: palette.background,
            padding: _pagePadding(designConfig),
            child: pw.Stack(
              children: [
                if (designConfig.watermarkIntensity !=
                    CertificateWatermarkIntensity.none)
                  _watermark(designConfig, palette),
                _certificateFrame(
                  certificate,
                  designConfig,
                  palette,
                  issueDate,
                  statusLabel,
                  statusColor,
                ),
              ],
            ),
          );
        },
      ),
    );

    return document.save();
  }

  static pw.Widget _certificateFrame(
    CertificateModel certificate,
    CertificateDesignConfig designConfig,
    _CertificatePalette palette,
    String issueDate,
    String statusLabel,
    PdfColor statusColor,
  ) {
    final titleScale = _titleScale(designConfig);
    final isMinimal =
        designConfig.templateStyle == CertificateTemplateStyle.minimal;

    return pw.Container(
      padding: _framePadding(designConfig),
      decoration: _outerDecoration(designConfig, palette),
      child: pw.Container(
        padding: isMinimal
            ? const pw.EdgeInsets.all(24)
            : const pw.EdgeInsets.all(28),
        decoration: _innerDecoration(designConfig, palette),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            _header(designConfig, palette, statusLabel, statusColor),
            pw.Spacer(),
            pw.Text(
              _templateTitle(designConfig),
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: 25 * titleScale,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: isMinimal ? 2 : 4,
                color: palette.text,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              certificate.title.toUpperCase(),
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 2,
                color: palette.primary,
              ),
            ),
            pw.SizedBox(height: isMinimal ? 22 : 28),
            _smallText('This certifies that', palette),
            pw.SizedBox(height: 10),
            pw.Text(
              certificate.studentName,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: 34 * titleScale,
                fontWeight: pw.FontWeight.bold,
                color: palette.text,
              ),
            ),
            pw.SizedBox(height: 12),
            _smallText('successfully completed', palette),
            pw.SizedBox(height: 8),
            pw.Text(
              certificate.courseTitle,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: 20 * titleScale,
                fontWeight: pw.FontWeight.bold,
                color: palette.text,
              ),
            ),
            pw.SizedBox(height: isMinimal ? 18 : 24),
            pw.Wrap(
              alignment: pw.WrapAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                _scoreBadge(
                  'Final Score',
                  '${certificate.finalScore.toStringAsFixed(0)}%',
                  palette,
                ),
                _scoreBadge(
                  'Grand Test',
                  '${certificate.grandTestScore.toStringAsFixed(0)}%',
                  palette,
                ),
                _scoreBadge(
                  'Assignments',
                  '${certificate.assignmentAverage.toStringAsFixed(0)}%',
                  palette,
                ),
              ],
            ),
            pw.Spacer(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                _footerColumn('Instructor', certificate.teacherName, palette),
                _footerColumn('Issue Date', issueDate, palette),
                _footerColumn(
                  'Verification Code',
                  certificate.verificationCode,
                  palette,
                ),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Divider(color: palette.divider),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Certificate ID: ${certificate.certificateId}',
                  style: pw.TextStyle(fontSize: 8, color: palette.muted),
                ),
                pw.Text(
                  'Generated from immutable SkillForge AI certificate data',
                  style: pw.TextStyle(fontSize: 8, color: palette.muted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _header(
    CertificateDesignConfig designConfig,
    _CertificatePalette palette,
    String statusLabel,
    PdfColor statusColor,
  ) {
    final badge = _statusBadge(statusLabel, statusColor);

    return switch (designConfig.logoPosition) {
      CertificateLogoPosition.topCenter => pw.Column(
        children: [
          _brandBlock(palette, alignment: pw.CrossAxisAlignment.center),
          pw.SizedBox(height: 10),
          badge,
        ],
      ),
      CertificateLogoPosition.topRight => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          badge,
          _brandBlock(palette, alignment: pw.CrossAxisAlignment.end),
        ],
      ),
      CertificateLogoPosition.topLeft => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [_brandBlock(palette), badge],
      ),
    };
  }

  static pw.Widget _brandBlock(
    _CertificatePalette palette, {
    pw.CrossAxisAlignment alignment = pw.CrossAxisAlignment.start,
  }) {
    final textAlign = alignment == pw.CrossAxisAlignment.end
        ? pw.TextAlign.right
        : alignment == pw.CrossAxisAlignment.center
        ? pw.TextAlign.center
        : pw.TextAlign.left;

    return pw.Column(
      crossAxisAlignment: alignment,
      children: [
        pw.Text(
          'SkillForge AI',
          textAlign: textAlign,
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: palette.primary,
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          'Verified Learning Credential',
          textAlign: textAlign,
          style: pw.TextStyle(fontSize: 9, color: palette.muted),
        ),
      ],
    );
  }

  static pw.Widget _watermark(
    CertificateDesignConfig designConfig,
    _CertificatePalette palette,
  ) {
    final size = switch (designConfig.watermarkIntensity) {
      CertificateWatermarkIntensity.subtle => 48.0,
      CertificateWatermarkIntensity.medium => 58.0,
      CertificateWatermarkIntensity.strong => 68.0,
      CertificateWatermarkIntensity.none => 0.0,
    };

    return pw.Center(
      child: pw.Text(
        'SKILLFORGE',
        style: pw.TextStyle(
          fontSize: size,
          fontWeight: pw.FontWeight.bold,
          letterSpacing: 8,
          color: palette.watermark,
        ),
      ),
    );
  }

  static pw.Widget _smallText(String value, _CertificatePalette palette) {
    return pw.Text(
      value,
      textAlign: pw.TextAlign.center,
      style: pw.TextStyle(fontSize: 13, color: palette.muted),
    );
  }

  static pw.Widget _statusBadge(String label, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(
        label,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }

  static pw.Widget _scoreBadge(
    String label,
    String value,
    _CertificatePalette palette,
  ) {
    return pw.Container(
      width: 110,
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: pw.BoxDecoration(
        color: palette.badgeBackground,
        border: pw.Border.all(color: palette.primary),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 17,
              fontWeight: pw.FontWeight.bold,
              color: palette.primary,
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            label.toUpperCase(),
            style: pw.TextStyle(fontSize: 7, color: palette.muted),
          ),
        ],
      ),
    );
  }

  static pw.Widget _footerColumn(
    String label,
    String value,
    _CertificatePalette palette,
  ) {
    return pw.SizedBox(
      width: 170,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            value.trim().isEmpty ? 'Not available' : value,
            textAlign: pw.TextAlign.center,
            maxLines: 2,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: palette.text,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Container(height: 1, color: palette.divider),
          pw.SizedBox(height: 4),
          pw.Text(
            label.toUpperCase(),
            style: pw.TextStyle(fontSize: 7, color: palette.muted),
          ),
        ],
      ),
    );
  }

  static pw.EdgeInsets _pagePadding(CertificateDesignConfig designConfig) {
    return switch (designConfig.templateStyle) {
      CertificateTemplateStyle.minimal => const pw.EdgeInsets.all(18),
      CertificateTemplateStyle.modern => const pw.EdgeInsets.all(20),
      CertificateTemplateStyle.luxury => const pw.EdgeInsets.all(22),
      CertificateTemplateStyle.classic => const pw.EdgeInsets.all(24),
    };
  }

  static pw.EdgeInsets _framePadding(CertificateDesignConfig designConfig) {
    return switch (designConfig.borderStyle) {
      CertificateBorderStyle.none => const pw.EdgeInsets.all(0),
      CertificateBorderStyle.minimal => const pw.EdgeInsets.all(16),
      CertificateBorderStyle.elegant => const pw.EdgeInsets.all(22),
      CertificateBorderStyle.doubleLine => const pw.EdgeInsets.all(24),
    };
  }

  static pw.BoxDecoration _outerDecoration(
    CertificateDesignConfig designConfig,
    _CertificatePalette palette,
  ) {
    return pw.BoxDecoration(
      color: palette.paper,
      border: designConfig.borderStyle == CertificateBorderStyle.none
          ? null
          : pw.Border.all(
              color: palette.primary,
              width: designConfig.borderStyle == CertificateBorderStyle.minimal
                  ? 1
                  : 3,
            ),
    );
  }

  static pw.BoxDecoration _innerDecoration(
    CertificateDesignConfig designConfig,
    _CertificatePalette palette,
  ) {
    final showInnerBorder =
        designConfig.borderStyle == CertificateBorderStyle.doubleLine ||
        designConfig.borderStyle == CertificateBorderStyle.elegant;

    return pw.BoxDecoration(
      border: showInnerBorder
          ? pw.Border.all(color: palette.secondary, width: 1)
          : null,
    );
  }

  static String _templateTitle(CertificateDesignConfig designConfig) {
    return switch (designConfig.templateStyle) {
      CertificateTemplateStyle.modern => 'SKILL CREDENTIAL',
      CertificateTemplateStyle.minimal => 'CERTIFICATE',
      CertificateTemplateStyle.luxury => 'CERTIFICATE OF EXCELLENCE',
      CertificateTemplateStyle.classic => 'CERTIFICATE OF ACHIEVEMENT',
    };
  }

  static double _titleScale(CertificateDesignConfig designConfig) {
    return switch (designConfig.typographyStyle) {
      CertificateTypographyStyle.modernSans => 0.96,
      CertificateTypographyStyle.formal => 1.02,
      CertificateTypographyStyle.bold => 1.08,
      CertificateTypographyStyle.classicSerif => 1,
    };
  }

  static _CertificatePalette _paletteFor(CertificateDesignConfig designConfig) {
    final base = switch (designConfig.colorTheme) {
      CertificateColorTheme.skillforgeBlue => _CertificatePalette(
        primary: PdfColors.blue700,
        secondary: PdfColors.blue200,
        badgeBackground: PdfColors.blue50,
      ),
      CertificateColorTheme.emerald => _CertificatePalette(
        primary: PdfColors.green700,
        secondary: PdfColors.green200,
        badgeBackground: PdfColors.green50,
      ),
      CertificateColorTheme.purple => _CertificatePalette(
        primary: PdfColors.purple700,
        secondary: PdfColors.purple200,
        badgeBackground: PdfColors.purple50,
      ),
      CertificateColorTheme.monochrome => _CertificatePalette(
        primary: PdfColors.grey900,
        secondary: PdfColors.grey400,
        badgeBackground: PdfColors.grey100,
      ),
      CertificateColorTheme.gold => _CertificatePalette(
        primary: PdfColors.amber800,
        secondary: PdfColors.amber200,
        badgeBackground: PdfColors.amber50,
      ),
    };

    return switch (designConfig.backgroundStyle) {
      CertificateBackgroundStyle.darkLuxury => base.copyWith(
        background: PdfColors.grey900,
        paper: PdfColors.grey800,
        text: PdfColors.white,
        muted: PdfColors.grey300,
        divider: PdfColors.grey500,
        watermark: PdfColors.grey700,
        badgeBackground: PdfColors.grey700,
      ),
      CertificateBackgroundStyle.parchment => base.copyWith(
        background: PdfColors.amber50,
        paper: PdfColors.amber50,
        watermark: PdfColors.amber100,
      ),
      CertificateBackgroundStyle.softGradient => base.copyWith(
        background: base.badgeBackground,
        paper: PdfColors.white,
      ),
      CertificateBackgroundStyle.clean => base,
    };
  }
}

class _CertificatePalette {
  const _CertificatePalette({
    required this.primary,
    required this.secondary,
    required this.badgeBackground,
    this.background = PdfColors.white,
    this.paper = PdfColors.white,
    this.text = PdfColors.grey900,
    this.muted = PdfColors.grey700,
    this.divider = PdfColors.grey300,
    this.watermark = PdfColors.grey100,
  });

  final PdfColor primary;
  final PdfColor secondary;
  final PdfColor badgeBackground;
  final PdfColor background;
  final PdfColor paper;
  final PdfColor text;
  final PdfColor muted;
  final PdfColor divider;
  final PdfColor watermark;

  _CertificatePalette copyWith({
    PdfColor? primary,
    PdfColor? secondary,
    PdfColor? badgeBackground,
    PdfColor? background,
    PdfColor? paper,
    PdfColor? text,
    PdfColor? muted,
    PdfColor? divider,
    PdfColor? watermark,
  }) {
    return _CertificatePalette(
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
      badgeBackground: badgeBackground ?? this.badgeBackground,
      background: background ?? this.background,
      paper: paper ?? this.paper,
      text: text ?? this.text,
      muted: muted ?? this.muted,
      divider: divider ?? this.divider,
      watermark: watermark ?? this.watermark,
    );
  }
}
