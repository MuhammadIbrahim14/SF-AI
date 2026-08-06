import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/models/smart_resume_model.dart';
import 'resume_design_config.dart';

class ResumePdfBuilder {
  const ResumePdfBuilder._();

  static Future<Uint8List> build(
    SmartResumeModel resume, {
    ResumeDesignConfig designConfig = ResumeDesignConfig.standard,
  }) async {
    final palette = _paletteFor(designConfig);
    final document = pw.Document(
      title: 'SkillForge Smart Resume - ${resume.headline}',
      author: 'SkillForge AI',
      creator: 'SkillForge AI',
      subject: 'Verified Smart Resume',
      keywords: 'SkillForge, resume, verified skills, portfolio',
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: _pageMargin(designConfig),
        header: (_) => _header(resume, designConfig, palette),
        footer: (context) => _footer(context, palette),
        build: (context) {
          final sections = <pw.Widget>[
            _scoreSummary(resume, designConfig, palette),
          ];

          for (final section in designConfig.sectionOrder) {
            if (!designConfig.visibleSections.contains(section)) continue;
            final widget = _sectionFor(resume, section, designConfig, palette);
            if (widget != null) sections.add(widget);
          }

          return sections;
        },
      ),
    );

    return document.save();
  }

  static pw.Widget? _sectionFor(
    SmartResumeModel resume,
    ResumeSection section,
    ResumeDesignConfig designConfig,
    _ResumePalette palette,
  ) {
    return switch (section) {
      ResumeSection.summary =>
        resume.summary.trim().isEmpty
            ? null
            : _section(
                'Professional Summary',
                [_paragraph(resume.summary, designConfig, palette)],
                designConfig,
                palette,
              ),
      ResumeSection.skills =>
        resume.verifiedSkills.isEmpty
            ? null
            : _section(
                'Skills',
                [
                  pw.Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: resume.verifiedSkills
                        .map((skill) => _chip(skill.skillName, palette))
                        .toList(),
                  ),
                ],
                designConfig,
                palette,
              ),
      ResumeSection.skillScores =>
        resume.verifiedSkills.isEmpty
            ? null
            : _section(
                'Skill Scores',
                resume.verifiedSkills
                    .map((skill) => _skillScoreEntry(skill, palette))
                    .toList(),
                designConfig,
                palette,
              ),
      ResumeSection.projects =>
        resume.projects.isEmpty
            ? null
            : _section(
                'Verified Projects',
                resume.projects
                    .map(
                      (project) =>
                          _projectEntry(project, designConfig, palette),
                    )
                    .toList(),
                designConfig,
                palette,
              ),
      ResumeSection.certificates =>
        resume.certificates.isEmpty
            ? null
            : _section(
                'Certificates',
                resume.certificates
                    .map(
                      (certificate) => _certificateEntry(certificate, palette),
                    )
                    .toList(),
                designConfig,
                palette,
              ),
      ResumeSection.strengths =>
        resume.strengths.isEmpty
            ? null
            : _section(
                'Strengths',
                [_bulletList(resume.strengths, designConfig, palette)],
                designConfig,
                palette,
              ),
      ResumeSection.education =>
        resume.education.trim().isEmpty
            ? null
            : _section(
                'Education',
                [_paragraph(resume.education, designConfig, palette)],
                designConfig,
                palette,
              ),
      ResumeSection.links =>
        !_hasLinks(resume)
            ? null
            : _section(
                'Links',
                [_bulletList(_resumeLinks(resume), designConfig, palette)],
                designConfig,
                palette,
              ),
      ResumeSection.achievements =>
        resume.achievements.isEmpty
            ? null
            : _section(
                'Achievements',
                resume.achievements
                    .map(
                      (achievement) =>
                          _achievementEntry(achievement, designConfig, palette),
                    )
                    .toList(),
                designConfig,
                palette,
              ),
      ResumeSection.improvementAreas =>
        resume.improvementAreas.isEmpty
            ? null
            : _section(
                'Improvement Areas',
                [_bulletList(resume.improvementAreas, designConfig, palette)],
                designConfig,
                palette,
              ),
    };
  }

  static pw.Widget _header(
    SmartResumeModel resume,
    ResumeDesignConfig designConfig,
    _ResumePalette palette,
  ) {
    final isTechnical =
        designConfig.templateStyle == ResumeTemplateStyle.technical;
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 14),
      margin: const pw.EdgeInsets.only(bottom: 18),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: palette.border, width: 1),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  resume.headline.trim().isEmpty
                      ? 'Verified Smart Resume'
                      : resume.headline,
                  style: pw.TextStyle(
                    fontSize: isTechnical ? 18 : 20,
                    fontWeight: pw.FontWeight.bold,
                    color: palette.text,
                  ),
                ),
                pw.SizedBox(height: 5),
                if (resume.careerGoal.trim().isNotEmpty)
                  pw.Text(
                    resume.careerGoal,
                    style: pw.TextStyle(fontSize: 9, color: palette.muted),
                  )
                else
                  pw.Text(
                    'SkillForge AI verified resume snapshot',
                    style: pw.TextStyle(fontSize: 9, color: palette.muted),
                  ),
              ],
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: pw.BoxDecoration(
              color: palette.primary,
              borderRadius: pw.BorderRadius.circular(
                designConfig.templateStyle == ResumeTemplateStyle.minimal
                    ? 0
                    : 4,
              ),
            ),
            child: pw.Text(
              'SCORE ${resume.resumeScore.toStringAsFixed(0)}',
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _footer(pw.Context context, _ResumePalette palette) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 10),
      decoration: pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: palette.border, width: 1)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Generated by SkillForge AI',
            style: pw.TextStyle(fontSize: 8, color: palette.muted),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 8, color: palette.muted),
          ),
        ],
      ),
    );
  }

  static pw.Widget _scoreSummary(
    SmartResumeModel resume,
    ResumeDesignConfig designConfig,
    _ResumePalette palette,
  ) {
    return pw.Container(
      padding: _densityPadding(designConfig),
      margin: const pw.EdgeInsets.only(bottom: 18),
      decoration: pw.BoxDecoration(
        color: palette.tintedSurface,
        border: pw.Border.all(color: palette.border),
        borderRadius: pw.BorderRadius.circular(
          designConfig.templateStyle == ResumeTemplateStyle.minimal ? 0 : 8,
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _summaryMetric(
            'Resume Score',
            resume.resumeScore.toStringAsFixed(0),
            palette,
          ),
          _summaryMetric(
            'Skills',
            resume.verifiedSkills.length.toString(),
            palette,
          ),
          _summaryMetric(
            'Projects',
            resume.projects.length.toString(),
            palette,
          ),
          _summaryMetric(
            'Certificates',
            resume.certificates.length.toString(),
            palette,
          ),
          _summaryMetric(
            'Updated',
            DateFormat('MMM d, yyyy').format(resume.updatedAt),
            palette,
          ),
        ],
      ),
    );
  }

  static pw.Widget _summaryMetric(
    String label,
    String value,
    _ResumePalette palette,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
            color: palette.text,
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          label.toUpperCase(),
          style: pw.TextStyle(fontSize: 6.5, color: palette.muted),
        ),
      ],
    );
  }

  static pw.Widget _section(
    String title,
    List<pw.Widget> children,
    ResumeDesignConfig designConfig,
    _ResumePalette palette,
  ) {
    return pw.Container(
      margin: pw.EdgeInsets.only(bottom: _sectionGap(designConfig)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title.toUpperCase(),
            style: pw.TextStyle(
              fontSize: _headingSize(designConfig),
              fontWeight: pw.FontWeight.bold,
              color: palette.primary,
              letterSpacing: 0.7,
            ),
          ),
          pw.SizedBox(height: 7),
          pw.Container(height: 1, color: palette.border),
          pw.SizedBox(height: 9),
          ...children,
        ],
      ),
    );
  }

  static pw.Widget _paragraph(
    String text,
    ResumeDesignConfig designConfig,
    _ResumePalette palette,
  ) {
    return pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: _bodySize(designConfig),
        color: palette.body,
        lineSpacing: _lineSpacing(designConfig),
      ),
    );
  }

  static pw.Widget _chip(String label, _ResumePalette palette) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: pw.BoxDecoration(
        color: palette.tintedSurface,
        border: pw.Border.all(color: palette.border),
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Text(
        label,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
          color: palette.text,
        ),
      ),
    );
  }

  static pw.Widget _skillScoreEntry(ResumeSkill skill, _ResumePalette palette) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              skill.skillName,
              style: pw.TextStyle(
                fontSize: 9.5,
                fontWeight: pw.FontWeight.bold,
                color: palette.text,
              ),
            ),
          ),
          pw.Text(
            '${skill.score.toStringAsFixed(0)}% - ${skill.level}',
            style: pw.TextStyle(fontSize: 9, color: palette.body),
          ),
        ],
      ),
    );
  }

  static pw.Widget _projectEntry(
    ResumeProject project,
    ResumeDesignConfig designConfig,
    _ResumePalette palette,
  ) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Text(
                  project.title.trim().isEmpty ? 'Project' : project.title,
                  style: pw.TextStyle(
                    fontSize: 10.5,
                    fontWeight: pw.FontWeight.bold,
                    color: palette.text,
                  ),
                ),
              ),
              pw.Text(
                '${project.score.toStringAsFixed(0)}%',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: palette.primary,
                ),
              ),
            ],
          ),
          if (project.description.trim().isNotEmpty) ...[
            pw.SizedBox(height: 3),
            _paragraph(project.description, designConfig, palette),
          ],
          if (project.skills.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              'Skills: ${project.skills.join(', ')}',
              style: pw.TextStyle(fontSize: 8, color: palette.muted),
            ),
          ],
          if (project.githubLink.trim().isNotEmpty ||
              project.liveDemoLink.trim().isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              [
                if (project.githubLink.trim().isNotEmpty)
                  'GitHub: ${project.githubLink}',
                if (project.liveDemoLink.trim().isNotEmpty)
                  'Live: ${project.liveDemoLink}',
              ].join('  |  '),
              style: pw.TextStyle(fontSize: 8, color: palette.muted),
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _certificateEntry(
    ResumeCertificate certificate,
    _ResumePalette palette,
  ) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            certificate.title.trim().isEmpty
                ? 'Certificate'
                : certificate.title,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: palette.text,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            '${certificate.courseTitle} - ${certificate.score.toStringAsFixed(0)}% - ID: ${certificate.verificationCode}',
            style: pw.TextStyle(fontSize: 8.5, color: palette.muted),
          ),
        ],
      ),
    );
  }

  static pw.Widget _achievementEntry(
    ResumeAchievement achievement,
    ResumeDesignConfig designConfig,
    _ResumePalette palette,
  ) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            achievement.title.trim().isEmpty
                ? 'Achievement'
                : achievement.title,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: palette.text,
            ),
          ),
          if (achievement.description.trim().isNotEmpty) ...[
            pw.SizedBox(height: 2),
            _paragraph(achievement.description, designConfig, palette),
          ],
        ],
      ),
    );
  }

  static pw.Widget _bulletList(
    List<String> items,
    ResumeDesignConfig designConfig,
    _ResumePalette palette,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: items
          .where((item) => item.trim().isNotEmpty)
          .map(
            (item) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '- ',
                    style: pw.TextStyle(fontSize: _bodySize(designConfig)),
                  ),
                  pw.Expanded(child: _paragraph(item, designConfig, palette)),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  static bool _hasLinks(SmartResumeModel resume) {
    return resume.projects.any(
      (project) =>
          project.githubLink.trim().isNotEmpty ||
          project.liveDemoLink.trim().isNotEmpty,
    );
  }

  static List<String> _resumeLinks(SmartResumeModel resume) {
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

  static pw.EdgeInsets _pageMargin(ResumeDesignConfig designConfig) {
    return switch (designConfig.density) {
      ResumeDensity.compact => const pw.EdgeInsets.fromLTRB(30, 28, 30, 34),
      ResumeDensity.comfortable => const pw.EdgeInsets.fromLTRB(42, 40, 42, 46),
      ResumeDensity.balanced => const pw.EdgeInsets.fromLTRB(36, 34, 36, 42),
    };
  }

  static pw.EdgeInsets _densityPadding(ResumeDesignConfig designConfig) {
    return switch (designConfig.density) {
      ResumeDensity.compact => const pw.EdgeInsets.all(10),
      ResumeDensity.comfortable => const pw.EdgeInsets.all(16),
      ResumeDensity.balanced => const pw.EdgeInsets.all(14),
    };
  }

  static double _sectionGap(ResumeDesignConfig designConfig) {
    return switch (designConfig.density) {
      ResumeDensity.compact => 11,
      ResumeDensity.comfortable => 18,
      ResumeDensity.balanced => 15,
    };
  }

  static double _headingSize(ResumeDesignConfig designConfig) {
    return switch (designConfig.typographyStyle) {
      ResumeTypographyStyle.compact => 10,
      ResumeTypographyStyle.bold => 12,
      ResumeTypographyStyle.classic => 11,
      ResumeTypographyStyle.modern => 11,
    };
  }

  static double _bodySize(ResumeDesignConfig designConfig) {
    return switch (designConfig.typographyStyle) {
      ResumeTypographyStyle.compact => 9,
      ResumeTypographyStyle.bold => 10.2,
      ResumeTypographyStyle.classic => 10,
      ResumeTypographyStyle.modern => 10,
    };
  }

  static double _lineSpacing(ResumeDesignConfig designConfig) {
    return switch (designConfig.density) {
      ResumeDensity.compact => 2,
      ResumeDensity.comfortable => 4,
      ResumeDensity.balanced => 3,
    };
  }

  static _ResumePalette _paletteFor(ResumeDesignConfig designConfig) {
    final base = switch (designConfig.accentColor) {
      ResumeAccentColor.emerald => _ResumePalette(
        primary: PdfColors.green700,
        tintedSurface: PdfColors.green50,
        border: PdfColors.green100,
      ),
      ResumeAccentColor.purple => _ResumePalette(
        primary: PdfColors.purple700,
        tintedSurface: PdfColors.purple50,
        border: PdfColors.purple100,
      ),
      ResumeAccentColor.slate => _ResumePalette(
        primary: PdfColors.grey800,
        tintedSurface: PdfColors.grey100,
        border: PdfColors.grey300,
      ),
      ResumeAccentColor.skillforgeBlue => _ResumePalette(
        primary: PdfColors.blue700,
        tintedSurface: PdfColors.blue50,
        border: PdfColors.blue100,
      ),
    };

    return switch (designConfig.templateStyle) {
      ResumeTemplateStyle.minimal => base.copyWith(
        tintedSurface: PdfColors.white,
        border: PdfColors.grey300,
      ),
      ResumeTemplateStyle.technical => base.copyWith(
        tintedSurface: PdfColors.grey100,
      ),
      ResumeTemplateStyle.modern => base,
      ResumeTemplateStyle.professional => base,
    };
  }
}

class _ResumePalette {
  const _ResumePalette({
    required this.primary,
    required this.tintedSurface,
    required this.border,
    this.text = PdfColors.grey900,
    this.body = PdfColors.grey800,
    this.muted = PdfColors.grey700,
  });

  final PdfColor primary;
  final PdfColor tintedSurface;
  final PdfColor border;
  final PdfColor text;
  final PdfColor body;
  final PdfColor muted;

  _ResumePalette copyWith({
    PdfColor? primary,
    PdfColor? tintedSurface,
    PdfColor? border,
    PdfColor? text,
    PdfColor? body,
    PdfColor? muted,
  }) {
    return _ResumePalette(
      primary: primary ?? this.primary,
      tintedSurface: tintedSurface ?? this.tintedSurface,
      border: border ?? this.border,
      text: text ?? this.text,
      body: body ?? this.body,
      muted: muted ?? this.muted,
    );
  }
}
