import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/features/chat/ask_client.dart';
import 'package:mobile/features/chat/ask_controller.dart';
import 'package:mobile/features/chat/ask_event.dart';

void main() {
  group('AskClient', () {
    test('sends authenticated text and normalizes the response', () async {
      late http.BaseRequest captured;
      final client = _RecordingClient((request) {
        captured = request;
        return _response(
          'data: {"conversation_id":"conversation-1"}\n\n'
          'data: {"content":"Found it"}\n\n'
          'data: [DONE]\n\n',
        );
      });
      final gateway = AskClient(
        baseUrl: 'https://api.findez.test/',
        tokenProvider: () => 'token-1',
        clientFactory: () => client,
      );

      final request = await gateway.streamText(message: 'Where is it?');
      final events = await request.events.toList();

      expect(
        captured.url.toString(),
        'https://api.findez.test/ai_command?stream=true',
      );
      expect(captured.headers['Authorization'], 'Bearer token-1');
      expect(captured.headers['Accept'], 'text/event-stream');
      expect(json.decode((captured as http.Request).body), {
        'message': 'Where is it?',
      });
      expect(events.map((event) => event.type), [
        AskEventType.conversation,
        AskEventType.delta,
        AskEventType.done,
      ]);
      expect(client.closed, isTrue);
    });

    test(
      'associates attachment requests with the active conversation',
      () async {
        late http.MultipartRequest captured;
        final client = _RecordingClient((request) {
          captured = request as http.MultipartRequest;
          return _response(
            'data: {"type":"done","conversation_id":"conversation-1"}\n\n',
          );
        });
        final gateway = AskClient(
          baseUrl: 'https://api.findez.test',
          tokenProvider: () => 'token-1',
          clientFactory: () => client,
        );

        final request = await gateway.streamFile(
          filename: 'manual.pdf',
          bytes: [1, 2, 3],
          mimeType: 'application/pdf',
          conversationId: 'conversation-1',
        );
        await request.events.toList();

        expect(captured.fields['conversation_id'], 'conversation-1');
        expect(captured.files.single.filename, 'manual.pdf');
        expect(captured.headers['Authorization'], 'Bearer token-1');
      },
    );

    test('cancellation closes the request client', () async {
      final client = _RecordingClient(
        (_) => http.StreamedResponse(const Stream<List<int>>.empty(), 200),
      );
      final gateway = AskClient(
        baseUrl: 'https://api.findez.test',
        tokenProvider: () => 'token-1',
        clientFactory: () => client,
      );
      final request = await gateway.streamText(message: 'Wait');

      await request.cancel();

      expect(client.closed, isTrue);
    });

    test('transport failures are not retried automatically', () async {
      var requestCount = 0;
      final client = _RecordingClient((_) {
        requestCount += 1;
        throw StateError('network down');
      });
      final gateway = AskClient(
        baseUrl: 'https://api.findez.test',
        tokenProvider: () => 'token-1',
        clientFactory: () => client,
      );

      await expectLater(
        gateway.streamText(message: 'Do not duplicate this'),
        throwsA(isA<AskTransportException>()),
      );

      expect(requestCount, 1);
      expect(client.closed, isTrue);
    });
  });

  group('AskController', () {
    test('owns conversation, status, navigation, and terminal state', () async {
      final events = Stream<AskEvent>.fromIterable(const [
        AskEvent.conversation('conversation-1'),
        AskEvent.status('Searching memory...'),
        AskEvent.delta('Cabinet A'),
        AskEvent.navigation({'type': 'space', 'id': 'space-1'}),
        AskEvent.done(),
      ]);
      final controller = AskController(
        gateway: _FakeGateway(() => _request(events)),
      );
      final received = <AskEvent>[];

      final outcome = await controller.sendText(
        message: 'Where is it?',
        onEvent: received.add,
      );

      expect(outcome, AskRunOutcome.completed);
      expect(controller.conversationId, 'conversation-1');
      expect(controller.pendingNavigation?['id'], 'space-1');
      expect(controller.isBusy, isFalse);
      expect(received.map((event) => event.type), [
        AskEventType.conversation,
        AskEventType.status,
        AskEventType.delta,
        AskEventType.navigation,
        AskEventType.done,
      ]);
    });

    test('surfaces protocol errors while preserving prior deltas', () async {
      final controller = AskController(
        gateway: _FakeGateway(
          () => _request(
            Stream<AskEvent>.fromIterable(const [
              AskEvent.delta('Partial answer'),
              AskEvent.error('The response ended unexpectedly.'),
              AskEvent.done(),
            ]),
          ),
        ),
      );
      final received = <AskEvent>[];

      final outcome = await controller.sendText(
        message: 'Question',
        onEvent: received.add,
      );

      expect(outcome, AskRunOutcome.failed);
      expect(received[0].message, 'Partial answer');
      expect(controller.errorMessage, 'The response ended unexpectedly.');
    });

    test('owns the canonical conversation message state', () {
      final sharedState = AskConversationState(
        messages: [
          AskMessage(role: 'user', content: 'Old question', timestamp: 1),
        ],
      );
      final controller = AskController(
        gateway: _FakeGateway(
          () => _request(Stream<AskEvent>.fromIterable(const [])),
        ),
        conversationState: sharedState,
      );

      controller.replaceMessages([
        AskMessage(role: 'user', content: 'Loaded question', timestamp: 2),
        AskMessage(role: 'assistant', content: 'Loaded answer', timestamp: 3),
      ]);

      expect(controller.hasStarted, isTrue);
      expect(controller.messages.map((message) => message.content), [
        'Loaded question',
        'Loaded answer',
      ]);

      controller.reset();
      expect(controller.messages, isEmpty);
      expect(controller.hasStarted, isFalse);
    });

    test('uses the server conversation id on the next question', () async {
      final gateway = _ConversationGateway();
      final controller = AskController(gateway: gateway);

      await controller.sendText(message: 'First', onEvent: (_) {});
      await controller.sendText(message: 'Follow up', onEvent: (_) {});

      expect(gateway.conversationIds, [null, 'conversation-1']);
    });

    test('cancels the active request without retrying it', () async {
      final stream = StreamController<AskEvent>();
      var cancelled = false;
      var requestCount = 0;
      final gateway = _FakeGateway(() {
        requestCount += 1;
        return AskRequest(
          events: stream.stream,
          cancel: () async => cancelled = true,
        );
      });
      final controller = AskController(gateway: gateway);
      final future = controller.sendText(message: 'Stop', onEvent: (_) {});
      await Future<void>.delayed(Duration.zero);

      await controller.cancelActive();
      final outcome = await future;

      expect(outcome, AskRunOutcome.cancelled);
      expect(cancelled, isTrue);
      expect(requestCount, 1);
      expect(controller.isBusy, isFalse);
      await stream.close();
    });
  });
}

AskRequest _request(Stream<AskEvent> events) {
  return AskRequest(events: events, cancel: () async {});
}

http.StreamedResponse _response(String body) {
  return http.StreamedResponse(Stream.value(utf8.encode(body)), 200);
}

class _FakeGateway implements AskGateway {
  _FakeGateway(this.create);

  final AskRequest Function() create;

  @override
  Future<AskRequest> streamText({
    required String message,
    String? conversationId,
  }) async => create();

  @override
  Future<AskRequest> streamFile({
    required String filename,
    required List<int> bytes,
    required String mimeType,
    String? conversationId,
  }) async => create();
}

class _RecordingClient extends http.BaseClient {
  _RecordingClient(this.handler);

  final http.StreamedResponse Function(http.BaseRequest request) handler;
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return handler(request);
  }

  @override
  void close() {
    closed = true;
    super.close();
  }
}

class _ConversationGateway implements AskGateway {
  final List<String?> conversationIds = [];

  @override
  Future<AskRequest> streamText({
    required String message,
    String? conversationId,
  }) async {
    conversationIds.add(conversationId);
    return _request(
      Stream<AskEvent>.fromIterable([
        if (conversationId == null)
          const AskEvent.conversation('conversation-1'),
        const AskEvent.done(),
      ]),
    );
  }

  @override
  Future<AskRequest> streamFile({
    required String filename,
    required List<int> bytes,
    required String mimeType,
    String? conversationId,
  }) {
    throw UnimplementedError();
  }
}
