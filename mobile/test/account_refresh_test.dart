import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/account_refresh.dart';

void main() {
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
