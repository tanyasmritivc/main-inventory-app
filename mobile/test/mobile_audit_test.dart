import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/core/ui/app_colors.dart';
import 'package:mobile/features/review/review_queue_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'support/hierarchy_fixture.dart';

class AuditReviewApi extends ApiClient {
  AuditReviewApi() : super(baseUrl: 'https://api.test');
  bool failRead = false;
  bool quantityMissing = false;
  int writes = 0;
  Completer<InventoryItem>? pending;
  @override
  String get accountId => 'audit';
  @override
  Future<Map<String, dynamic>> getMyProfile() async => {};
  @override
  Future<Map<String, dynamic>> getNotifications() async => {'unread_count': 0};
  @override
  Future<ReviewQueueResult> getReviewItems({int limit = 100}) async {
    if (failRead) throw const FormatException('Could not refresh Review.');
    return ReviewQueueResult(
      items: [
        ReviewItem.fromJson({
          'review_id': 'capture',
          'name': 'Sample item',
          'category': 'Tools',
          'location': 'Workshop',
          'quantity': 2,
          'status': 'pending',
          if (quantityMissing) 'scan_evidence': {'quantity_basis': 'unknown'},
        }),
      ],
      pendingCount: 1,
    );
  }

  @override
  Future<InventoryItem> resolveReviewItem({
    required String reviewId,
    required ExtractedInventoryItem item,
  }) {
    writes++;
    return pending!.future;
  }
}

double contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return ((x > y ? x : y) + .05) / ((x > y ? y : x) + .05);
}

void main() {
  final fixture = HierarchyFixture();
  setUpAll(() => fixture.initialize());
  tearDownAll(() => Supabase.instance.dispose());
  for (final brightness in Brightness.values) {
    testWidgets(
      '${brightness.name} hints and muted labels meet text contrast',
      (tester) async {
        final theme = AppTheme.create(brightness);
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Builder(
              builder: (context) {
                for (final foreground in [
                  theme.inputDecorationTheme.hintStyle!.color!,
                  AppTheme.foreground(context, AppColors.hint),
                  AppTheme.textMuted(context),
                  AppTheme.sectionLabel(context),
                ]) {
                  for (final background in [
                    theme.scaffoldBackgroundColor,
                    theme.colorScheme.surface,
                    theme.colorScheme.surfaceContainer,
                  ]) {
                    expectSync(
                      contrast(foreground, background),
                      greaterThanOrEqualTo(4.5),
                      reason: '$foreground on $background',
                    );
                  }
                }
                return const Scaffold();
              },
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  Future<void> open(WidgetTester tester, AuditReviewApi api) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.create(Brightness.light),
        home: ReviewQueuePage(api: api, location: 'Workshop'),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Review refresh failure remains visible alongside saved rows', (
    tester,
  ) async {
    final api = AuditReviewApi();
    await open(tester, api);
    api.failRead = true;
    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();
    expect(find.text('Sample item'), findsOneWidget);
    expect(find.text('Could not refresh Review.'), findsOneWidget);
    api.failRead = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Could not refresh Review.'), findsNothing);
    expect(find.text('Sample item'), findsOneWidget);
  });

  testWidgets('Review keeps edits when Back is cancelled', (tester) async {
    final api = AuditReviewApi();
    await open(tester, api);
    await tester.tap(find.text('Sample item'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Decrease quantity'), findsOneWidget);
    expect(find.byTooltip('Increase quantity'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Edited item');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Edited item'), findsOneWidget);
    expect(api.writes, 0);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard changes'));
    await tester.pumpAndSettle();
    expect(find.text('Review capture'), findsNothing);
    expect(find.text('Sample item'), findsOneWidget);
  });

  testWidgets('Review protects an unfinished quantity edit', (tester) async {
    await open(tester, AuditReviewApi()..quantityMissing = true);
    await tester.tap(find.text('Sample item'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byType(TextFormField),
      200,
      scrollable: find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .last,
    );
    await tester.enterText(find.byType(TextFormField), '2.');
    await tester.tap(find.byTooltip('Close review'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('2.'), findsOneWidget);
  });

  testWidgets(
    'Review blocks dismissal during save and retains a failed draft',
    (tester) async {
      final api = AuditReviewApi()..pending = Completer<InventoryItem>();
      await open(tester, api);
      await tester.tap(find.text('Sample item'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Edited item');
      await tester.ensureVisible(find.text('Confirm and add to Find'));
      await tester.tap(find.text('Confirm and add to Find'));
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Review capture'), findsOneWidget);
      expect(api.writes, 1);
      api.pending!.completeError(
        const FormatException('Save failed. Try again.'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Edited item'), findsOneWidget);
      expect(find.text('Save failed. Try again.'), findsOneWidget);
      api.pending = Completer<InventoryItem>();
      await tester.tap(find.text('Confirm and add to Find'));
      await tester.pump();
      api.pending!.complete(
        InventoryItem.fromJson({
          'id': 'saved',
          'name': 'Edited item',
          'category': 'Tools',
          'location': 'Workshop',
          'quantity': 2,
        }),
      );
      await tester.pumpAndSettle();
      expect(find.text('Review capture'), findsNothing);
      expect(api.writes, 2);
    },
  );

  testWidgets('Review editor stays usable in a short large-text viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await open(tester, AuditReviewApi());
    await tester.tap(find.text('Sample item'));
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(320, 350);
    tester.platformDispatcher.textScaleFactorTestValue = 3.2;
    await tester.pumpAndSettle();
    final layoutError = tester.takeException();
    expect(
      layoutError,
      isNull,
      reason: layoutError is FlutterError
          ? layoutError.toDiagnosticsNode().toStringDeep()
          : null,
    );
    await tester.scrollUntilVisible(
      find.text('Confirm and add to Find'),
      150,
      scrollable: find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .last,
      maxScrolls: 100,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Close review'));
    await tester.pumpAndSettle();
    expect(find.text('Review capture'), findsNothing);
  });
}
