import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'ask_event.dart';
import 'ask_sse_decoder.dart';

typedef AskTokenProvider = FutureOr<String?> Function();
typedef AskHttpClientFactory = http.Client Function();

abstract interface class AskGateway {
  Future<AskRequest> streamText({
    required String message,
    String? conversationId,
  });

  Future<AskRequest> streamFile({
    required String filename,
    required List<int> bytes,
    required String mimeType,
    String? conversationId,
  });
}

class AskRequest {
  AskRequest({required this.events, required Future<void> Function() cancel})
    : _cancel = cancel;

  final Stream<AskEvent> events;
  final Future<void> Function() _cancel;
  bool _cancelled = false;

  Future<void> cancel() async {
    if (_cancelled) return;
    _cancelled = true;
    await _cancel();
  }
}

class AskTransportException implements Exception {
  const AskTransportException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AskClient implements AskGateway {
  AskClient({
    required String baseUrl,
    AskTokenProvider? tokenProvider,
    AskHttpClientFactory? clientFactory,
    this.requestTimeout = const Duration(minutes: 2),
  }) : _baseUrl = baseUrl.endsWith('/')
           ? baseUrl.substring(0, baseUrl.length - 1)
           : baseUrl,
       _tokenProvider = tokenProvider ?? _supabaseToken,
       _clientFactory = clientFactory ?? http.Client.new;

  final String _baseUrl;
  final AskTokenProvider _tokenProvider;
  final AskHttpClientFactory _clientFactory;
  final Duration requestTimeout;

  static String? _supabaseToken() {
    return Supabase.instance.client.auth.currentSession?.accessToken;
  }

  @override
  Future<AskRequest> streamText({
    required String message,
    String? conversationId,
  }) async {
    final request = http.Request(
      'POST',
      Uri.parse('$_baseUrl/ai_command?stream=true'),
    );
    request.headers.addAll(await _headers(contentType: 'application/json'));
    request.body = json.encode(<String, dynamic>{
      'message': message,
      if (conversationId != null && conversationId.isNotEmpty)
        'conversation_id': conversationId,
    });
    return _send(request);
  }

  @override
  Future<AskRequest> streamFile({
    required String filename,
    required List<int> bytes,
    required String mimeType,
    String? conversationId,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/ai_upload'),
    );
    request.headers.addAll(await _headers());
    if (conversationId != null && conversationId.isNotEmpty) {
      request.fields['conversation_id'] = conversationId;
    }
    final parts = mimeType.split('/');
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
        contentType: parts.length == 2 ? MediaType(parts[0], parts[1]) : null,
      ),
    );
    return _send(request);
  }

  Future<Map<String, String>> _headers({String? contentType}) async {
    final token = await _tokenProvider();
    if (token == null || token.isEmpty) {
      throw const AskTransportException(
        'Session expired. Please sign in again.',
      );
    }
    return <String, String>{
      'Authorization': 'Bearer $token',
      'Accept': 'text/event-stream',
      if (contentType != null) 'Content-Type': contentType,
    };
  }

  Future<AskRequest> _send(http.BaseRequest request) async {
    final client = _clientFactory();
    http.StreamedResponse response;
    try {
      response = await client.send(request).timeout(requestTimeout);
    } on Object {
      client.close();
      throw const AskTransportException(
        'Ask FindEZ could not connect. Please try again.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      client.close();
      throw AskTransportException(_statusMessage(response.statusCode));
    }

    final events = () async* {
      try {
        yield* normalizeAskEvents(response.stream.timeout(requestTimeout));
      } on Object {
        yield const AskEvent.error(
          'Ask FindEZ lost the connection. Please try again.',
        );
        yield const AskEvent.done();
      } finally {
        client.close();
      }
    }();

    return AskRequest(
      events: events,
      cancel: () async {
        client.close();
      },
    );
  }

  String _statusMessage(int statusCode) {
    if (statusCode == 401) return 'Session expired. Please sign in again.';
    if (statusCode == 403) return 'Ask FindEZ is unavailable for this account.';
    if (statusCode == 429) {
      return 'Ask FindEZ is busy. Please try again shortly.';
    }
    return 'Ask FindEZ is temporarily unavailable. Please try again.';
  }
}
