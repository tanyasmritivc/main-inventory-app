import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'account_preferences.dart';

/// Personal purchase planning. Inventory counts are always server-confirmed.
class RestockEntry {
  const RestockEntry({
    this.minimum,
    this.buyQuantity,
    this.ordered = false,
    this.orderQuantity,
    this.receiptTotal,
  });

  final int? minimum, buyQuantity, orderQuantity, receiptTotal;
  final bool ordered;

  bool get isEmpty =>
      minimum == null &&
      buyQuantity == null &&
      !ordered &&
      receiptTotal == null;
  bool needsBuying(int quantity) =>
      !ordered &&
      receiptTotal == null &&
      (buyQuantity != null || (minimum != null && quantity <= minimum!));
  int quantityToBuy(int quantity) =>
      buyQuantity ?? (((minimum ?? 0) + 1) - quantity).clamp(1, 100000);

  Map<String, Object?> toJson() => {
    if (minimum != null) 'minimum': minimum,
    if (buyQuantity != null) 'buy_quantity': buyQuantity,
    if (ordered) 'ordered': true,
    if (orderQuantity != null) 'order_quantity': orderQuantity,
    if (receiptTotal != null) 'receipt_total': receiptTotal,
  };

  factory RestockEntry.fromJson(Map<String, dynamic> json) {
    int? count(String key, {int lower = 0}) {
      final raw = json[key];
      if (raw == null) return null;
      final n = raw is int ? raw : int.tryParse('$raw');
      if (n == null || n < lower) {
        throw FormatException('Invalid restock count: $key');
      }
      return n;
    }

    if (json['ordered'] != null && json['ordered'] is! bool) {
      throw const FormatException('Invalid order status');
    }

    return RestockEntry(
      minimum: count('minimum'),
      buyQuantity: count('buy_quantity', lower: 1),
      ordered: json['ordered'] == true,
      orderQuantity: count('order_quantity', lower: 1),
      receiptTotal: count('receipt_total'),
    );
  }
}

class RestockPlan {
  const RestockPlan(this.entries);
  final Map<String, RestockEntry> entries;
  RestockEntry entry(String id) => entries[id] ?? const RestockEntry();
  bool needsBuying(String id, int quantity) => entry(id).needsBuying(quantity);
  bool onOrder(String id) =>
      entry(id).ordered || entry(id).receiptTotal != null;
  Map<String, int> get thresholds => {
    for (final e in entries.entries)
      if (e.value.minimum != null) e.key: e.value.minimum!,
  };
}

class RestockPrefs {
  static const _key = 'restock_plan_v1';
  static const _thresholdKey = 'low_stock_thresholds';
  static const _checkedKey = 'shopping_list_checked';
  static Completer<void>? _pending;
  static final changes = ValueNotifier<int>(0);

  static String get accountKey => accountPreferenceKey(_key);

  // Serialize reads/migrations/writes so concurrent item changes never overwrite
  // one another. Capture the account before any asynchronous operation.
  static Future<T> _serial<T>(Future<T> Function() operation) {
    final previous = _pending;
    final gate = Completer<void>();
    _pending = gate;
    return () async {
      if (previous != null) await previous.future;
      try {
        return await operation();
      } finally {
        if (identical(_pending, gate)) _pending = null;
        gate.complete();
      }
    }();
  }

  static void _guard(String key) {
    if (accountKey != key) {
      throw StateError('Account changed. Reopen the restock planner.');
    }
  }

  static Future<void> _write(
    SharedPreferences prefs,
    String key,
    Map<String, RestockEntry> entries,
  ) async {
    _guard(key);
    final previous = prefs.getString(key);
    try {
      final ok = await prefs.setString(
        key,
        jsonEncode({
          for (final e in entries.entries)
            if (!e.value.isEmpty) e.key: e.value.toJson(),
        }),
      );
      if (!ok) throw StateError('Could not save the restock plan.');
    } catch (_) {
      // SharedPreferences changes its cache before platform confirmation.
      // Restore that cache so a failed save is not displayed as successful.
      try {
        if (previous == null) {
          await prefs.remove(key);
        } else {
          await prefs.setString(key, previous);
        }
      } catch (_) {
        // The original write failure is still raised below.
      }
      rethrow;
    }
    _guard(key);
    changes.value++;
  }

  static Future<RestockPlan> _read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    _guard(key);
    final raw = prefs.getString(key);
    if (raw != null) {
      // Do not silently replace a damaged saved purchase plan with an empty one.
      final decoded = jsonDecode(raw);
      if (decoded is! Map) throw const FormatException('Invalid restock plan');
      if (decoded.values.any((value) => value is! Map)) {
        throw const FormatException('Invalid restock entry');
      }
      return RestockPlan({
        for (final e in decoded.entries)
          if (e.value is Map)
            e.key.toString(): RestockEntry.fromJson(
              Map<String, dynamic>.from(e.value as Map),
            ),
      });
    }
    final suffix = key.substring(_key.length);
    final thresholdsKey = '$_thresholdKey$suffix';
    final checkedKey = '$_checkedKey$suffix';
    final signedIn = suffix != ':signed-out';
    final thresholdRaw =
        prefs.getString(thresholdsKey) ??
        (signedIn ? prefs.getString(_thresholdKey) : null);
    final checked =
        prefs.getStringList(checkedKey) ??
        (signedIn ? prefs.getStringList(_checkedKey) : null);
    final entries = <String, RestockEntry>{};
    if (thresholdRaw != null) {
      final decoded = jsonDecode(thresholdRaw);
      if (decoded is! Map) {
        throw const FormatException('Invalid stock thresholds');
      }
      for (final e in decoded.entries) {
        final n = int.tryParse(e.value.toString());
        if (n != null && n >= 0) {
          entries[e.key.toString()] = RestockEntry(minimum: n);
        }
      }
    }
    for (final id in checked ?? const <String>[]) {
      entries[id] = RestockEntry(minimum: entries[id]?.minimum, ordered: true);
    }
    if (thresholdRaw != null || checked != null) {
      await _write(prefs, key, entries);
      // Retire only unscoped keys actually inherited by this account. Old
      // account-scoped values remain as a rollback copy and are ignored now.
      if (signedIn &&
          prefs.getString(thresholdsKey) == null &&
          thresholdRaw != null) {
        await prefs.remove(_thresholdKey);
      }
      if (signedIn &&
          prefs.getStringList(checkedKey) == null &&
          checked != null) {
        await prefs.remove(_checkedKey);
      }
    }
    return RestockPlan(entries);
  }

  static Future<RestockPlan> load() {
    final key = accountKey;
    return _serial(() => _read(key));
  }

  static Future<void> _change(
    String id,
    RestockEntry Function(RestockEntry) update, {
    String? expectedAccount,
  }) {
    final key = expectedAccount ?? accountKey;
    return _serial(() async {
      _guard(key);
      final plan = await _read(key);
      final entries = {...plan.entries};
      final next = update(plan.entry(id));
      if (next.isEmpty) {
        entries.remove(id);
      } else {
        entries[id] = next;
      }
      final prefs = await SharedPreferences.getInstance();
      await _write(prefs, key, entries);
    });
  }

  static Future<void> setThreshold(String id, int? minimum) => _change(
    id,
    (e) => RestockEntry(
      minimum: minimum != null && minimum >= 0 ? minimum : null,
      buyQuantity: e.buyQuantity,
      ordered: e.ordered,
      orderQuantity: e.orderQuantity,
      receiptTotal: e.receiptTotal,
    ),
  );
  static Future<void> planPurchase(
    String id,
    int quantity, {
    required String account,
  }) => _change(
    id,
    (e) =>
        RestockEntry(minimum: e.minimum, buyQuantity: quantity, ordered: false),
    expectedAccount: account,
  );
  static Future<void> order(
    String id,
    int quantity, {
    required String account,
  }) => _change(
    id,
    (e) => RestockEntry(
      minimum: e.minimum,
      buyQuantity: e.buyQuantity,
      ordered: true,
      orderQuantity: quantity,
    ),
    expectedAccount: account,
  );
  static Future<void> cancelOrder(String id, {required String account}) =>
      _change(
        id,
        (e) => RestockEntry(
          minimum: e.minimum,
          buyQuantity: e.orderQuantity ?? e.buyQuantity ?? 1,
        ),
        expectedAccount: account,
      );
  static Future<void> prepareReceipt(
    String id,
    int total, {
    required String account,
  }) => _change(
    id,
    (e) => RestockEntry(
      minimum: e.minimum,
      buyQuantity: e.buyQuantity,
      ordered: e.ordered,
      orderQuantity: e.orderQuantity,
      receiptTotal: total,
    ),
    expectedAccount: account,
  );
  static Future<void> finishReceipt(String id, {required String account}) =>
      _change(
        id,
        (e) => RestockEntry(minimum: e.minimum),
        expectedAccount: account,
      );
  static Future<void> remove(String id, {required String account}) =>
      _change(id, (_) => const RestockEntry(), expectedAccount: account);
}
