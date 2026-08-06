import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../models/application_model.dart';

class OfferLetterPdfBuilder {
  const OfferLetterPdfBuilder._();

  static Future<Uint8List> build({
    required ApplicationModel application,
    required String companyName,
    required String candidateName,
    String? jobTitle,
  }) async {
    final document = pw.Document(
      title: 'Offer Letter — $candidateName',
      author: companyName,
      creator: 'SkillForge AI',
    );
    final dateFmt = DateFormat('MMMM d, yyyy');
    final accent = PdfColor.fromInt(0xFF1B4F72);
    final role = application.offerRole.isNotEmpty
        ? application.offerRole
        : (jobTitle ?? 'the offered role');
    final generatedOn = application.offerDocumentGeneratedAt ?? DateTime.now();

    document.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          theme: pw.ThemeData.withFont(
            base: pw.Font.helvetica(),
            bold: pw.Font.helveticaBold(),
            italic: pw.Font.helveticaOblique(),
          ),
        ),
        build: (context) => [
          _header(companyName, accent),
          pw.SizedBox(height: 28),
          pw.Text(
            'Offer of Employment',
            style: pw.TextStyle(
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
              color: accent,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Date: ${dateFmt.format(application.offerSentAt ?? generatedOn)}',
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 22),
          pw.Text(
            'Dear $candidateName,',
            style: const pw.TextStyle(fontSize: 12),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'We are pleased to offer you the position of $role'
            '${companyName.trim().isEmpty ? '' : ' at $companyName'}. '
            'This letter summarizes the key terms of your employment offer.',
            style: const pw.TextStyle(fontSize: 11, lineSpacing: 3),
          ),
          pw.SizedBox(height: 20),
          _sectionTitle('Offer details', accent),
          pw.SizedBox(height: 10),
          _factsTable(application, role),
          if (application.offerMessage.trim().isNotEmpty ||
              application.offerDetails.trim().isNotEmpty) ...[
            pw.SizedBox(height: 18),
            _sectionTitle('Message from the company', accent),
            pw.SizedBox(height: 8),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Text(
                application.offerMessage.trim().isNotEmpty
                    ? application.offerMessage.trim()
                    : application.offerDetails.trim(),
                style: const pw.TextStyle(fontSize: 11, lineSpacing: 3),
              ),
            ),
          ],
          pw.SizedBox(height: 22),
          pw.Text(
            'Please respond to this offer through SkillForge AI '
            '(Accept, Decline, or Request Clarification). '
            'Acceptance in the app constitutes your electronic acceptance '
            'of these terms for this hiring workflow.',
            style: const pw.TextStyle(fontSize: 10, lineSpacing: 2.5),
          ),
          pw.SizedBox(height: 28),
          pw.Text(
            'Sincerely,',
            style: const pw.TextStyle(fontSize: 11),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            companyName.trim().isEmpty ? 'Hiring Team' : companyName,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Spacer(),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 6),
          pw.Text(
            'Generated via SkillForge AI · ${dateFmt.format(generatedOn)}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ],
      ),
    );

    return document.save();
  }

  static pw.Widget _header(String companyName, PdfColor accent) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 48,
          height: 48,
          decoration: pw.BoxDecoration(
            color: accent,
            borderRadius: pw.BorderRadius.circular(12),
          ),
          child: pw.Center(
            child: pw.Text(
              'SF',
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ),
        pw.SizedBox(width: 14),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                companyName.trim().isEmpty ? 'SkillForge AI' : companyName,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Employment Offer Letter',
                style: const pw.TextStyle(
                  fontSize: 11,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _sectionTitle(String title, PdfColor accent) {
    return pw.Text(
      title,
      style: pw.TextStyle(
        fontSize: 13,
        fontWeight: pw.FontWeight.bold,
        color: accent,
      ),
    );
  }

  static pw.Widget _factsTable(ApplicationModel app, String role) {
    final rows = <List<String>>[
      ['Role', role],
      if (app.offerDepartment.isNotEmpty) ['Department', app.offerDepartment],
      if (app.offerSalary.isNotEmpty)
        [
          'Compensation',
          '${app.offerSalary} ${app.offerCurrency}'.trim(),
        ],
      if (app.offerEmploymentType.isNotEmpty)
        ['Employment type', app.offerEmploymentType],
      if (app.offerJoiningDate.isNotEmpty) ['Joining date', app.offerJoiningDate],
      if (app.offerLocation.isNotEmpty) ['Location', app.offerLocation],
      if (app.offerWorkingHours.isNotEmpty) ['Working hours', app.offerWorkingHours],
      if (app.offerContractDuration.isNotEmpty)
        ['Contract duration', app.offerContractDuration],
      if (app.offerBenefits.isNotEmpty) ['Benefits', app.offerBenefits],
      if (app.offerExpiresAt.isNotEmpty) ['Offer expires', app.offerExpiresAt],
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.6),
      columnWidths: {
        0: const pw.FixedColumnWidth(130),
        1: const pw.FlexColumnWidth(),
      },
      children: [
        for (final row in rows)
          pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(
                  row[0],
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(row[1], style: const pw.TextStyle(fontSize: 10)),
              ),
            ],
          ),
      ],
    );
  }
}
