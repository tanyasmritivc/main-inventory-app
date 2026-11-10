import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api_client.dart';

/// Reject incomplete responses instead of rendering unverified allowances.
Map<String, dynamic> verifiedAnnouncementAccess(dynamic value) {
  if (value is! Map ||
      value['name'] is! String ||
      (value['name'] as String).trim().isEmpty ||
      value['pilot'] is! bool ||
      value['fine'] is! String ||
      value['rows'] is! List ||
      (value['rows'] as List).isEmpty ||
      !(value['rows'] as List).every(
        (row) =>
            row is Map &&
            row['label'] is String &&
            row['now'] is String &&
            row['free'] is String,
      )) {
    throw const FormatException('Access details are unavailable.');
  }
  return Map<String, dynamic>.from(value);
}

Future<Map<String, dynamic>> loadAnnouncementAccess(ApiClient api) async =>
    verifiedAnnouncementAccess(
      await api.collaboration('/announcements/access'),
    );

String _sessionId() {
  final r = Random.secure();
  final b = List.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 15) | 64;
  b[8] = (b[8] & 63) | 128;
  final h = b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

/// Server claims are the authority. Local storage is only an account-bound write
/// outbox, never a second eligibility store. A lost receipt cannot repeat a claim.
class AnnouncementController extends ChangeNotifier {
  AnnouncementController({
    required this.api,
    required this.accountId,
    required this.isCurrent,
    required this.platform,
    this.welcomeAfterSignIn = false,
  });
  final ApiClient api;
  final String accountId, platform;
  final bool welcomeAfterSignIn;
  final bool Function() isCurrent;
  final sessionId = _sessionId();
  bool attempted = false, presented = false, _disposed = false;
  Map<String, dynamic>? campaign, access;
  String get _outboxKey => 'announcement_receipts:$accountId';
  bool get current => !_disposed && isCurrent();
  Future<void>? _flushing;
  DateTime? _retryAfter;

  Future<void> loadAccess() async {
    final result = await loadAnnouncementAccess(api);
    if (!current) return;
    access = result;
    notifyListeners();
  }

  Future<void> evaluate() async {
    if (!current ||
        attempted ||
        (_retryAfter?.isAfter(DateTime.now()) ?? false)) {
      return;
    }
    attempted = true;
    if (welcomeAfterSignIn) {
      // This is an account welcome, not a repeat claim for a server campaign.
      // Never invent access: render only freshly verified account entitlements.
      try {
        final verified = await loadAnnouncementAccess(api);
        if (!current) return;
        access = verified;
        if (verified['pilot'] == true) {
          campaign = {
            'id': 'sign-in-welcome',
            'session_welcome': true,
            'design': 'access',
            'title': 'Founders Access',
            'action': 'dismiss',
          };
        }
        notifyListeners();
      } catch (_) {
        attempted = false;
        _retryAfter = DateTime.now().add(const Duration(seconds: 15));
        rethrow;
      }
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    if (!current) return;
    await flush();
    if (!current) return;
    final result = await api.collaboration(
      '/announcements/claim',
      method: 'POST',
      data: {
        'session_id': sessionId,
        'platform': platform,
        'client_revision': 1,
        'legacy_seen':
            prefs.getString('findez_plan_intro_v1:$accountId') == 'dismissed',
      },
    );
    if (!current) return;
    access = verifiedAnnouncementAccess(result['access']);
    final value = result['campaign'];
    if (value is Map) {
      final candidate = Map<String, dynamic>.from(value);
      final expiry = DateTime.tryParse(
        candidate['expires_at']?.toString() ?? '',
      );
      if ([
            'access',
            'pricing',
            'whats_new',
            'message',
          ].contains(candidate['design']) &&
          ['dismiss', 'capture'].contains(candidate['action']) &&
          (expiry == null || expiry.isAfter(DateTime.now()))) {
        campaign = candidate;
      }
    }
    notifyListeners();
  }

  Future<bool> record(String campaignId, String event) async {
    if (!current) return false;
    final prefs = await SharedPreferences.getInstance();
    if (!current) return false;
    final queue = prefs.getStringList(_outboxKey) ?? [];
    final entry = jsonEncode({'id': campaignId, 'event': event});
    if (!queue.contains(entry)) queue.add(entry);
    if (!await prefs.setStringList(_outboxKey, queue)) {
      throw StateError('Could not save announcement preference.');
    }
    await flush();
    return !(prefs.getStringList(_outboxKey) ?? []).contains(entry);
  }

  Future<void> flush() =>
      _flushing ??= _flush().whenComplete(() => _flushing = null);
  Future<void> _flush() async {
    final prefs = await SharedPreferences.getInstance();
    while (current) {
      final entries = prefs.getStringList(_outboxKey) ?? [];
      if (entries.isEmpty) return;
      final entry = entries.first;
      final data = jsonDecode(entry) as Map;
      try {
        await api.collaboration(
          '/announcements/${Uri.encodeComponent(data['id'] as String)}/receipt',
          method: 'POST',
          data: {'event': data['event']},
        );
      } catch (_) {
        // Durable retry receipt remains queued; claim already prevents replay.
        return;
      }
      if (!current) return;
      final remaining = prefs.getStringList(_outboxKey) ?? [];
      remaining.remove(entry);
      await prefs.setStringList(_outboxKey, remaining);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
