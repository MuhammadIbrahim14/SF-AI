import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../models/admin_finance_model.dart';

class FinanceReportPdfBuilder {
  const FinanceReportPdfBuilder._();

  static Future<Uint8List> build({
    required AdminFinanceSnapshot snapshot,
    required String title,
  }) async {
    final document = pw.Document(
      title: title,
      author: 'SkillForge AI',
      creator: 'SkillForge AI',
    );
    final kpis = snapshot.kpis;
    final date = DateFormat('MMM d, yyyy h:mm a');

    document.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          theme: pw.ThemeData.withFont(
            base: pw.Font.helvetica(),
            bold: pw.Font.helveticaBold(),
          ),
        ),
        build: (context) => [
          _header(title, date.format(snapshot.generatedAt)),
          pw.SizedBox(height: 18),
          _sandboxNotice(),
          pw.SizedBox(height: 18),
          _sectionTitle('Revenue Summary'),
          _metricGrid([
            _metric(
              'Today Revenue',
              _money(kpis.todayRevenue, snapshot.currency),
            ),
            _metric(
              'Weekly Revenue',
              _money(kpis.weeklyRevenue, snapshot.currency),
            ),
            _metric(
              'Monthly Revenue',
              _money(kpis.monthlyRevenue, snapshot.currency),
            ),
            _metric(
              'Yearly Revenue',
              _money(kpis.yearlyRevenue, snapshot.currency),
            ),
            _metric(
              'Lifetime Revenue',
              _money(kpis.lifetimeRevenue, snapshot.currency),
            ),
            _metric(
              'Platform Commission',
              _money(kpis.platformCommission, snapshot.currency),
            ),
            _metric('Net Revenue', _money(kpis.netRevenue, snapshot.currency)),
            _metric(
              'Average Order Value',
              _money(kpis.averageOrderValue, snapshot.currency),
            ),
          ]),
          pw.SizedBox(height: 18),
          _sectionTitle('Operations'),
          _metricGrid([
            _metric('Orders', '${kpis.orderCount}'),
            _metric('Completed Orders', '${kpis.completedOrders}'),
            _metric('Pending Orders', '${kpis.pendingOrders}'),
            _metric('Cancelled Orders', '${kpis.cancelledOrders}'),
            _metric('Refund Count', '${kpis.refundCount}'),
            _metric(
              'Refund Value',
              _money(kpis.refundValue, snapshot.currency),
            ),
            _metric('Escrow Held', _money(kpis.escrowHeld, snapshot.currency)),
            _metric(
              'Escrow Released',
              _money(kpis.escrowReleased, snapshot.currency),
            ),
          ]),
          pw.SizedBox(height: 18),
          _sectionTitle('Wallets & Payouts'),
          _metricGrid([
            _metric(
              'Wallet Available',
              _money(kpis.walletAvailable, snapshot.currency),
            ),
            _metric(
              'Wallet Pending',
              _money(kpis.walletPending, snapshot.currency),
            ),
            _metric(
              'Wallet Escrow',
              _money(kpis.walletEscrow, snapshot.currency),
            ),
            _metric(
              'Pending Withdrawals',
              _money(kpis.pendingWithdrawals, snapshot.currency),
            ),
            _metric(
              'Completed Withdrawals',
              _money(kpis.completedWithdrawals, snapshot.currency),
            ),
            _metric(
              'Avg Completion Hours',
              kpis.averageCompletionHours.toStringAsFixed(1),
            ),
          ]),
          pw.SizedBox(height: 18),
          _breakdown('Top Services', snapshot.topServices(), snapshot.currency),
          pw.SizedBox(height: 12),
          _breakdown(
            'Top Freelancers',
            snapshot.topFreelancers(),
            snapshot.currency,
          ),
          pw.SizedBox(height: 12),
          _breakdown(
            'Top Categories',
            snapshot.topCategories(),
            snapshot.currency,
          ),
          pw.SizedBox(height: 20),
          _footer(),
        ],
      ),
    );

    return document.save();
  }

  static pw.Widget _header(String title, String generatedAt) {
    return pw.Row(
      children: [
        pw.Container(
          width: 48,
          height: 48,
          decoration: pw.BoxDecoration(
            color: PdfColors.red600,
            borderRadius: pw.BorderRadius.circular(12),
          ),
          child: pw.Center(
            child: pw.Text(
              'SF',
              style: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'Generated $generatedAt',
                style: const pw.TextStyle(
                  color: PdfColors.blueGrey700,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _sandboxNotice() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.amber50,
        border: pw.Border.all(color: PdfColors.amber300),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Text(
        'Sandbox commerce report only. No real payment gateway, bank transfer, or external payout is represented.',
        style: pw.TextStyle(
          color: PdfColors.amber900,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.Widget _sectionTitle(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Text(
        title,
        style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  static pw.Widget _metricGrid(List<pw.Widget> metrics) {
    return pw.Wrap(spacing: 8, runSpacing: 8, children: metrics);
  }

  static pw.Widget _metric(String label, String value) {
    return pw.Container(
      width: 165,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.blueGrey100),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(
              color: PdfColors.blueGrey700,
              fontSize: 8,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  static pw.Widget _breakdown(
    String title,
    List<FinanceBreakdownItem> items,
    String currency,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle(title),
        pw.TableHelper.fromTextArray(
          headers: const ['Name', 'Count', 'Amount'],
          data: items
              .map(
                (item) => [
                  item.label,
                  '${item.count}',
                  _money(item.amount, currency),
                ],
              )
              .toList(),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey50),
          border: pw.TableBorder.all(color: PdfColors.blueGrey100),
          cellStyle: const pw.TextStyle(fontSize: 9),
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 9,
          ),
        ),
      ],
    );
  }

  static pw.Widget _footer() {
    return pw.Text(
      'Prepared by SkillForge AI Admin Finance Center. CSV export architecture is intentionally reserved for a future phase.',
      style: const pw.TextStyle(color: PdfColors.blueGrey600, fontSize: 8),
    );
  }

  static String _money(double value, String currency) {
    return '$currency ${value.toStringAsFixed(2)}';
  }
}
