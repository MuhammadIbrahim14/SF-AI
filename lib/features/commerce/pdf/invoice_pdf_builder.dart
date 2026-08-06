import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../models/invoice_model.dart';

class InvoicePdfBuilder {
  const InvoicePdfBuilder._();

  static Future<Uint8List> build(InvoiceModel invoice) async {
    final document = pw.Document(
      title: invoice.invoiceNumber,
      author: invoice.platformName,
      creator: 'SkillForge AI',
    );
    final date = DateFormat('MMM d, yyyy');
    final accent = _accentFor(invoice.type);

    document.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          theme: pw.ThemeData.withFont(
            base: pw.Font.helvetica(),
            bold: pw.Font.helveticaBold(),
            italic: pw.Font.helveticaOblique(),
          ),
        ),
        build: (context) => [
          _header(invoice, accent),
          pw.SizedBox(height: 20),
          _sandboxBanner(),
          pw.SizedBox(height: 22),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _infoBox(
                  title: 'Bill To',
                  rows: [
                    invoice.clientName,
                    if (invoice.clientEmail.trim().isNotEmpty)
                      invoice.clientEmail,
                    'Client ID: ${invoice.clientId}',
                  ],
                ),
              ),
              pw.SizedBox(width: 14),
              pw.Expanded(
                child: _infoBox(
                  title: invoice.isPlatformInvoice ? 'Platform' : 'Provider',
                  rows: invoice.isPlatformInvoice
                      ? [
                          invoice.platformName,
                          invoice.platformEmail,
                          invoice.platformWebsite,
                        ]
                      : [
                          invoice.freelancerName,
                          if (invoice.freelancerEmail.trim().isNotEmpty)
                            invoice.freelancerEmail,
                          'Freelancer ID: ${invoice.freelancerId}',
                        ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          _invoiceFacts(invoice, date, accent),
          pw.SizedBox(height: 24),
          _serviceTable(invoice, accent),
          pw.SizedBox(height: 18),
          _totals(invoice),
          pw.Spacer(),
          _footer(invoice),
        ],
      ),
    );

    return document.save();
  }

  static pw.Widget _header(InvoiceModel invoice, PdfColor accent) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 54,
          height: 54,
          decoration: pw.BoxDecoration(
            color: accent,
            borderRadius: pw.BorderRadius.circular(14),
          ),
          child: pw.Center(
            child: pw.Text(
              'SF',
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 20,
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
                invoice.platformName,
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Professional sandbox marketplace billing',
                style: const pw.TextStyle(
                  color: PdfColors.blueGrey700,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              InvoiceType.label(invoice.type),
              style: pw.TextStyle(
                color: accent,
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              invoice.invoiceNumber,
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _sandboxBanner() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.amber50,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: PdfColors.amber300),
      ),
      child: pw.Text(
        'Sandbox invoice: no real payment, tax filing, payout, or settlement has been processed.',
        style: pw.TextStyle(
          color: PdfColors.amber900,
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.Widget _infoBox({
    required String title,
    required List<String> rows,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.blueGrey50,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: PdfColors.blueGrey100),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColors.blueGrey700,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          ...rows
              .where((row) => row.trim().isNotEmpty)
              .map(
                (row) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 3),
                  child: pw.Text(row, style: const pw.TextStyle(fontSize: 10)),
                ),
              ),
        ],
      ),
    );
  }

  static pw.Widget _invoiceFacts(
    InvoiceModel invoice,
    DateFormat date,
    PdfColor accent,
  ) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: PdfColors.blueGrey100),
      ),
      child: pw.Wrap(
        spacing: 24,
        runSpacing: 10,
        children: [
          _fact('Invoice ID', invoice.invoiceId),
          _fact('Order ID', invoice.orderId),
          _fact('Status', invoice.status.toUpperCase(), color: accent),
          _fact('Issued', date.format(invoice.issuedAt)),
          _fact(
            'Paid',
            invoice.paidAt == null ? 'Pending' : date.format(invoice.paidAt!),
          ),
          _fact('Verification', invoice.verificationCode),
        ],
      ),
    );
  }

  static pw.Widget _fact(String label, String value, {PdfColor? color}) {
    return pw.SizedBox(
      width: 150,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(
              color: PdfColors.blueGrey600,
              fontSize: 8,
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            value,
            style: pw.TextStyle(
              color: color ?? PdfColors.black,
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _serviceTable(InvoiceModel invoice, PdfColor accent) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.blueGrey100),
      columnWidths: const {0: pw.FlexColumnWidth(3), 1: pw.FlexColumnWidth(1)},
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: accent),
          children: [_tableHeader('Description'), _tableHeader('Amount')],
        ),
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(12),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    invoice.serviceTitle,
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    invoice.serviceDescription,
                    style: const pw.TextStyle(
                      color: PdfColors.blueGrey700,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(12),
              child: pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  _money(invoice.subtotal, invoice.currency),
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _tableHeader(String label) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(10),
      child: pw.Text(
        label,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontWeight: pw.FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }

  static pw.Widget _totals(InvoiceModel invoice) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.SizedBox(
        width: 240,
        child: pw.Column(
          children: [
            _totalRow('Subtotal', invoice.subtotal, invoice.currency),
            _totalRow('Platform fee', invoice.platformFee, invoice.currency),
            _totalRow('Tax', invoice.taxAmount, invoice.currency),
            pw.Divider(color: PdfColors.blueGrey200),
            _totalRow(
              'Total',
              invoice.totalAmount,
              invoice.currency,
              emphasized: true,
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _totalRow(
    String label,
    double value,
    String currency, {
    bool emphasized = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: emphasized ? 12 : 10,
              fontWeight: emphasized ? pw.FontWeight.bold : null,
            ),
          ),
          pw.Text(
            _money(value, currency),
            style: pw.TextStyle(
              fontSize: emphasized ? 12 : 10,
              fontWeight: emphasized ? pw.FontWeight.bold : null,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _footer(InvoiceModel invoice) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.only(top: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.blueGrey100)),
      ),
      child: pw.Text(
        '${invoice.platformName} - ${invoice.platformWebsite} - Verification code: ${invoice.verificationCode}',
        textAlign: pw.TextAlign.center,
        style: const pw.TextStyle(color: PdfColors.blueGrey600, fontSize: 9),
      ),
    );
  }
}

PdfColor _accentFor(String type) {
  return switch (InvoiceType.normalize(type)) {
    InvoiceType.freelancerInvoice => PdfColor.fromHex('#14B8A6'),
    InvoiceType.platformCommissionInvoice => PdfColor.fromHex('#F59E0B'),
    _ => PdfColor.fromHex('#6366F1'),
  };
}

String _money(double value, String currency) {
  return '$currency ${value.toStringAsFixed(2)}';
}
