import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/features/scan/capture_progress.dart';
import 'package:mobile/features/scan/confirm_scan_sheet.dart';

class CaptureHarness {
  final root = GlobalKey<NavigatorState>();
  final nested = GlobalKey<NavigatorState>();
  late BuildContext spaceContext;
  int calls = 0;

  Future<void> mount(
    WidgetTester tester,
    Future<void> Function() extract,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: root,
        home: Scaffold(
          body: Navigator(
            key: nested,
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Inventory directory')),
            ),
          ),
        ),
      ),
    );
    unawaited(
      nested.currentState!.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            body: Builder(
              builder: (context) {
                spaceContext = context;
                return Column(
                  children: [
                    const Text('Space items'),
                    ElevatedButton(
                      onPressed: () async {
                        final sourceRoute = ModalRoute.of(context);
                        try {
                          await runWithCaptureProgress(
                            context: context,
                            extract: () {
                              calls++;
                              return extract();
                            },
                          );
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Try again')),
                            );
                          }
                          return;
                        }
                        if (!context.mounted || sourceRoute?.isCurrent == false) {
                          return;
                        }
                        await showModalBottomSheet<
                          List<ExtractedInventoryItem>
                        >(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => ConfirmScanSheet(
                            items: [
                              ExtractedInventoryItem(
                                name: 'Fixture motor',
                                category: 'Robot Parts',
                                quantity: 1,
                              ),
                            ],
                            defaultLocation: 'Fixture Space',
                          ),
                        );
                      },
                      child: const Text('Scan photo'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> start(WidgetTester tester) async {
    await tester.tap(find.text('Scan photo'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Extracting items…'), findsOneWidget);
  }
}

void main() {
  testWidgets('completed extraction removes root spinner before confirmation', (
    tester,
  ) async {
    final work = Completer<void>();
    final harness = CaptureHarness();
    await harness.mount(tester, () => work.future);
    await harness.start(tester);
    work.complete();
    await tester.pumpAndSettle();
    expect(find.text('Extracting items…', skipOffstage: false), findsNothing);
    expect(find.text('Confirm Items'), findsOneWidget);
    expect(harness.calls, 1);
    expect(harness.root.currentState!.canPop(), isFalse);
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();
    expect(find.text('Space items'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('failure clears only progress and lets the same Space retry', (
    tester,
  ) async {
    var work = Completer<void>();
    final harness = CaptureHarness();
    await harness.mount(tester, () => work.future);
    await harness.start(tester);
    work.completeError(TimeoutException('Interrupted fixture request'));
    await tester.pumpAndSettle();
    expect(find.text('Extracting items…', skipOffstage: false), findsNothing);
    expect(find.text('Space items'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    work = Completer<void>();
    await harness.start(tester);
    work.complete();
    await tester.pumpAndSettle();
    expect(harness.calls, 2);
    expect(find.text('Confirm Items'), findsOneWidget);
    expect(find.text('Extracting items…', skipOffstage: false), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('cleanup never dismisses a different root modal', (tester) async {
    final work = Completer<void>();
    final harness = CaptureHarness();
    await harness.mount(tester, () => work.future);
    await harness.start(tester);
    unawaited(
      showDialog<void>(
        context: harness.spaceContext,
        builder: (_) => const AlertDialog(title: Text('Other modal')),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    work.complete();
    await tester.pumpAndSettle();
    expect(find.text('Other modal'), findsOneWidget);
    expect(find.text('Extracting items…', skipOffstage: false), findsNothing);
    harness.root.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('Confirm Items'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('leaving the Space still cleans up the root dialog', (
    tester,
  ) async {
    final work = Completer<void>();
    final harness = CaptureHarness();
    await harness.mount(tester, () => work.future);
    await harness.start(tester);
    harness.nested.currentState!.pop();
    await tester.pump(const Duration(milliseconds: 300));
    work.complete();
    await tester.pumpAndSettle();
    expect(find.text('Extracting items…', skipOffstage: false), findsNothing);
    expect(find.text('Confirm Items'), findsNothing);
    expect(find.text('Inventory directory'), findsOneWidget);
    expect(harness.root.currentState!.canPop(), isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
