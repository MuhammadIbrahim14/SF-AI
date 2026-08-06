enum CertificateTemplateStyle { classic, modern, minimal, luxury }

enum CertificateColorTheme { skillforgeBlue, emerald, purple, gold, monochrome }

enum CertificateBorderStyle { elegant, doubleLine, minimal, none }

enum CertificateWatermarkIntensity { none, subtle, medium, strong }

enum CertificateLogoPosition { topLeft, topCenter, topRight }

enum CertificateTypographyStyle { classicSerif, modernSans, formal, bold }

enum CertificateBackgroundStyle { clean, softGradient, parchment, darkLuxury }

class CertificateDesignConfig {
  const CertificateDesignConfig({
    required this.templateStyle,
    required this.colorTheme,
    required this.borderStyle,
    required this.watermarkIntensity,
    required this.logoPosition,
    required this.typographyStyle,
    required this.backgroundStyle,
  });

  static const standard = CertificateDesignConfig(
    templateStyle: CertificateTemplateStyle.classic,
    colorTheme: CertificateColorTheme.gold,
    borderStyle: CertificateBorderStyle.doubleLine,
    watermarkIntensity: CertificateWatermarkIntensity.subtle,
    logoPosition: CertificateLogoPosition.topLeft,
    typographyStyle: CertificateTypographyStyle.classicSerif,
    backgroundStyle: CertificateBackgroundStyle.clean,
  );

  final CertificateTemplateStyle templateStyle;
  final CertificateColorTheme colorTheme;
  final CertificateBorderStyle borderStyle;
  final CertificateWatermarkIntensity watermarkIntensity;
  final CertificateLogoPosition logoPosition;
  final CertificateTypographyStyle typographyStyle;
  final CertificateBackgroundStyle backgroundStyle;

  CertificateDesignConfig copyWith({
    CertificateTemplateStyle? templateStyle,
    CertificateColorTheme? colorTheme,
    CertificateBorderStyle? borderStyle,
    CertificateWatermarkIntensity? watermarkIntensity,
    CertificateLogoPosition? logoPosition,
    CertificateTypographyStyle? typographyStyle,
    CertificateBackgroundStyle? backgroundStyle,
  }) {
    return CertificateDesignConfig(
      templateStyle: templateStyle ?? this.templateStyle,
      colorTheme: colorTheme ?? this.colorTheme,
      borderStyle: borderStyle ?? this.borderStyle,
      watermarkIntensity: watermarkIntensity ?? this.watermarkIntensity,
      logoPosition: logoPosition ?? this.logoPosition,
      typographyStyle: typographyStyle ?? this.typographyStyle,
      backgroundStyle: backgroundStyle ?? this.backgroundStyle,
    );
  }
}

extension CertificateDesignLabel on Enum {
  String get designLabel {
    final spaced = name.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (match) => ' ${match.group(1)}',
    );
    return spaced[0].toUpperCase() + spaced.substring(1);
  }
}
