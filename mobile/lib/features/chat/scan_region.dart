import 'dart:ui';

enum ScanRegionPhase { pending, checking, checked, unreadable }

/// Transient scan activity, never an inventory item or a confidence score.
class ScanRegion {
  const ScanRegion(this.id, this.box, this.phase);
  final int id;
  final Rect box;
  final ScanRegionPhase phase;

  String get status => switch (phase) {
    ScanRegionPhase.pending => 'Waiting',
    ScanRegionPhase.checking => 'Reading details',
    ScanRegionPhase.checked => 'Checked',
    ScanRegionPhase.unreadable => 'Needs review',
  };
}

/// Ignore unsupported or malformed events without moving a box to another item.
List<ScanRegion> applyScanRegions(List<ScanRegion> current, Object? event) {
  if (event is! Map) return current;
  final regions = <int, ScanRegion>{for (final r in current) r.id: r};
  ScanRegionPhase? phase(Object? value) {
    for (final p in ScanRegionPhase.values) {
      if (p.name == value) return p;
    }
    return null;
  }

  if (event['regions'] is List) {
    regions.clear();
    final seen = <int>{};
    final duplicates = <int>{};
    for (final row in (event['regions'] as List)) {
      if (row is! Map) continue;
      final id = row['id'];
      if (id is! int || id < 0) continue;
      if (!seen.add(id)) duplicates.add(id);
      final box = row['box'];
      final state = phase(row['state']);
      if (box is! List || box.length != 4 || state == null) continue;
      if (box.any((n) => n is! num || !n.isFinite || n < 0 || n > 1000)) {
        continue;
      }
      final rect = Rect.fromLTRB(
        (box[0] as num) / 1000,
        (box[1] as num) / 1000,
        (box[2] as num) / 1000,
        (box[3] as num) / 1000,
      );
      if (rect.isEmpty) continue;
      regions[id] = ScanRegion(id, rect, state);
    }
    for (final id in duplicates) {
      regions.remove(id);
    }
  }
  if (event['states'] is List) {
    for (final row in (event['states'] as List)) {
      if (row is! Map) continue;
      final region = regions[row['id']];
      final state = phase(row['state']);
      if (region == null || state == null) continue;
      // Late/replayed starts must not turn a completed crop back into activity.
      if ((region.phase == ScanRegionPhase.checked ||
              region.phase == ScanRegionPhase.unreadable) &&
          (state == ScanRegionPhase.pending ||
              state == ScanRegionPhase.checking)) {
        continue;
      }
      regions[region.id] = ScanRegion(region.id, region.box, state);
    }
  }
  return List.unmodifiable(
    regions.values.toList()..sort((a, b) => a.id.compareTo(b.id)),
  );
}
