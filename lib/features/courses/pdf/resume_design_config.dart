enum ResumeTemplateStyle { professional, modern, minimal, technical }

enum ResumeAccentColor { skillforgeBlue, emerald, purple, slate }

enum ResumeTypographyStyle { classic, modern, compact, bold }

enum ResumeDensity { comfortable, balanced, compact }

enum ResumeSection {
  summary,
  skills,
  projects,
  certificates,
  skillScores,
  strengths,
  education,
  links,
  achievements,
  improvementAreas,
}

class ResumeDesignConfig {
  const ResumeDesignConfig({
    required this.templateStyle,
    required this.accentColor,
    required this.typographyStyle,
    required this.density,
    required this.visibleSections,
    required this.sectionOrder,
  });

  static const standard = ResumeDesignConfig(
    templateStyle: ResumeTemplateStyle.professional,
    accentColor: ResumeAccentColor.skillforgeBlue,
    typographyStyle: ResumeTypographyStyle.modern,
    density: ResumeDensity.balanced,
    visibleSections: {
      ResumeSection.summary,
      ResumeSection.skills,
      ResumeSection.projects,
      ResumeSection.certificates,
      ResumeSection.skillScores,
      ResumeSection.strengths,
      ResumeSection.education,
      ResumeSection.links,
      ResumeSection.achievements,
    },
    sectionOrder: [
      ResumeSection.summary,
      ResumeSection.skills,
      ResumeSection.projects,
      ResumeSection.certificates,
      ResumeSection.skillScores,
      ResumeSection.strengths,
      ResumeSection.education,
      ResumeSection.links,
      ResumeSection.achievements,
      ResumeSection.improvementAreas,
    ],
  );

  final ResumeTemplateStyle templateStyle;
  final ResumeAccentColor accentColor;
  final ResumeTypographyStyle typographyStyle;
  final ResumeDensity density;
  final Set<ResumeSection> visibleSections;
  final List<ResumeSection> sectionOrder;

  ResumeDesignConfig copyWith({
    ResumeTemplateStyle? templateStyle,
    ResumeAccentColor? accentColor,
    ResumeTypographyStyle? typographyStyle,
    ResumeDensity? density,
    Set<ResumeSection>? visibleSections,
    List<ResumeSection>? sectionOrder,
  }) {
    return ResumeDesignConfig(
      templateStyle: templateStyle ?? this.templateStyle,
      accentColor: accentColor ?? this.accentColor,
      typographyStyle: typographyStyle ?? this.typographyStyle,
      density: density ?? this.density,
      visibleSections: visibleSections ?? this.visibleSections,
      sectionOrder: sectionOrder ?? this.sectionOrder,
    );
  }
}

extension ResumeDesignLabel on Enum {
  String get resumeLabel {
    final spaced = name.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (match) => ' ${match.group(1)}',
    );
    return spaced[0].toUpperCase() + spaced.substring(1);
  }
}
