import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart' as dio;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/features/scan/review_capture.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CaptureAdapter implements dio.HttpClientAdapter {
  final requests = <dio.RequestOptions>[];
  final preview = <String, dynamic>{
    'name': 'Unidentified item',
    'category': 'Other',
    'quantity': 1,
    'review_id': 'preview-1',
    'review_status': 'preview',
    'review_token': 'signed-preview',
    'scan_evidence': {'needs_review': true},
  };

  @override
  Future<dio.ResponseBody> fetch(
    dio.RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final result = options.path == '/inventory/bulk_create'
        ? {
            'inserted': [],
            'accepted_indices': [],
            'failures': [
              {'index': 0},
            ],
          }
        : options.path == '/inventory/extract_from_image'
        ? {
            'items': [preview],
            'summary': {'total_detected': 1, 'categories': {}},
          }
        : {
            'review_item': {
              ...preview,
              'review_id': 'saved-1',
              'status': 'pending',
            },
          };
    return dio.ResponseBody.fromString(
      jsonEncode(result),
      200,
      headers: {
        dio.Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final user = {
      'id': 'user-1',
      'aud': 'authenticated',
      'role': 'authenticated',
      'email': 'test@example.test',
      'created_at': '2026-01-01T00:00:00Z',
      'app_metadata': {},
      'user_metadata': {},
    };
    final token =
        '${base64Url.encode(utf8.encode('{"alg":"HS256"}'))}.${base64Url.encode(utf8.encode(jsonEncode({'sub': 'user-1', 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600})))}.signature';
    await Supabase.initialize(
      url: 'https://auth.test',
      publishableKey: 'test',
      authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode({
            'access_token': token,
            'refresh_token': 'test-refresh',
            'expires_in': 3600,
            'token_type': 'bearer',
            'user': user,
          }),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    await Supabase.instance.client.auth.signInWithPassword(
      email: 'test@example.test',
      password: 'test-password',
    );
  });
  tearDownAll(() => Supabase.instance.dispose());

  test('cancelled extraction does not upload a photo', () async {
    final adapter = CaptureAdapter();
    final client = dio.Dio(dio.BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = adapter;
    final api = ApiClient(baseUrl: 'https://api.test', httpClient: client);
    final token = dio.CancelToken()..cancel();
    await expectLater(
      api.extractInventoryFromImage(
        bytes: [1, 2, 3],
        filename: 'photo.jpg',
        cancelToken: token,
      ),
      throwsA(
        isA<dio.DioException>().having(
          (error) => error.type,
          'type',
          dio.DioExceptionType.cancel,
        ),
      ),
    );
    expect(adapter.requests, isEmpty);
  });

  test('upload is a preview and only Save creates the signed review', () async {
    final adapter = CaptureAdapter();
    final client = dio.Dio(dio.BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = adapter;
    final api = ApiClient(baseUrl: 'https://api.test', httpClient: client);
    final cancelToken = dio.CancelToken();
    final result = await api.extractInventoryFromImage(
      cancelToken: cancelToken,
      bytes: [1, 2, 3],
      filename: 'photo.jpg',
    );
    expect(adapter.requests, hasLength(1));
    expect(adapter.requests.single.cancelToken, same(cancelToken));
    expect(
      (adapter.requests.single.data as dio.FormData).fields
          .firstWhere((field) => field.key == 'preview_only')
          .value,
      'true',
    );
    expect(result.items.single.reviewStatus, 'preview');
    expect(result.items.single.reviewToken, 'signed-preview');
    final plan = await prepareCaptureForSave(api: api, items: result.items);
    expect(plan.reviewCount, 1);
    expect(plan.inventoryItems, isEmpty);
    expect(adapter.requests, hasLength(2));
    expect(adapter.requests.last.path, '/review-items/preview-1');
    expect(adapter.requests.last.method, 'POST');
    expect(adapter.requests.last.data['review_token'], 'signed-preview');
    expect(
      adapter.requests.last.headers['Authorization'],
      startsWith('Bearer '),
    );

    final old = ExtractedInventoryItem.fromJson({
      ...adapter.preview,
      'review_status': 'pending',
    });
    await api.updateReviewItem(reviewId: 'saved-1', item: old);
    expect(adapter.requests.last.method, 'PATCH');
    expect(adapter.requests.last.data.containsKey('review_token'), isFalse);
    final receipt = await api.bulkCreateInventory(
      items: [old],
      requestIds: ['stable-capture-1'],
    );
    expect(
      adapter.requests.last.data['items'][0]['client_request_id'],
      'stable-capture-1',
    );
    expect(
      adapter.requests.last.headers['Authorization'],
      startsWith('Bearer '),
    );
    expect(receipt.confirmedIndices(1), isEmpty);
    client.close();
  });
}
