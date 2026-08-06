/// Non-web: browser download is unavailable; caller should offer copy.
Future<bool> downloadTeacherBatchCsv({
  required String filename,
  required String csvContent,
}) async {
  return false;
}
