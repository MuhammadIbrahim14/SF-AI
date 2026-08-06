import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/pdf_export_service.dart';
import '../features/courses/data/models/certificate_model.dart';
import '../features/courses/data/models/smart_resume_model.dart';
import '../features/courses/pdf/certificate_design_config.dart';
import '../features/courses/pdf/certificate_pdf_builder.dart';
import '../features/courses/pdf/resume_design_config.dart';
import '../features/courses/pdf/resume_pdf_builder.dart';
import '../features/commerce/pdf/invoice_pdf_builder.dart';
import '../features/commerce/pdf/finance_report_pdf_builder.dart';
import '../features/company/hiring_lifecycle/pdf/offer_letter_pdf_builder.dart';
import '../features/company/hiring_lifecycle/providers/hiring_lifecycle_providers.dart';
import '../models/admin_finance_model.dart';
import '../models/application_model.dart';
import '../models/invoice_model.dart';

final pdfExportServiceProvider = Provider<PdfExportService>((ref) {
  return const PdfExportService();
});

final pdfExportActionProvider =
    AsyncNotifierProvider<PdfExportActionNotifier, void>(
      PdfExportActionNotifier.new,
    );

class PdfExportActionNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> exportCertificate(
    CertificateModel certificate, {
    CertificateDesignConfig designConfig = CertificateDesignConfig.standard,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final bytes = await CertificatePdfBuilder.build(
        certificate,
        designConfig: designConfig,
      );
      final shared = await ref
          .read(pdfExportServiceProvider)
          .sharePdf(
            bytes: bytes,
            filename:
                '${_safeFilename(certificate.studentName)}_${_safeFilename(certificate.courseTitle)}_certificate.pdf',
          );
      if (!shared) {
        throw StateError('The PDF export was cancelled.');
      }
    });
    return !state.hasError;
  }

  Future<bool> exportResume(
    SmartResumeModel resume, {
    ResumeDesignConfig designConfig = ResumeDesignConfig.standard,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final bytes = await ResumePdfBuilder.build(
        resume,
        designConfig: designConfig,
      );
      final shared = await ref
          .read(pdfExportServiceProvider)
          .sharePdf(
            bytes: bytes,
            filename: '${_safeFilename(resume.headline)}_smart_resume.pdf',
          );
      if (!shared) {
        throw StateError('The PDF export was cancelled.');
      }
    });
    return !state.hasError;
  }

  Future<bool> exportInvoice(InvoiceModel invoice) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final bytes = await InvoicePdfBuilder.build(invoice);
      final shared = await ref
          .read(pdfExportServiceProvider)
          .sharePdf(
            bytes: bytes,
            filename: '${_safeFilename(invoice.invoiceNumber)}.pdf',
          );
      if (!shared) {
        throw StateError('The invoice export was cancelled.');
      }
    });
    return !state.hasError;
  }

  Future<bool> printInvoice(InvoiceModel invoice) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final bytes = await InvoicePdfBuilder.build(invoice);
      await ref
          .read(pdfExportServiceProvider)
          .printPdf(
            bytes: bytes,
            filename: '${_safeFilename(invoice.invoiceNumber)}.pdf',
          );
    });
    return !state.hasError;
  }

  Future<bool> exportFinanceReport(
    AdminFinanceSnapshot snapshot, {
    String title = 'SkillForge Finance Summary',
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final bytes = await FinanceReportPdfBuilder.build(
        snapshot: snapshot,
        title: title,
      );
      final shared = await ref
          .read(pdfExportServiceProvider)
          .sharePdf(bytes: bytes, filename: '${_safeFilename(title)}.pdf');
      if (!shared) {
        throw StateError('The finance report export was cancelled.');
      }
    });
    return !state.hasError;
  }

  Future<bool> exportOfferLetter({
    required ApplicationModel application,
    required String companyName,
    required String candidateName,
    String? jobTitle,
    bool print = false,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final bytes = await OfferLetterPdfBuilder.build(
        application: application,
        companyName: companyName,
        candidateName: candidateName,
        jobTitle: jobTitle,
      );
      final filename = '${_safeFilename(candidateName)}_offer_letter.pdf';
      if (print) {
        await ref
            .read(pdfExportServiceProvider)
            .printPdf(bytes: bytes, filename: filename);
      } else {
        final shared = await ref
            .read(pdfExportServiceProvider)
            .sharePdf(bytes: bytes, filename: filename);
        if (!shared) {
          throw StateError('The offer letter export was cancelled.');
        }
      }
      try {
        await ref
            .read(hiringLifecycleServiceProvider)
            .markOfferDocumentGenerated(applicationId: application.id);
      } catch (_) {
        // Audit stamp is best-effort; PDF already generated.
      }
    });
    return !state.hasError;
  }

  String? get errorMessage => state.error?.toString();
}

String _safeFilename(String value) {
  final cleaned = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  return cleaned.isEmpty ? 'skillforge_export' : cleaned;
}
