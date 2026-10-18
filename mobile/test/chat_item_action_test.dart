import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/core/ask_answer.dart';
import 'package:mobile/core/chat_item_action.dart';
import 'package:mobile/core/ui/app_typography.dart';
import 'package:mobile/features/chat/chat_item_action_card.dart';

const inventoryId = '11111111-1111-4111-8111-111111111111';
const actionId = '22222222-2222-4222-8222-222222222222';
Map<String, dynamic> payload({
  String operation = 'add',
  String status = 'pending',
}) => {
  'id': actionId,
  'inventory_id': inventoryId,
  'operation': operation,
  'status': status,
  'items': [
    {'name': 'Bolt', 'quantity': 3, 'location': 'Garage'},
  ],
};

class ActionApi extends ApiClient {
  ActionApi({this.editable = true, this.pending})
    : super(baseUrl: 'https://api.test');
  final bool editable;
  final Completer<ChatItemActionResult>? pending;
  final decisions = <String>[];
  final ids = <String>[];
  @override
  bool get canEdit => editable;
  @override
  Future<ChatItemActionResult> decideChatItemAction({
    required ChatItemAction action,
    required String decision,
    dio.CancelToken? cancelToken,
  }) async {
    decisions.add(decision);
    ids.add(action.id);
    if (pending != null) return pending!.future;
    return ChatItemActionResult(
      action: ChatItemAction.parse(
        payload(
          operation: action.operation,
          status: decision == 'confirm' ? 'confirmed' : 'cancelled',
        ),
      )!,
      assistantMessage: decision == 'confirm'
          ? 'Added 3 bolts in Garage.'
          : null,
      replyId: 'reply',
    );
  }
}

Widget page(
  ActionApi api,
  Brightness brightness, {
  String operation = 'add',
  ValueChanged<ChatItemActionResult>? onResult,
  double scale = 1,
}) => MaterialApp(
  theme: const bool.fromEnvironment('FINDEZ_VISUAL_QA')
      ? AppTheme.create(brightness).copyWith(
          textTheme: AppTheme.create(
            brightness,
          ).textTheme.apply(fontFamily: 'FindEZQA'),
          textButtonTheme: TextButtonThemeData(
            style: AppTheme.create(brightness).textButtonTheme.style?.copyWith(
              textStyle: const WidgetStatePropertyAll(
                TextStyle(fontFamily: 'FindEZQA'),
              ),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: AppTheme.create(brightness).filledButtonTheme.style
                ?.copyWith(
                  textStyle: const WidgetStatePropertyAll(
                    TextStyle(fontFamily: 'FindEZQA'),
                  ),
                ),
          ),
        )
      : AppTheme.create(brightness),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: AppTypography(child: child!),
  ),
  home: Scaffold(
    body: RepaintBoundary(
      key: const ValueKey('action-qa'),
      child: SingleChildScrollView(
        child: ChatItemActionCard(
          api: api,
          action: ChatItemAction.parse(payload(operation: operation))!,
          onResult: onResult,
        ),
      ),
    ),
  ),
);
void main() {
  setUpAll(() async {
    if (const bool.fromEnvironment('FINDEZ_VISUAL_QA')) {
      await (FontLoader('FindEZQA')..addFont(
            File(
              '/System/Library/Fonts/SFNS.ttf',
            ).readAsBytes().then(ByteData.sublistView),
          ))
          .load();
    }
  });
  test('malformed action data never becomes a confirmation card', () {
    for (final value in [
      null,
      {},
      {...payload(), 'id': 'bad'},
      {...payload(), 'operation': 'delete_organization'},
      {
        ...payload(),
        'items': [
          {'name': 'Bolt', 'quantity': -1, 'location': 'Garage'},
        ],
      },
    ]) {
      expect(ChatItemAction.parse(value), isNull);
    }
    expect(
      AskAnswerContext.fromJson({
        'pending_actions': 'malformed',
      }).pendingActions,
      isEmpty,
    );
  });
  for (final brightness in Brightness.values) {
    testWidgets(
      '${brightness.name} additions wait for review and deliver the actual reply',
      (tester) async {
        final api = ActionApi();
        final replies = <ChatItemActionResult>[];
        if (const bool.fromEnvironment('FINDEZ_VISUAL_QA')) {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
        }
        await tester.pumpWidget(page(api, brightness, onResult: replies.add));
        if (const bool.fromEnvironment('FINDEZ_VISUAL_QA')) {
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const ValueKey('action-qa')),
            );
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '/private/tmp/findez-chat-action-${brightness.name}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        expect(api.decisions, isEmpty);
        expect(find.text('Qty 3 · Garage'), findsOneWidget);
        await tester.tap(find.text('Confirm additions'));
        await tester.pumpAndSettle();
        expect(api.decisions, ['confirm']);
        expect(api.ids, [actionId]);
        expect(find.text('Change confirmed'), findsOneWidget);
        expect(find.text('Confirm additions'), findsNothing);
        expect(replies.single.assistantMessage, 'Added 3 bolts in Garage.');
        await tester.pumpWidget(const SizedBox());
      },
    );
    testWidgets(
      '${brightness.name} deletion requires a separate confirmation and Cancel writes nothing',
      (tester) async {
        final api = ActionApi();
        await tester.pumpWidget(page(api, brightness, operation: 'delete'));
        await tester.tap(find.text('Review deletion'));
        await tester.pumpAndSettle();
        expect(find.text('Delete 1 item?'), findsOneWidget);
        expect(api.decisions, isEmpty);
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Cancel'),
          ),
        );
        await tester.pumpAndSettle();
        expect(api.decisions, isEmpty);
        await tester.tap(find.text('Review deletion'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete items'));
        await tester.pumpAndSettle();
        expect(api.decisions, ['confirm']);
        expect(find.text('Change confirmed'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      },
    );
    testWidgets(
      '${brightness.name} Viewer cannot confirm and large text stays usable',
      (tester) async {
        tester.view.physicalSize = const Size(320, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final api = ActionApi(editable: false);
        await tester.pumpWidget(page(api, brightness, scale: 2.6));
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );
        await tester.ensureVisible(find.text('Cancel'));
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(api.decisions, ['cancel']);
        expect(find.text('Cancelled'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
