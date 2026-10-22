import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/core/ask_answer.dart';
import 'package:mobile/features/chat/chat_photo_attachment_card.dart';

Future<void> Function(String)? photoAuditCapture;
Map<String, dynamic> proposal() => {
  'version': 1,
  'id': 'request',
  'conversation_id': 'chat',
  'status': 'pending',
  'choices': [
    for (final shelf in ['A', 'B'])
      {
        'item_id': shelf,
        'inventory_id': 'parts',
        'name': 'Arduino Uno',
        'location': 'Shelf $shelf',
        'inventory_name': 'Parts',
        'workspace_name': 'Lab',
        'match': 'similar',
      },
  ],
};

class PhotoApi extends ApiClient {
  PhotoApi() : super(worldKey: 'organization', baseUrl: 'https://api.test');
  final sent = <Map<String, dynamic>>[];
  bool fail = false;
  late Map<String, dynamic> current = proposal();
  Completer<Map<String, dynamic>>? delayed;
  @override
  Future<Map<String, dynamic>> decideChatPhotoAttachment(
    Map<String, dynamic> card,
    String decision, {
    Map<String, dynamic>? choice,
  }) async {
    sent.add({'decision': decision, 'choice': choice});
    if (decision == 'cancel') return {...card, 'status': 'cancelled'};
    current = {...card, 'selected': choice, 'status': 'saving'};
    if (fail) {
      fail = false;
      throw const AskRequestException('Retry this request.');
    }
    return delayed?.future ??
        {
          ...current,
          'status': 'confirmed',
          'receipt': {...choice!, 'photo_added': true},
        };
  }

  @override
  Future<Map<String, dynamic>> getChatPhotoAttachment(
    Map<String, dynamic> card,
  ) async => current;
}

void main() {
  Future<PhotoApi> mount(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
    double scale = 1,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = PhotoApi();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.create(brightness),
        home: RepaintBoundary(
          key: const ValueKey('photo-audit-frame'),
          child: MediaQuery(
            data: MediaQueryData(
              size: const Size(390, 844),
              textScaler: TextScaler.linear(scale),
            ),
            child: Scaffold(
              body: SafeArea(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ChatPhotoAttachmentCard(
                      api: api,
                      attachment: proposal(),
                      onChanged: (_) {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return api;
  }

  test('only complete attachment receipts parse as confirmed', () {
    expect(parsePhotoAttachment(proposal()), isNotNull);
    expect(
      parsePhotoAttachment({...proposal(), 'status': 'confirmed'}),
      isNull,
    );
    expect(parsePhotoAttachment({...proposal(), 'choices': []}), isNull);
  });
  for (final brightness in Brightness.values) {
    testWidgets(
      '${brightness.name} typo match needs exact location choice before attaching',
      (tester) async {
        final api = await mount(tester, brightness: brightness);
        expect(find.text('Did you mean…?'), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Attach photo'),
              )
              .onPressed,
          isNull,
        );
        await tester.tap(find.text('Lab / Parts / Shelf B'));
        await tester.pumpAndSettle();
        await photoAuditCapture?.call('${brightness.name}-choices');
        expect(api.sent, isEmpty);
        await tester.tap(find.text('Attach photo'));
        await tester.pumpAndSettle();
        expect(api.sent.single['choice']['item_id'], 'B');
        expect(find.text('Photo added'), findsOneWidget);
        expect(find.text('Arduino Uno · Shelf B'), findsOneWidget);
        await photoAuditCapture?.call('${brightness.name}-saved');
      },
    );
  }
  testWidgets(
    'failed response freezes target and safely retries the same photo card',
    (tester) async {
      final api = await mount(tester);
      api.fail = true;
      await tester.tap(find.text('Lab / Parts / Shelf A'));
      await tester.pump();
      await tester.tap(find.text('Attach photo'));
      await tester.pumpAndSettle();
      expect(find.text('Retry attachment'), findsOneWidget);
      expect(find.text('Cancel'), findsNothing);
      await tester.tap(find.text('Lab / Parts / Shelf B'));
      await tester.pump();
      await tester.tap(find.text('Retry attachment'));
      await tester.pumpAndSettle();
      expect(api.sent.every((r) => r['choice']['item_id'] == 'A'), isTrue);
      expect(find.text('Photo added'), findsOneWidget);
    },
  );
  testWidgets('cancel never selects or attaches an item', (tester) async {
    final api = await mount(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(api.sent.single, {'decision': 'cancel', 'choice': null});
    expect(find.text('Photo request cancelled'), findsOneWidget);
  });
  testWidgets('large text keeps choices and attachment controls reachable', (
    tester,
  ) async {
    await mount(tester, scale: 2.2, brightness: Brightness.dark);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Attach photo'));
    await photoAuditCapture?.call('large-text');
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'late response after leaving card does not update a disposed screen',
    (tester) async {
      final api = await mount(tester);
      api.delayed = Completer();
      await tester.tap(find.text('Lab / Parts / Shelf A'));
      await tester.pump();
      await tester.tap(find.text('Attach photo'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      api.delayed!.complete({
        ...proposal(),
        'status': 'confirmed',
        'receipt': {'photo_added': true},
      });
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
