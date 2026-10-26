import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/ask_answer.dart' show trustedAskPhotoUrl;
import 'package:mobile/core/chat_item_action.dart';
import 'package:mobile/core/inventory_context.dart';
import 'support/hierarchy_fixture.dart';

const inventoryId = '11111111-1111-4111-8111-111111111111';
const actionId = '22222222-2222-4222-8222-222222222222';
Map<String, dynamic> payload([String status = 'pending']) => {
  'id': actionId,
  'inventory_id': inventoryId,
  'operation': 'add',
  'status': status,
  'items': [
    {'name': 'Bolt', 'quantity': 3, 'location': 'Garage'},
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fixture = HierarchyFixture();
  setUpAll(fixture.initialize);
  tearDownAll(() => Supabase.instance.dispose());
  setUp(() async {
    await fixture.signIn('actor-a');
    fixture.requests.clear();
    fixture.status = 200;
    fixture.respond = (_) => {'action': payload('confirmed')};
  });
  ApiClient selected({String role = 'editor', bool Function()? current}) =>
      ApiClient.forInventory(
        fixture.api,
        InventoryContext.fromJson(
          inventory(inventoryId, role: role),
          accountId: 'actor-a',
          expectedInventory: inventoryId,
        ),
        isCurrent: current ?? () => true,
      );
  test(
    'shared photo history stays bound to the selected inventory and origin',
    () {
      const owner = '33333333-3333-4333-8333-333333333333';
      final url =
          'https://storage.test/storage/v1/object/public/item-images/$owner/$inventoryId-${'a' * 32}-ask-${'b' * 32}.jpg';
      expect(
        trustedAskPhotoUrl(
          url,
          owner: 'actor-a',
          origins: ['https://storage.test'],
          inventoryId: inventoryId,
        ),
        url,
      );
      expect(
        trustedAskPhotoUrl(
          url,
          owner: 'actor-a',
          origins: ['https://storage.test'],
          inventoryId: owner,
        ),
        isNull,
      );
      expect(
        trustedAskPhotoUrl(
          url,
          owner: 'actor-a',
          origins: ['https://foreign.test'],
          inventoryId: inventoryId,
        ),
        isNull,
      );
    },
  );
  test(
    'confirmation sends only the decision within the selected inventory',
    () async {
      final result = await selected().decideChatItemAction(
        action: ChatItemAction.parse(payload())!,
        decision: 'confirm',
      );
      expect(result.action.status, 'confirmed');
      expect(
        fixture.requests.single.path,
        '/inventories/$inventoryId/ai_actions/$actionId',
      );
      expect(fixture.requests.single.data, {'decision': 'confirm'});
      expect(
        fixture.requests.single.headers['Authorization'],
        startsWith('Bearer '),
      );
    },
  );
  test('Viewer can cancel an old card but cannot confirm', () async {
    final api = selected(role: 'viewer');
    await expectLater(
      api.decideChatItemAction(
        action: ChatItemAction.parse(payload())!,
        decision: 'confirm',
      ),
      throwsA(isA<AskRequestException>()),
    );
    expect(fixture.requests, isEmpty);
    fixture.respond = (_) => {'action': payload('cancelled')};
    expect(
      (await api.decideChatItemAction(
        action: ChatItemAction.parse(payload())!,
        decision: 'cancel',
      )).action.status,
      'cancelled',
    );
  });
  test(
    'late response after inventory switch cannot enter the next chat',
    () async {
      var current = true;
      final response = Completer<Object?>();
      fixture.respond = (_) => response.future;
      final pending = selected(current: () => current).decideChatItemAction(
        action: ChatItemAction.parse(payload())!,
        decision: 'confirm',
      );
      await Future<void>.delayed(Duration.zero);
      current = false;
      response.complete({'action': payload('confirmed')});
      await expectLater(pending, throwsA(anything));
    },
  );
  test('a wrong action receipt never becomes success', () async {
    fixture.respond = (_) => {
      'action': {...payload('confirmed'), 'id': inventoryId},
    };
    await expectLater(
      selected().decideChatItemAction(
        action: ChatItemAction.parse(payload())!,
        decision: 'confirm',
      ),
      throwsA(isA<AskRequestException>()),
    );
  });
}
