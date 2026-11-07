import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/account_refresh.dart';
import 'package:mobile/core/inventory_cache.dart';

void main() {
  testWidgets('a deletion during a refresh triggers one fresh read', (
    tester,
  ) async {
    final first = Completer<void>();
    var reads = 0;
    final refresh = AccountRefresh(
      refresh: () async {
        if (++reads == 1) await first.future;
      },
      isActive: () => true,
    );
    unawaited(refresh.check());
    InventoryCache.clear();
    InventoryCache.clear();
    first.complete();
    await tester.pump();
    expect(reads, 2);
    refresh.dispose();
  });
  testWidgets('confirmed inventory mutations refresh counts immediately', (
    tester,
  ) async {
    var reads = 0;
    final refresh = AccountRefresh(
      refresh: () async {
        reads++;
      },
      isActive: () => true,
    );
    InventoryCache.clear();
    await tester.pump();
    expect(reads, 1);
    refresh.dispose();
    InventoryCache.clear();
    await tester.pump();
    expect(reads, 1);
  });
  testWidgets(
    'visible refresh coalesces requests and pauses for editors and disposal',
    (tester) async {
      var active = true;
      var reads = 0;
      var pending = Completer<void>();
      final refresh = AccountRefresh(
        refresh: () {
          reads++;
          return pending.future;
        },
        isActive: () => active,
      );
      await tester.pump(const Duration(seconds: 15));
      expect(reads, 1);
      await tester.pump(const Duration(seconds: 30));
      expect(reads, 1);
      pending.complete();
      await tester.pump();
      active = false; // An editor or a covered route must keep its draft.
      await tester.pump(const Duration(seconds: 15));
      expect(reads, 1);
      active = true;
      pending = Completer<void>();
      await tester.pump(const Duration(seconds: 15));
      expect(reads, 2);
      refresh.dispose();
      pending.complete();
      await tester.pump(const Duration(seconds: 30));
      expect(reads, 2);
    },
  );
}
