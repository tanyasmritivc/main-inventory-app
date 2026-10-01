class AskSessionScope {
  String? _owner;

  bool selectAccount(String? accountId) {
    final reset = accountId == null || _owner != accountId;
    _owner = accountId;
    return reset;
  }
}

class AskSource {
  const AskSource({
    required this.kind,
    required this.label,
    required this.detail,
  });
  final String kind;
  final String label;
  final String detail;
}

class AskResultRow {
  const AskResultRow({
    required this.id,
    required this.name,
    required this.availableQuantity,
    this.requiredQuantity,
    this.location = '',
    this.status,
  });
  final String id;
  final String name;
  final int availableQuantity;
  final int? requiredQuantity;
  final String location;
  final String? status;
}

class AskAnswerContext {
  const AskAnswerContext({
    this.sources = const [],
    this.rows = const [],
    this.rowsTruncated = false,
  });
  final List<AskSource> sources;
  final List<AskResultRow> rows;
  final bool rowsTruncated;

  factory AskAnswerContext.fromJson(Map<String, dynamic> json) {
    String text(Object? value, [int limit = 200]) {
      if (value is! String) return '';
      return value.length <= limit ? value : value.substring(0, limit);
    }

    int? count(Object? value) =>
        value is num && value.isFinite && value >= 0 && value % 1 == 0
        ? value.toInt()
        : null;

    final sources = <AskSource>[];
    if (json['sources'] is List) {
      for (final raw in (json['sources'] as List).take(20)) {
        if (raw is! Map) continue;
        final kind = text(raw['kind']);
        final label = text(raw['label']);
        if (label.isEmpty ||
            !const {
              'inventory',
              'project',
              'document',
              'history',
              'spaces',
            }.contains(kind)) {
          continue;
        }
        sources.add(
          AskSource(kind: kind, label: label, detail: text(raw['detail'], 400)),
        );
      }
    }
    final rows = <AskResultRow>[];
    if (json['rows'] is List) {
      for (final raw in (json['rows'] as List).take(100)) {
        if (raw is! Map) continue;
        final name = text(raw['name']);
        final available = count(raw['available_quantity']);
        if (name.isEmpty || available == null) continue;
        final required = count(raw['required_quantity']);
        // Derive readiness from quantities. Do not trust a conflicting badge.
        final status = required == null
            ? null
            : available >= required
            ? 'have'
            : available == 0
            ? 'missing'
            : 'low';
        rows.add(
          AskResultRow(
            id: text(raw['id']),
            name: name,
            availableQuantity: available,
            requiredQuantity: required,
            location: text(raw['location']),
            status: status,
          ),
        );
      }
    }
    return AskAnswerContext(
      sources: sources,
      rows: rows,
      rowsTruncated: json['rows_truncated'] == true,
    );
  }
}
