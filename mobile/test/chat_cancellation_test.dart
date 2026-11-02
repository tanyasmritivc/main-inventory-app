import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/ask_answer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'support/hierarchy_fixture.dart';

class _PendingClient extends http.BaseClient {
  final headers = Completer<http.StreamedResponse>();
  final started = Completer<void>();
  int closes = 0;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    started.complete();
    return headers.future;
  }

  @override
  void close() {
    closes++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fixture = HierarchyFixture();
  setUpAll(fixture.initialize);
  tearDownAll(() => Supabase.instance.dispose());
  setUp(() => fixture.signIn('actor-a'));
  for (final photo in [false, true]) {
    Stream<AiStreamEvent> events() => photo
        ? fixture.api.aiPhotoQuestionStream(
            message: 'What is this?',
            photo: AskPhoto(bytes: Uint8List.fromList([1, 2, 3])),
          )
        : fixture.api.aiCommandStream(message: 'Where is my lantern?');
    test(
      'cancel ${photo ? 'photo' : 'text'} before headers closes transport immediately',
      () async {
        final client = _PendingClient();
        await http.runWithClient(() async {
          final received = <AiStreamEvent>[];
          final errors = <Object>[];
          final subscription = events().listen(
            received.add,
            onError: errors.add,
          );
          await client.started.future;
          await subscription.cancel().timeout(const Duration(seconds: 1));
          expect(client.closes, 1);
          client.headers.complete(
            http.StreamedResponse(
              Stream.value(
                utf8.encode(
                  'data: {"type":"done","assistant_message":"late"}\n\n',
                ),
              ),
              200,
            ),
          );
          await Future<void>.delayed(Duration.zero);
          expect(received, isEmpty);
          expect(errors, isEmpty);
        }, () => client);
      },
    );
    test(
      'cancel ${photo ? 'photo' : 'text'} stream closes transport and ignores late events',
      () async {
        final client = _PendingClient();
        var canceled = false;
        final body = StreamController<List<int>>(
          onCancel: () {
            canceled = true;
          },
        );
        await http.runWithClient(() async {
          final first = Completer<void>();
          final received = <AiStreamEvent>[];
          final subscription = events().listen((e) {
            received.add(e);
            if (!first.isCompleted) first.complete();
          });
          await client.started.future;
          client.headers.complete(http.StreamedResponse(body.stream, 200));
          body.add(
            utf8.encode('data: {"type":"delta","delta":"Partial reply"}\n\n'),
          );
          await first.future;
          await subscription.cancel().timeout(const Duration(seconds: 1));
          expect(canceled, true);
          expect(client.closes, 1);
          body.add(
            utf8.encode('data: {"type":"done","assistant_message":"late"}\n\n'),
          );
          await body.close();
          expect(received.map((e) => e.delta), ['Partial reply']);
        }, () => client);
      },
    );
  }
  test(
    'completed response closes transport exactly once and preserves canonical answer',
    () async {
      final client = _PendingClient();
      await http.runWithClient(() async {
        final result = fixture.api.aiCommandStream(message: 'Where?').toList();
        await client.started.future;
        client.headers.complete(
          http.StreamedResponse(
            Stream.value(
              utf8.encode(
                'data: {"type":"done","assistant_message":"On the shelf","conversation_id":"chat"}\n\n',
              ),
            ),
            200,
          ),
        );
        expect((await result).single.assistantMessage, 'On the shelf');
        expect(client.closes, 1);
      }, () => client);
    },
  );
}
