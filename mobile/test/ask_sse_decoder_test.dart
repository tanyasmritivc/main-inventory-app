import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/chat/ask_event.dart';
import 'package:mobile/features/chat/ask_sse_decoder.dart';

void main() {
  test('decodes text content and terminal events', () async {
    final events = await _events(
      'data: {"content":"Hello"}\n\ndata: [DONE]\n\n',
    );
    expect(events.map((event) => event.type), [
      AskEventType.delta,
      AskEventType.done,
    ]);
    expect(events.first.message, 'Hello');
  });

  test('normalizes upload status and delta events', () async {
    final events = await _events(
      'data: {"type":"status","message":"Analyzing file..."}\n\n'
      'data: {"type":"delta","delta":"A summary"}\n\n'
      'data: {"type":"done","assistant_message":"A summary"}\n\n',
    );
    expect(events.map((event) => event.type), [
      AskEventType.status,
      AskEventType.delta,
      AskEventType.done,
    ]);
  });

  test('normalizes conversation and navigation events in order', () async {
    final events = await _events(
      'data: {"conversation_id":"conversation-1"}\n\n'
      'data: {"nav_hint":{"type":"item","id":"item-1"}}\n\n'
      'data: [DONE]\n\n',
    );
    expect(events.map((event) => event.type), [
      AskEventType.conversation,
      AskEventType.navigation,
      AskEventType.done,
    ]);
    expect(events[0].conversationId, 'conversation-1');
    expect(events[1].navigation?['id'], 'item-1');
  });

  test('preserves multiple events delivered in one network chunk', () async {
    final events = await _events(
      'data: {"content":"one"}\n\ndata: {"content":"two"}\n\n'
      'data: [DONE]\n\n',
    );
    expect(
      events
          .where((event) => event.type == AskEventType.delta)
          .map((event) => event.message),
      ['one', 'two'],
    );
  });

  test('reassembles partial chunks and split UTF-8 characters', () async {
    final bytes = utf8.encode(
      'data: {"content":"Find caf\u00e9 parts"}\n\ndata: [DONE]\n\n',
    );
    final marker = bytes.indexOf(0xc3);
    final chunks = <List<int>>[
      bytes.sublist(0, 7),
      bytes.sublist(7, marker + 1),
      bytes.sublist(marker + 1, bytes.length - 3),
      bytes.sublist(bytes.length - 3),
    ];
    final events = await normalizeAskEvents(
      Stream.fromIterable(chunks),
    ).toList();
    expect(events.first.message, 'Find caf\u00e9 parts');
    expect(events.last.type, AskEventType.done);
  });

  test(
    'reports malformed JSON without discarding the terminal event',
    () async {
      final events = await _events('data: {bad json}\n\ndata: [DONE]\n\n');
      expect(events.map((event) => event.type), [
        AskEventType.error,
        AskEventType.done,
      ]);
      expect(events.first.message, contains('malformed'));
    },
  );

  test('reports an empty data event', () async {
    final events = await _events('data:\n\ndata: [DONE]\n\n');
    expect(events.first.type, AskEventType.error);
    expect(events.first.message, contains('empty'));
  });

  test('reports an unexpected event without exposing its payload', () async {
    final events = await _events(
      'data: {"type":"tool","result":{"secret":"value"}}\n\n'
      'data: [DONE]\n\n',
    );
    expect(events.first.type, AskEventType.error);
    expect(events.first.message, isNot(contains('secret')));
  });

  test('normalizes backend error events', () async {
    final events = await _events(
      'data: {"error":"AI temporarily unavailable"}\n\n'
      'data: [DONE]\n\n',
    );
    expect(events.first.type, AskEventType.error);
    expect(
      events.first.message,
      'Ask FindEZ could not complete that request. Please try again.',
    );
  });

  test('reports an incomplete final SSE event and unexpected ending', () async {
    final events = await _events('data: {"content":"partial"}');
    expect(events.map((event) => event.type), [
      AskEventType.error,
      AskEventType.done,
    ]);
    expect(events.first.message, contains('final event'));
  });

  test('reports a clean stream that ends without a terminal event', () async {
    final events = await _events('data: {"content":"partial"}\n\n');
    expect(events.map((event) => event.type), [
      AskEventType.delta,
      AskEventType.error,
      AskEventType.done,
    ]);
  });
}

Future<List<AskEvent>> _events(String source) {
  return normalizeAskEvents(Stream.value(utf8.encode(source))).toList();
}
