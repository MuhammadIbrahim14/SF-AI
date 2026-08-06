import 'dart:typed_data';

import 'package:printing/printing.dart';

class PdfExportService {
  const PdfExportService();

  Future<bool> sharePdf({required Uint8List bytes, required String filename}) {
    return Printing.sharePdf(bytes: bytes, filename: filename);
  }

  Future<void> printPdf({required Uint8List bytes, required String filename}) {
    return Printing.layoutPdf(name: filename, onLayout: (_) async => bytes);
  }
}
