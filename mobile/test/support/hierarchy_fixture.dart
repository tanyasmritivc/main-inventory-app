import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart' as dio;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/api_client.dart';

class HierarchyFixture implements dio.HttpClientAdapter {
  final requests = <dio.RequestOptions>[];
  late FutureOr<Object?> Function(dio.RequestOptions) respond;
  int status = 200;
  late ApiClient api;
  String account = 'actor-a';
  Future<void> initialize({bool mockPreferences = true}) async {
    if (mockPreferences) {
      SharedPreferences.setMockInitialValues({});
    }
    await Supabase.initialize(
      url: 'https://auth.test',
      publishableKey: 'test',
      authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/logout')) {
          return http.Response('{}', 200);
        }
        if (request.method == 'PUT' && request.url.path.endsWith('/user')) {
          return http.Response(
            jsonEncode({
              'id': account,
              'aud': 'authenticated',
              'role': 'authenticated',
              'email': '$account@example.test',
              'created_at': '2026-01-01T00:00:00Z',
              'app_metadata': {},
              'user_metadata': (jsonDecode(request.body) as Map)['data'] ?? {},
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        final token =
            '${base64Url.encode(utf8.encode('{"alg":"HS256"}'))}.${base64Url.encode(utf8.encode(jsonEncode({'sub': account, 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600})))}.signature';
        return http.Response(
          jsonEncode({
            'access_token': token,
            'refresh_token': 'test-refresh',
            'expires_in': 3600,
            'token_type': 'bearer',
            'user': {
              'id': account,
              'aud': 'authenticated',
              'role': 'authenticated',
              'email': '$account@example.test',
              'created_at': '2026-01-01T00:00:00Z',
              'app_metadata': {},
              'user_metadata': {},
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await signIn('actor-a');
    final client = dio.Dio(dio.BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = this;
    api = ApiClient(baseUrl: 'https://api.test', httpClient: client);
  }

  Future<void> signIn(String id) async {
    account = id;
    await Supabase.instance.client.auth.signInWithPassword(
      email: '$id@example.test',
      password: 'test-password',
    );
  }

  @override
  Future<dio.ResponseBody> fetch(
    dio.RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final result = await respond(options);
    return dio.ResponseBody.fromString(
      jsonEncode(result),
      status,
      headers: {
        dio.Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> inventory(
  String id, {
  String workspace = 'workspace-a',
  String organization = 'org-a',
  String role = 'editor',
  String? name,
}) => {
  'inventory_id': id,
  'name': name ?? id,
  'team_id': workspace == 'personal' ? null : workspace,
  'owner_user_id': 'owner',
  'role': role,
  'can_edit': ['owner', 'admin', 'editor'].contains(role),
  'can_manage': ['owner', 'admin'].contains(role),
  'can_rename': ['owner', 'admin'].contains(role),
  'workspace': {
    'workspace_id': workspace,
    'name': workspace,
    'organization_id': workspace == 'personal' ? null : organization,
    'organization_name': workspace == 'personal' ? null : organization,
    'role': role == 'owner' ? 'owner' : 'member',
  },
};
