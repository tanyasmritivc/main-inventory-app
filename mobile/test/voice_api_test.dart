import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart' as dio;
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/inventory_context.dart';
import 'support/hierarchy_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fixture = HierarchyFixture();
  setUpAll(fixture.initialize);
  tearDownAll(() => Supabase.instance.dispose());
  setUp(() async {
    await fixture.signIn('actor-a');
    fixture.requests.clear();
    fixture.status = 200;
    fixture.respond = (_) => {'text': ' Where are my screws? '};
  });
  test(
    'voice uses authenticated account route even in view-only inventories',
    () async {
      final api = ApiClient.forInventory(
        fixture.api,
        InventoryContext.fromJson(
          inventory('inventory-a', role: 'viewer'),
          accountId: 'actor-a',
          expectedInventory: 'inventory-a',
        ),
        isCurrent: () => true,
      );
      expect(
        await api.transcribeVoice(
          Uint8List(44),
          cancelToken: dio.CancelToken(),
        ),
        'Where are my screws?',
      );
      final request = fixture.requests.single;
      expect(request.path, '/voice/transcriptions');
      expect(request.headers['Authorization'], startsWith('Bearer '));
      final form = request.data as dio.FormData;
      expect(form.files.single.value.contentType.toString(), 'audio/wav');
      expect(form.files.single.value.filename, 'voice.wav');
      expect(form.fields, isEmpty);
    },
  );
  test('account change rejects a transcription already in flight', () async {
    final response = Completer<Object?>();
    fixture.respond = (_) => response.future;
    final future = fixture.api.transcribeVoice(
      Uint8List(44),
      cancelToken: dio.CancelToken(),
    );
    await Future<void>.delayed(Duration.zero);
    await fixture.signIn('actor-b');
    response.complete({'text': 'private old draft'});
    await expectLater(future, throwsA(anything));
  });
  test('cancellation rejects a late provider result', () async {
    final response = Completer<Object?>();
    fixture.respond = (_) => response.future;
    final token = dio.CancelToken();
    final future = fixture.api.transcribeVoice(
      Uint8List(44),
      cancelToken: token,
    );
    final assertion = expectLater(future, throwsA(isA<dio.DioException>()));
    await Future<void>.delayed(Duration.zero);
    token.cancel();
    response.complete({'text': 'late draft'});
    await assertion;
  });
  test('malformed transcription cannot populate a draft', () async {
    fixture.respond = (_) => {'text': 42};
    await expectLater(
      fixture.api.transcribeVoice(
        Uint8List(44),
        cancelToken: dio.CancelToken(),
      ),
      throwsFormatException,
    );
  });
}
