import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/core/background_http.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const codec = StandardMethodCodec();
  final starts = <Map>[];
  final cancels = <String>[];
  Future<void> event(Map<String, Object?> value) async {
    final done = Completer<void>();
    binding.defaultBinaryMessenger.handlePlatformMessage(
      BackgroundHttpClient.channel.name,
      codec.encodeMethodCall(MethodCall('event', value)),
      (_) => done.complete(),
    );
    await done.future;
  }

  setUp(() {
    starts.clear();
    cancels.clear();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      BackgroundHttpClient.channel,
      (call) async {
        final args = call.arguments as Map;
        if (call.method == 'start') starts.add(args);
        if (call.method == 'cancel') cancels.add(args['id'] as String);
        return null;
      },
    );
  });
  tearDown(
    () => binding.defaultBinaryMessenger.setMockMethodCallHandler(
      BackgroundHttpClient.channel,
      null,
    ),
  );
  test(
    'native response preserves chunk ordering and exact scoped request',
    () async {
      final client = BackgroundHttpClient();
      final request =
          http.Request(
              'POST',
              Uri.parse('https://test.invalid/inventories/a/ai_command'),
            )
            ..headers['Authorization'] = 'Bearer fixture-only'
            ..body = '{"message":"fixture"}';
      final response = client.send(request);
      await Future<void>.delayed(Duration.zero);
      final id = starts.single['id'];
      expect(starts.single['url'], contains('/inventories/a/'));
      expect(starts.single['headers']['Authorization'], 'Bearer fixture-only');
      expect(starts.single['body'], request.bodyBytes);
      await event({
        'id': id,
        'type': 'headers',
        'status': 200,
        'headers': {'content-type': 'text/event-stream'},
      });
      final text = (await response).stream.bytesToString();
      await event({
        'id': id,
        'type': 'data',
        'bytes': Uint8List.fromList('one'.codeUnits),
      });
      // No Flutter lifecycle callback cancels a native-owned transfer.
      await event({
        'id': id,
        'type': 'data',
        'bytes': Uint8List.fromList('two'.codeUnits),
      });
      await event({'id': id, 'type': 'done'});
      expect(await text, 'onetwo');
      client.close();
      expect(cancels, isEmpty);
    },
  );
  test(
    'Stop cancels while waiting for headers; late completion is ignored',
    () async {
      final client = BackgroundHttpClient();
      final response = client.send(
        http.Request('POST', Uri.parse('https://test.invalid/ai_command')),
      );
      final failure = expectLater(
        response,
        throwsA(isA<http.ClientException>()),
      );
      await Future<void>.delayed(Duration.zero);
      final id = starts.single['id'];
      client.close();
      await failure;
      await Future<void>.delayed(Duration.zero);
      expect(cancels, [id]);
      await event({
        'id': id,
        'type': 'headers',
        'status': 200,
        'headers': <String, String>{},
      });
      await event({'id': id, 'type': 'done'});
    },
  );
  test('closing one account cannot cancel another request', () async {
    final a = BackgroundHttpClient(), b = BackgroundHttpClient();
    final failed = a.send(
      http.Request('POST', Uri.parse('https://test.invalid/ai_command')),
    );
    final failure = expectLater(failed, throwsA(isA<http.ClientException>()));
    final other = b.send(
      http.Request('POST', Uri.parse('https://test.invalid/ai_command')),
    );
    await Future<void>.delayed(Duration.zero);
    final id = starts.last['id'];
    a.close();
    await failure;
    await event({
      'id': id,
      'type': 'headers',
      'status': 403,
      'headers': <String, String>{},
    });
    expect((await other).statusCode, 403);
    await event({'id': id, 'type': 'done'});
    b.close();
    expect(cancels, [starts.first['id']]);
  });
}
