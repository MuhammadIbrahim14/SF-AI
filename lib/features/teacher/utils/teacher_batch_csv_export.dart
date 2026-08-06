import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../providers/teacher_batch_provider.dart';
import 'teacher_batch_csv_download_stub.dart'
    if (dart.library.html) 'teacher_batch_csv_download_web.dart'
    as csv_download;

String buildTeacherBatchRosterCsv({
  required String batchTitle,
  required List<TeacherBatchRosterEntry> roster,
}) {
  final buffer = StringBuffer();
  buffer.writeln(
    _csvRow([
      'studentId',
      'name',
      'email',
      'progress',
      'riskFlag',
      'riskReasons',
      'batchTitle',
    ]),
  );
  for (final entry in roster) {
    final riskFlag = entry.isAtRisk
        ? 'at_risk'
        : entry.needsAttention
        ? 'needs_attention'
        : 'healthy';
    buffer.writeln(
      _csvRow([
        entry.studentId,
        entry.studentName,
        entry.studentEmail,
        entry.averageProgress.round().toString(),
        riskFlag,
        entry.riskReasons.join('; '),
        batchTitle,
      ]),
    );
  }
  return buffer.toString();
}

String _csvRow(List<String> cells) {
  return cells.map(_csvEscape).join(',');
}

String _csvEscape(String value) {
  final needsQuotes =
      value.contains(',') ||
      value.contains('"') ||
      value.contains('\n') ||
      value.contains('\r');
  final escaped = value.replaceAll('"', '""');
  return needsQuotes ? '"$escaped"' : escaped;
}

class TeacherBatchCsvExportResult {
  const TeacherBatchCsvExportResult({
    required this.copied,
    required this.downloaded,
  });

  final bool copied;
  final bool downloaded;
}

/// Copies CSV to clipboard; on web also triggers a file download when possible.
Future<TeacherBatchCsvExportResult> exportTeacherBatchRosterCsv({
  required String batchTitle,
  required List<TeacherBatchRosterEntry> roster,
}) async {
  final csv = buildTeacherBatchRosterCsv(
    batchTitle: batchTitle,
    roster: roster,
  );
  await Clipboard.setData(ClipboardData(text: csv));
  var downloaded = false;
  if (kIsWeb) {
    final safeTitle = batchTitle
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final filename =
        '${safeTitle.isEmpty ? 'batch' : safeTitle}-roster.csv';
    downloaded = await csv_download.downloadTeacherBatchCsv(
      filename: filename,
      csvContent: csv,
    );
  }
  return TeacherBatchCsvExportResult(copied: true, downloaded: downloaded);
}
