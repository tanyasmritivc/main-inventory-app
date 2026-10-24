/// Read-only discovery over saved fields. Numeric identifiers are never fuzzy.
String _normalize(String value) => value.toLowerCase();
List<String> _tokens(String value) => RegExp(
  r'[\p{L}\p{N}]+(?:\.[\p{L}\p{N}]+)*',
  unicode: true,
).allMatches(_normalize(value)).map((m) => m.group(0)!).toList();
String _compact(String value) =>
    _normalize(value).replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');
String _word(String value) {
  const aliases = {
    'adaptor': 'adapter',
    'batteries': 'battery',
    'shelves': 'shelf',
    'charging': 'charger',
    'little': 'small',
  };
  return aliases[value] ??
      (value.length > 3 &&
              value.endsWith('s') &&
              !value.endsWith('ss') &&
              !value.endsWith('us')
          ? value.substring(0, value.length - 1)
          : value);
}

bool _oneTypo(String a, String b) {
  if (a.length < 4 ||
      b.length < 4 ||
      RegExp(r'\d').hasMatch(a + b) ||
      (a.length - b.length).abs() > 1) {
    return false;
  }
  if (a.length == b.length) {
    final differences = <int>[];
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) differences.add(i);
    }
    return differences.length == 1 ||
        (differences.length == 2 &&
            differences[1] == differences[0] + 1 &&
            a[differences[0]] == b[differences[1]] &&
            a[differences[1]] == b[differences[0]]);
  }
  final short = a.length < b.length ? a : b;
  final long = a.length < b.length ? b : a;
  for (var i = 0; i < long.length; i++) {
    if (long.substring(0, i) + long.substring(i + 1) == short) return true;
  }
  return false;
}

int scoreItemSearch({
  required String query,
  required String name,
  required Iterable<String> fields,
  Iterable<String> identifiers = const [],
}) {
  final requested = _tokens(query);
  if (requested.isEmpty) return query.trim().isEmpty ? 1 : 0;
  final key = _compact(query);
  for (final id in identifiers) {
    if (key.isNotEmpty && _compact(id) == key) return 1000;
    if (key.length >= 2 &&
        (_compact(id).startsWith(key) || _tokens(id).contains(key))) {
      return 800;
    }
  }
  final words = fields
      .expand(_tokens)
      .expand((word) => [word, _word(word)])
      .toSet();
  var score = _normalize(query).trim() == _normalize(name).trim() ? 600 : 400;
  for (final term in requested) {
    final canonical = _word(term);
    if (words.contains(canonical)) continue;
    if (term.length >= 3 &&
        !RegExp(r'\d').hasMatch(term) &&
        words.any((word) => word.startsWith(canonical))) {
      if (score > 200) score = 200;
    } else if (words.any((word) => _oneTypo(canonical, word))) {
      score = 100;
    } else {
      return 0;
    }
  }
  return score;
}
