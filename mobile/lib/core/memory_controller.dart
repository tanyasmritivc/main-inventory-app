import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'api_client.dart';
import 'api_error.dart';

/// No preference cache: the authenticated backend is authoritative on each load.
class MemoryController extends ChangeNotifier {
  MemoryController(this.api) : owner = api.accountId;
  final ApiClient api;
  final String? owner;
  Map<String, dynamic>? snapshot;
  List<Map<String, dynamic>> spaces = [];
  Map<String, dynamic>? pending;
  bool busy = false, _disposed = false;
  String? error, notice;
  String? get inventoryId => api.inventoryContext?.inventoryId;
  bool get current => !_disposed && owner != null && api.accountId == owner;
  bool get enabled => snapshot?['enabled'] == true;
  List<Map<String, dynamic>> get entries =>
      (snapshot?['entries'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
  String? preference(String key) {
    for (final row in entries) {
      if (row['key'] == key) return (row['payload'] as Map)['value'] as String?;
    }
    return null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _check() {
    if (!current) {
      snapshot = null;
      pending = null;
      spaces = [];
      throw const AskRequestException('Your account changed. Reopen Memory.');
    }
    try {
      api.assertCurrentContext();
    } catch (_) {
      snapshot = null;
      pending = null;
      spaces = [];
      rethrow;
    }
  }

  Future<void> load({bool afterSave = false, bool quiet = false}) async {
    if (busy && !afterSave) return;
    busy = true;
    error = null;
    if (!quiet) {
      snapshot = null;
      spaces = [];
    }
    _notify();
    try {
      _check();
      final result = await api.collaboration(
        '/memory',
        query: {if (inventoryId != null) 'inventory_id': inventoryId},
      );
      _check();
      if (result['revision'] is! int || result['entries'] is! List) {
        throw const FormatException('Memory is unavailable.');
      }
      snapshot = result;
      if (inventoryId != null) {
        spaces = await api.listSpaces();
        _check();
      }
    } catch (reason) {
      if (!_disposed) error = describeError(reason).$1;
    } finally {
      busy = false;
      _notify();
    }
  }

  String _operationId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final s = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
  }

  Future<void> change(Map<String, dynamic>? values) async {
    if (busy || (snapshot == null && pending == null)) return;
    if (values != null && (pending != null || snapshot == null)) return;
    busy = true;
    error = null;
    notice = null;
    if (values != null) {
      pending = {
        'operation_id': _operationId(),
        'expected_revision': snapshot!['revision'],
        ...values,
      };
    }
    _notify();
    try {
      _check();
      if (pending == null) return;
      final result = await api.collaboration(
        '/memory',
        method: 'POST',
        data: pending,
      );
      _check();
      if (result['saved'] != true) {
        throw const AskRequestException(
          'The save was not confirmed. Retry save.',
        );
      }
      pending = null;
      notice = 'Memory saved.';
      await load(afterSave: true);
    } catch (reason) {
      if (!_disposed) {
        if (reason is DioException &&
            [403, 409, 422].contains(reason.response?.statusCode)) {
          pending = null;
          error =
              'The preference could not be saved. Refresh and check your access.';
        } else {
          error = describeError(reason).$1;
        }
      }
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<String?> export() async {
    busy = true;
    error = null;
    _notify();
    try {
      _check();
      final result = await api.collaboration('/memory/export');
      _check();
      if (result['partial'] == true) {
        notice =
            'This export is partial because older memory exceeded the export limit.';
      }
      return const JsonEncoder.withIndent('  ').convert(result);
    } catch (reason) {
      if (!_disposed) error = describeError(reason).$1;
      return null;
    } finally {
      busy = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
