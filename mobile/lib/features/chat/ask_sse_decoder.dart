import 'dart:async';
import 'dart:convert';

import 'ask_event.dart';

class SseFrame {
  const SseFrame({this.event, required this.data, this.isComplete = true});

  final String? event;
  final String data;
  final bool isComplete;
}

class AskSseDecoder {
  const AskSseDecoder();

  Stream<SseFrame> decode(Stream<List<int>> bytes) async* {
    var buffer = '';
    await for (final text in bytes.transform(utf8.decoder)) {
      buffer += text;
      while (true) {
        final delimiter = _nextDelimiter(buffer);
        if (delimiter == null) break;
        final block = buffer.substring(0, delimiter.index);
        buffer = buffer.substring(delimiter.index + delimiter.length);
        final frame = _parseBlock(block, isComplete: true);
        if (frame != null) yield frame;
      }
    }

    if (buffer.trim().isNotEmpty) {
      final frame = _parseBlock(buffer, isComplete: false);
      if (frame != null) yield frame;
    }
  }

  ({int index, int length})? _nextDelimiter(String value) {
    final lf = value.indexOf('\n\n');
    final crlf = value.indexOf('\r\n\r\n');
    if (lf < 0 && crlf < 0) return null;
    if (lf < 0) return (index: crlf, length: 4);
    if (crlf < 0) return (index: lf, length: 2);
    return lf < crlf ? (index: lf, length: 2) : (index: crlf, length: 4);
  }

  SseFrame? _parseBlock(String block, {required bool isComplete}) {
    String? event;
    final data = <String>[];
    for (final line in block.split(RegExp(r'\r?\n'))) {
      if (line.isEmpty || line.startsWith(':')) continue;
      final separator = line.indexOf(':');
      final field = separator < 0 ? line : line.substring(0, separator);
      var value = separator < 0 ? '' : line.substring(separator + 1);
      if (value.startsWith(' ')) value = value.substring(1);
      switch (field) {
        case 'event':
          event = value;
        case 'data':
          data.add(value);
      }
    }
    if (data.isEmpty) return null;
    return SseFrame(
      event: event,
      data: data.join('\n'),
      isComplete: isComplete,
    );
  }
}

class AskEventAdapter {
  const AskEventAdapter();

  Iterable<AskEvent> adapt(SseFrame frame) sync* {
    if (!frame.isComplete) {
      yield const AskEvent.error(
        'The response ended before the final event was complete.',
      );
      return;
    }

    final raw = frame.data.trim();
    if (raw.isEmpty) {
      yield const AskEvent.error('The response contained an empty event.');
      return;
    }
    if (raw == '[DONE]') {
      yield const AskEvent.done();
      return;
    }

    Object? decoded;
    try {
      decoded = json.decode(raw);
    } on FormatException {
      yield const AskEvent.error('The response contained malformed data.');
      return;
    }
    if (decoded is! Map) {
      yield const AskEvent.error('The response contained an unexpected event.');
      return;
    }

    final payload = decoded.cast<String, dynamic>();
    final type = payload['type']?.toString();
    var recognized = false;

    final error = payload['error']?.toString().trim() ?? '';
    if (error.isNotEmpty) {
      recognized = true;
      yield const AskEvent.error(
        'Ask FindEZ could not complete that request. Please try again.',
      );
    }

    final conversationId = payload['conversation_id']?.toString().trim() ?? '';
    if (conversationId.isNotEmpty) {
      recognized = true;
      yield AskEvent.conversation(conversationId);
    }

    if (type == 'status') {
      recognized = true;
      final message = payload['message']?.toString().trim() ?? '';
      if (message.isNotEmpty) yield AskEvent.status(message);
    }

    final content = type == 'delta'
        ? payload['delta']?.toString() ?? ''
        : payload['content']?.toString() ?? '';
    if (content.isNotEmpty) {
      recognized = true;
      yield AskEvent.delta(content);
    }

    final navigation = payload['nav_hint'];
    if (navigation is Map) {
      recognized = true;
      yield AskEvent.navigation(navigation.cast<String, dynamic>());
    }

    if (type == 'done') {
      recognized = true;
      yield const AskEvent.done();
    }

    if (!recognized) {
      yield const AskEvent.error('The response contained an unexpected event.');
    }
  }
}

Stream<AskEvent> normalizeAskEvents(
  Stream<List<int>> bytes, {
  AskSseDecoder decoder = const AskSseDecoder(),
  AskEventAdapter adapter = const AskEventAdapter(),
}) async* {
  var terminalSeen = false;
  var errorSeen = false;
  try {
    await for (final frame in decoder.decode(bytes)) {
      for (final event in adapter.adapt(frame)) {
        yield event;
        if (event.type == AskEventType.error) {
          errorSeen = true;
        }
        if (event.type == AskEventType.done) {
          terminalSeen = true;
          return;
        }
      }
    }
  } on Object {
    errorSeen = true;
    yield const AskEvent.error('The response stream could not be decoded.');
  }

  if (!terminalSeen) {
    if (!errorSeen) {
      yield const AskEvent.error('The response ended unexpectedly.');
    }
    yield const AskEvent.done();
  }
}
