import 'dart:typed_data';

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
    this.photoUrl,
  });
  final List<AskSource> sources;
  final List<AskResultRow> rows;
  final bool rowsTruncated;
  final String? photoUrl;

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
              'photo',
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
      photoUrl: text(json['photo_url'], 2000).isEmpty
          ? null
          : text(json['photo_url'], 2000),
    );
  }
}

class AskPhoto {
  const AskPhoto({required this.bytes});
  final Uint8List bytes;
  static const maxBytes = 10 * 1024 * 1024;
}

// History previews load only app-owned photos on a configured origin.
String? trustedAskPhotoUrl(
  String? value, {
  required String? owner,
  required List<String> origins,
}) {
  if (value == null || owner == null || owner.isEmpty) return null;
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.userInfo.isNotEmpty ||
      uri.fragment.isNotEmpty) {
    return null;
  }
  if (!origins.any(
    (origin) =>
        Uri.tryParse(origin)?.hasAuthority == true &&
        Uri.parse(origin).origin == uri.origin,
  )) {
    return null;
  }
  final path = uri.pathSegments;
  if (path.length != 7 ||
      path[0] != 'storage' ||
      path[1] != 'v1' ||
      path[2] != 'object' ||
      !{'public', 'sign'}.contains(path[3]) ||
      path[4].isEmpty ||
      path[5] != owner) {
    return null;
  }
  return RegExp(r'^ask-[a-f0-9]{32}\.jpg$').hasMatch(path[6]) ? value : null;
}
