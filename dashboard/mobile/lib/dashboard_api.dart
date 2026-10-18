import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

typedef Json = Map<String, dynamic>;

class DashboardError implements Exception {
  final String message;
  final int? status;
  DashboardError(this.message, [this.status]);
  @override
  String toString() => message;
}

class SessionVault {
  static const channel = MethodChannel('com.findez.dashboard/session');
  Future<String?> read() => channel.invokeMethod<String>('read');
  Future<void> write(String value) => channel.invokeMethod('write', value);
  Future<void> clear() => channel.invokeMethod('clear');
  Future<bool> unlock() async =>
      await channel.invokeMethod<bool>('unlock') ?? false;
}

class DashboardApi extends ChangeNotifier {
  static const authBase = String.fromEnvironment('SUPABASE_URL');
  static const anon = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const base = String.fromEnvironment(
    'DASHBOARD_API_URL',
    defaultValue: 'https://findez.ai/api/founder/v1',
  );
  final http.Client client;
  final SessionVault vault;
  Json? session;
  Json? data;
  String? error;
  String? factor;
  String? challenge;
  bool loading = false;
  bool restoring = true;
  bool locked = false;
  bool emailCodePending = false;
  DateTime? lastSuccess;
  Future<void>? _refreshing;
  DashboardApi({http.Client? client, SessionVault? vault})
    : client = client ?? http.Client(),
      vault = vault ?? SessionVault();
  bool get signedIn => session != null && !locked && factor == null;
  bool get configured =>
      Uri.tryParse(authBase)?.scheme == 'https' &&
      anon.isNotEmpty &&
      Uri.tryParse(base)?.scheme == 'https';

  Future<Json> _request(
    String method,
    Uri url, {
    Json? body,
    bool auth = true,
  }) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (authBase.isNotEmpty && url.origin == Uri.parse(authBase).origin) {
      headers['apikey'] = anon;
    }
    if (auth && session != null) {
      headers['Authorization'] = 'Bearer ${session!['access_token']}';
    }
    try {
      final request = http.Request(method, url)..headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);
      final streamed = await client
          .send(request)
          .timeout(const Duration(seconds: 45));
      final response = await http.Response.fromStream(
        streamed,
      ).timeout(const Duration(seconds: 45));
      final decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
      if (response.statusCode >= 300) {
        final message = decoded is Map
            ? decoded['detail'] ??
                  decoded['msg'] ??
                  decoded['error_description']
            : null;
        throw DashboardError(
          message is String
              ? message
              : 'Could not complete this request. Please try again.',
          response.statusCode,
        );
      }
      return Map<String, dynamic>.from(decoded as Map);
    } on TimeoutException {
      throw DashboardError(
        'The connection took too long. Pull down to try again.',
      );
    } on http.ClientException {
      throw DashboardError(
        'Could not connect. Check your internet connection.',
      );
    } on FormatException {
      throw DashboardError(
        'The service returned an unexpected response. Please try again.',
      );
    }
  }

  Future<void> restore() async {
    try {
      if (configured) {
        final saved = await vault.read();
        if (saved != null && await vault.unlock()) {
          session = Map<String, dynamic>.from(jsonDecode(saved));
          await refresh();
        }
      }
    } catch (_) {
      error = 'Sign in to open your private dashboard.';
    } finally {
      restoring = false;
      notifyListeners();
    }
  }

  Future<void> signIn(String email, String password) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final value = await _request(
        'POST',
        Uri.parse('$authBase/auth/v1/token?grant_type=password'),
        body: {'email': email.trim(), 'password': password},
        auth: false,
      );
      await _establish(value);
    } catch (e) {
      error = e.toString();
      if (e is DashboardError && e.status == 403) {
        session = null;
        await vault.clear();
      }
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _establish(Json value) async {
    session = value;
    locked = false;
    emailCodePending = false;
    final factors = ((session!['user'] as Map?)?['factors'] as List? ?? [])
        .where((f) => f['status'] == 'verified' && f['factor_type'] == 'totp');
    if (factors.isNotEmpty) {
      factor = factors.first['id'];
      final response = await _request(
        'POST',
        Uri.parse('$authBase/auth/v1/factors/$factor/challenge'),
        body: {},
      );
      challenge = response['id'];
    } else {
      await vault.write(jsonEncode(session));
      await refresh();
    }
  }

  Future<void> requestEmailCode() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await _request(
        'POST',
        Uri.parse('$base/login/code'),
        body: {},
        auth: false,
      );
      emailCodePending = true;
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> verifyEmailCode(String email, String code) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final value = await _request(
        'POST',
        Uri.parse('$authBase/auth/v1/verify'),
        body: {'email': email.trim(), 'token': code.trim(), 'type': 'email'},
        auth: false,
      );
      await _establish(value);
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> verifyCode(String code) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      session = await _request(
        'POST',
        Uri.parse('$authBase/auth/v1/factors/$factor/verify'),
        body: {'challenge_id': challenge, 'code': code.trim()},
      );
      factor = null;
      challenge = null;
      await vault.write(jsonEncode(session));
      await refresh();
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _refreshToken() async {
    final expires = session?['expires_at'] as int? ?? 0;
    if (DateTime.now().millisecondsSinceEpoch ~/ 1000 < expires - 60) return;
    session = await _request(
      'POST',
      Uri.parse('$authBase/auth/v1/token?grant_type=refresh_token'),
      body: {'refresh_token': session!['refresh_token']},
      auth: false,
    );
    await vault.write(jsonEncode(session));
  }

  Future<void> refresh() {
    if (session == null || locked || factor != null) return Future.value();
    return _refreshing ??= _synchronize().whenComplete(
      () => _refreshing = null,
    );
  }

  Future<void> _synchronize() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await _refreshToken();
      final token = session?['access_token'];
      final snapshot = await _request('GET', Uri.parse('$base/snapshot'));
      if (session?['access_token'] != token) return;
      data = snapshot;
      lastSuccess = DateTime.tryParse(snapshot['at']?.toString() ?? '');
    } catch (e) {
      error = e.toString();
      if (e is DashboardError && (e.status == 401 || e.status == 403)) {
        session = null;
        data = null;
        await vault.clear();
      }
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> saveIssue({
    required String title,
    String description = '',
    String severity = 'warning',
    String kind = 'issue',
  }) async {
    await _refreshToken();
    await _request(
      'POST',
      Uri.parse('$base/issues'),
      body: {
        'title': title,
        'description': description,
        'severity': severity,
        'kind': kind,
      },
    );
    await refresh();
  }

  Future<void> updateIssue(String id, String status) async {
    await _refreshToken();
    await _request(
      'PATCH',
      Uri.parse('$base/issues/${Uri.encodeComponent(id)}'),
      body: {'status': status},
    );
    await refresh();
  }

  Future<void> signOut() async {
    try {
      if (session != null) {
        await _request(
          'POST',
          Uri.parse('$authBase/auth/v1/logout?scope=local'),
        );
      }
    } catch (_) {
      /* Local credentials must still be removed when offline. */
    }
    session = null;
    data = null;
    factor = null;
    challenge = null;
    error = null;
    locked = false;
    emailCodePending = false;
    lastSuccess = null;
    await vault.clear();
    notifyListeners();
  }

  Future<void> unlock() async {
    if (await vault.unlock()) {
      locked = false;
      notifyListeners();
      await refresh();
    }
  }

  void lock() {
    if (session != null) {
      locked = true;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    client.close();
    super.dispose();
  }
}
