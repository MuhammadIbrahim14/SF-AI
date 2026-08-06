String listToCsv<T>(List<T> items, List<String> headers, List<List<String>> Function(T) rowMapper) {
  final buffer = StringBuffer();
  buffer.writeln(headers.join(','));
  for (final item in items) {
    final rows = rowMapper(item);
    for (final row in rows) {
      // escape commas and quotes
      final escaped = row.map((c) {
        if (c.contains(',') || c.contains('"') || c.contains('\n')) {
          final inner = c.replaceAll('"', '""');
          return '"$inner"';
        }
        return c;
      }).join(',');
      buffer.writeln(escaped);
    }
  }
  return buffer.toString();
}
