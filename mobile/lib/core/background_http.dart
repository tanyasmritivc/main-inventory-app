import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// File-backed URLSession uploads keep the HTTP exchange owned by iOS while
/// Flutter is suspended. The same SSE decoder still owns application events.
@visibleForTesting
http.Client Function()? debugAssistantHttpClientFactory;

http.Client assistantHttpClient() {
  http.Client? testClient;
  assert(() {
    testClient = debugAssistantHttpClientFactory?.call();
    return true;
  }());
  return testClient ??
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
          ? BackgroundHttpClient()
          : http.Client());
}

class BackgroundHttpClient extends http.BaseClient {
  static const channel = MethodChannel('com.findez.app/assistant-network');
  static final _requests = <String, _PendingResponse>{};
  static int _sequence = 0;
  static bool _listening = false;
  final _owned = <String>{};
  bool _closed = false;

  static void _listen() {
    if (_listening) return;
    _listening = true;
    channel.setMethodCallHandler((call) async {
      if (call.method != 'event' || call.arguments is! Map) return;
      final event = Map<Object?, Object?>.from(call.arguments as Map);
      final id = event['id'];
      final pending = _requests[id];
      if (pending == null) return;
      switch (event['type']) {
        case 'headers':
          if (!pending.response.isCompleted) {
            pending.response.complete(
              http.StreamedResponse(
                pending.body.stream,
                event['status'] as int,
                headers: Map<String, String>.from(event['headers'] as Map),
                request: pending.request,
              ),
            );
          }
        case 'data':
          pending.body.add(List<int>.from(event['bytes'] as List));
        case 'done':
          _requests.remove(id);
          if (!pending.response.isCompleted) {
            pending.fail(http.ClientException('The response was interrupted.'));
          } else {
            unawaited(pending.body.close());
          }
        case 'error':
          _requests.remove(id);
          pending.fail(
            http.ClientException(
              'The connection was interrupted. Please try again.',
            ),
          );
      }
    });
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_closed) throw http.ClientException('Request cancelled.');
    _listen();
    final id = '${DateTime.now().microsecondsSinceEpoch}-${++_sequence}';
    final pending = _PendingResponse(request);
    _requests[id] = pending;
    _owned.add(id);
    pending.body.onCancel = () => _cancel(id);
    // Start observing the future before awaiting body serialization or native IO.
    final response = pending.response.future;
    unawaited(() async {
      try {
        final bytes = await request.finalize().toBytes();
        if (_closed || !_requests.containsKey(id)) return;
        await channel.invokeMethod<void>('start', {
          'id': id,
          'url': request.url.toString(),
          'method': request.method,
          'headers': request.headers,
          'body': bytes,
        });
      } catch (_) {
        if (_requests.remove(id) != null) {
          pending.fail(http.ClientException('The request could not start.'));
        }
      }
    }());
    return response;
  }

  void _cancel(String id) {
    _owned.remove(id);
    final pending = _requests.remove(id);
    if (pending == null) return;
    pending.fail(http.ClientException('Request cancelled.'));
    unawaited(
      channel.invokeMethod<void>('cancel', {'id': id}).catchError((_) {
        // A torn-down engine has no listener; native task cleanup also runs at launch.
      }),
    );
  }

  @override
  void close() {
    _closed = true;
    for (final id in _owned.toList()) {
      _cancel(id);
    }
    _owned.clear();
    super.close();
  }
}

class _PendingResponse {
  _PendingResponse(this.request);
  final http.BaseRequest request;
  final response = Completer<http.StreamedResponse>();
  final body = StreamController<List<int>>();
  void fail(Object error) {
    if (!response.isCompleted) {
      response.completeError(error);
    } else if (!body.isClosed) {
      body.addError(error);
    }
    if (!body.isClosed) unawaited(body.close());
  }
}
