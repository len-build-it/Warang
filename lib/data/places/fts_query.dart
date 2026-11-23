/// Builds a safe SQLite FTS5 `MATCH` expression from raw user input.
///
/// Splits on whitespace, strips FTS5 operator and punctuation characters,
/// quotes each remaining token so reserved words such as `NEAR`, `AND`, `OR`,
/// and `NOT` match literally, and appends `*` to the last token for prefix
/// search. Returns `null` when no searchable token remains.
String? buildFtsQuery(String input) {
  final cleaned = input
      .replaceAll(
        RegExp(r'["\x27\-\*\(\)\^\:\+\~\{\}\[\]\\/,.;!?@#\$%&=<>\|\`]'),
        ' ',
      )
      .trim();
  if (cleaned.isEmpty) return null;
  final tokens = cleaned
      .split(RegExp(r'\s+'))
      .where((token) => token.isNotEmpty)
      .toList();
  if (tokens.isEmpty) return null;
  final parts = <String>[];
  for (var i = 0; i < tokens.length; i++) {
    final escaped = tokens[i].replaceAll('"', '');
    if (escaped.isEmpty) continue;
    final quoted = '"$escaped"';
    parts.add(i == tokens.length - 1 ? '$quoted*' : quoted);
  }
  return parts.isEmpty ? null : parts.join(' ');
}
