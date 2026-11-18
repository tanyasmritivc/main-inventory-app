import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/ask_answer.dart';
import 'package:mobile/core/chat_source.dart';
import 'package:mobile/core/inventory_context.dart';
import 'support/hierarchy_fixture.dart';

const inventoryId = '11111111-1111-4111-8111-111111111111';
const spaceId = '22222222-2222-4222-8222-222222222222';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fixture = HierarchyFixture();
  setUpAll(fixture.initialize);
  tearDownAll(() => Supabase.instance.dispose());
  setUp(() async {
    await fixture.signIn('actor-a');
    fixture.requests.clear();
    fixture.status = 200;
  });
  ApiClient selected({
    bool Function()? current,
    String organization = 'org-a',
    bool personal = false,
  }) => ApiClient.forSpaceChat(
    ApiClient.forInventory(
      fixture.api,
      InventoryContext.fromJson(
        inventory(
          inventoryId,
          role: 'viewer',
          organization: organization,
          workspace: personal ? 'personal' : 'workspace-a',
        ),
        accountId: 'actor-a',
        expectedInventory: inventoryId,
      ),
      isCurrent: current ?? () => true,
    ),
    spaceId,
    'Hardware',
  );
  const source = ChatSource(
    kind: 'file',
    name: 'parts.csv',
    text: 'Name,Qty\nBolt,2',
  );
  final done =
      'data: ${jsonEncode({'type': 'done', 'assistant_message': 'A bolt.', 'conversation_id': 'chat'})}\n\n';
  test('Space text includes evidence and completes', () async {
    final sent = <http.Request>[];
    final events = await http.runWithClient(
      () => selected()
          .aiCommandStream(message: 'Are these here?', sources: [source])
          .toList(),
      () => MockClient((r) async {
        sent.add(r);
        return http.Response(done, 200);
      }),
    );
    expect(sent.single.url.path, '/worlds/org-a/ai_command');
    final body = jsonDecode(sent.single.body) as Map;
    expect(body['sources'], [source.toJson()]);
    expect(body.containsKey('supports_capture'), isFalse);
    expect(events.single.type, 'done');
  });
  test('Space photo is a question, never extraction', () async {
    final sent = <http.Request>[];
    await http.runWithClient(
      () => selected()
          .aiPhotoQuestionStream(
            message: 'Is this here?',
            photo: AskPhoto(bytes: Uint8List.fromList([1, 2, 3])),
            sources: [source],
          )
          .toList(),
      () => MockClient((r) async {
        sent.add(r);
        return http.Response(done, 200);
      }),
    );
    expect(sent.single.url.path, '/worlds/org-a/ai_photo_question');
    expect(sent.single.body, contains('parts.csv'));
    expect(sent.single.body, isNot(contains('auto_extract')));
    expect(sent.single.body, isNot(contains('supports_capture')));
  });
  test(
    'Viewer file parsing stays Space-bound while history uses its organization',
    () async {
      fixture.respond = (_) => {
        'kind': 'file',
        'name': 'parts.csv',
        'text': 'Bolt,2',
        'truncated': false,
      };
      final api = selected();
      expect((await api.readChatFile([1], 'parts.csv')).name, 'parts.csv');
      expect(
        fixture.requests.last.path,
        '/inventories/$inventoryId/space-chat/$spaceId/chat-files',
      );
      fixture.respond = (_) => [];
      await api.listConversations();
      expect(fixture.requests.last.path, '/worlds/org-a/conversations');
      fixture.respond = (_) => {'deleted': true};
      await api.deleteConversation('chat');
      expect(fixture.requests.last.path, '/worlds/org-a/conversations/chat');
    },
  );

  test(
    'Personal Space never expands to an organization or main personal chat',
    () {
      final api = selected(personal: true);
      expect(api.worldKey, isNull);
      expect(
        api.inventoryPath('/ai_command'),
        '/inventories/$inventoryId/space-chat/$spaceId/ai_command',
      );
      expect(api.contextualChatLabel, 'Only in Hardware');
    },
  );
  test('Different organizations keep distinct chat and history routes', () {
    final a = selected(), b = selected(organization: 'org-b');
    expect(a.inventoryPath('/ai_command'), '/worlds/org-a/ai_command');
    expect(b.inventoryPath('/conversations'), '/worlds/org-b/conversations');
    expect(a.contextualChatLabel, 'Across accessible Spaces in org-a');
    expect(b.contextualChatLabel, 'Across accessible Spaces in org-b');
    expect(a.inventoryPath('/items'), '/inventories/$inventoryId/items');
    expect(a.canEdit, isFalse);
  });
  test(
    'Account switch retires the organization Space client before sending',
    () async {
      final api = selected();
      await fixture.signIn('actor-b');
      var sent = false;
      await http.runWithClient(
        () async {
          await expectLater(
            api.aiCommandStream(message: 'Gears').toList(),
            throwsA(isA<Exception>()),
          );
        },
        () => MockClient((r) async {
          sent = true;
          return http.Response(done, 200);
        }),
      );
      expect(sent, isFalse);
    },
  );
  test(
    'Organization Space request preserves idempotency and sources',
    () async {
      late http.Request request;
      await http.runWithClient(
        () => selected()
            .aiCommandStream(
              message: 'Gears',
              requestId: 'turn-id',
              sources: [source],
            )
            .toList(),
        () => MockClient((r) async {
          request = r;
          return http.Response(done, 200);
        }),
      );
      final body = jsonDecode(request.body) as Map;
      expect(body['request_id'], 'turn-id');
      expect(body['sources'], [source.toJson()]);
      expect(body['supports_capture'], isNot(true));
    },
  );
  test('Stale inventory cannot send', () async {
    await expectLater(
      selected(
        current: () => false,
      ).aiCommandStream(message: 'Question').toList(),
      throwsA(isA<Exception>()),
    );
    expect(fixture.requests, isEmpty);
  });
}
