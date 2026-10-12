/// PostgREST one-to-one relationships are objects while one-to-many are lists.
List<Map<String, dynamic>> relationRows(Object? raw) {
  if (raw == null) return <Map<String, dynamic>>[];
  if (raw is Map) return [Map<String, dynamic>.from(raw)];
  if (raw is List) {
    return raw.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }
  throw const FormatException('Invalid embedded relation');
}
