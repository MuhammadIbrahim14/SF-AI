import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/utils/app_logger.dart';
import '../models/payment_models.dart';

class InvoiceService {
  Future<void> generateAndDisplayInvoice({
    required PaymentRecordModel payment,
    required String businessName,
    required String businessEmail,
    required String companyRegistration,
  }) async {
    final pdf = pw.Document();

    final invoice = _buildInvoice(
      payment: payment,
      businessName: businessName,
      businessEmail: businessEmail,
      companyRegistration: companyRegistration,
    );

    pdf.addPage(invoice);

    try {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => await pdf.save(),
        name:
            'Invoice_${payment.transactionId}_${payment.createdAt.year}${payment.createdAt.month.toString().padLeft(2, '0')}${payment.createdAt.day.toString().padLeft(2, '0')}.pdf',
      );
    } catch (_) {
      AppLogger.warn('Invoice PDF could not be displayed.');
    }
  }

  Future<Uint8List> generateInvoicePdf({
    required PaymentRecordModel payment,
    required String businessName,
    required String businessEmail,
    required String companyRegistration,
  }) async {
    final pdf = pw.Document();

    final invoice = _buildInvoice(
      payment: payment,
      businessName: businessName,
      businessEmail: businessEmail,
      companyRegistration: companyRegistration,
    );

    pdf.addPage(invoice);
    return await pdf.save();
  }

  pw.Page _buildInvoice({
    required PaymentRecordModel payment,
    required String businessName,
    required String businessEmail,
    required String companyRegistration,
  }) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final invoiceNumber = 'INV-${payment.transactionId.toUpperCase().substring(0, 8)}-${payment.createdAt.year}';
    
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header with business info
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      businessName,
                      style: pw.TextStyle(
                        fontSize: 28,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      businessEmail,
                      style: const pw.TextStyle(fontSize: 11, color: PdfColor.fromInt(0xFF666666)),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'INVOICE',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromInt(0xFF5B7CFF),
                      ),
                    ),
                    if (payment.gateway == PaymentGateway.skillforgeDemo ||
                        payment.metadata['isDemo'] == true ||
                        payment.metadata['environment'] == 'demo') ...[
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'DEMO / TEST — NO REAL MONEY',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromInt(0xFFB45309),
                        ),
                      ),
                    ],
                    pw.SizedBox(height: 4),
                    pw.Text(
                      invoiceNumber,
                      style: const pw.TextStyle(fontSize: 11, color: PdfColor.fromInt(0xFF666666)),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 30),
            
            // Invoice details
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'INVOICE DATE',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromInt(0xFF666666),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      dateFormat.format(payment.createdAt),
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'TRANSACTION ID',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromInt(0xFF666666),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      payment.transactionId,
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'PAYMENT STATUS',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromInt(0xFF666666),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      payment.status,
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PaymentStatus.isSuccess(payment.status)
                            ? PdfColor.fromInt(0xFF22C55E)
                            : PaymentStatus.isPending(payment.status)
                                ? PdfColor.fromInt(0xFFF59E0B)
                                : PdfColor.fromInt(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 30),
            
            // Items table
            pw.Table(
              border: pw.TableBorder.all(
                color: PdfColor.fromInt(0xFFE5E7EB),
                width: 1,
              ),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1),
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFF5B7CFF),
                  ),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'DESCRIPTION',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'QUANTITY',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'AMOUNT',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
                // Item row
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            payment.description,
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'Transaction: ${payment.transactionId}',
                            style: const pw.TextStyle(
                              fontSize: 9,
                              color: PdfColor.fromInt(0xFF999999),
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        '1',
                        style: const pw.TextStyle(fontSize: 11),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        '${payment.currency} ${payment.amount.toStringAsFixed(2)}',
                        style: const pw.TextStyle(fontSize: 11),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            
            // Totals section
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.SizedBox(
                width: 200,
                child: pw.Column(
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Subtotal',
                          style: const pw.TextStyle(fontSize: 11),
                        ),
                        pw.Text(
                          '${payment.currency} ${payment.amount.toStringAsFixed(2)}',
                          style: const pw.TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Tax',
                          style: const pw.TextStyle(fontSize: 11),
                        ),
                        pw.Text(
                          '${payment.currency} 0.00',
                          style: const pw.TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 12),
                    pw.Container(
                      decoration: pw.BoxDecoration(
                        border: pw.Border(
                          top: pw.BorderSide(
                            color: PdfColor.fromInt(0xFF5B7CFF),
                            width: 2,
                          ),
                        ),
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'TOTAL',
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            '${payment.currency} ${payment.amount.toStringAsFixed(2)}',
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromInt(0xFF5B7CFF),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            pw.SizedBox(height: 40),
            
            // Footer
            pw.Divider(color: PdfColor.fromInt(0xFFE5E7EB)),
            pw.SizedBox(height: 12),
            if (payment.gateway == PaymentGateway.skillforgeDemo ||
                payment.metadata['isDemo'] == true ||
                payment.metadata['environment'] == 'demo')
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 10),
                child: pw.Text(
                  'This is a DEMO invoice generated by SkillForge Demo Gateway. No real money was transferred.',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromInt(0xFFB45309),
                  ),
                ),
              ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'COMPANY INFORMATION',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromInt(0xFF666666),
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Company: $businessName',
                  style: const pw.TextStyle(fontSize: 9),
                ),
                pw.Text(
                  'Registration: $companyRegistration',
                  style: const pw.TextStyle(fontSize: 9),
                ),
                pw.Text(
                  'Email: $businessEmail',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Text(
              'Thank you for your payment. This invoice is automatically generated and requires no signature.',
              style: pw.TextStyle(
                fontSize: 9,
                color: PdfColor.fromInt(0xFF999999),
                fontStyle: pw.FontStyle.italic,
              ),
            ),
          ],
        );
      },
    );
  }
}
