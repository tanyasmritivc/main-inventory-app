import 'dart:convert';
import '../../core/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingAnswers {
  const OnboardingAnswers({
    required this.useCase,
    required this.inventoryTypes,
    required this.primaryGoal,
    required this.collaboration,
    this.useCaseOther,
    this.inventoryOther,
  });
  final String useCase, primaryGoal, collaboration;
  final List<String> inventoryTypes;
  final String? useCaseOther, inventoryOther;
  Map<String, dynamic> toJson() => {
    'schema_version': 1,
    'use_case': useCase,
    'use_case_other': useCaseOther,
    'inventory_types': [...inventoryTypes]..sort(),
    'inventory_other': inventoryOther,
    'primary_goal': primaryGoal,
    'collaboration': collaboration,
  };
  factory OnboardingAnswers.fromJson(Map<String, dynamic> json) {
    if (json['schema_version'] != 1) {
      throw const FormatException('Unsupported setup answers');
    }
    return OnboardingAnswers(
      useCase: json['use_case'] as String,
      inventoryTypes: (json['inventory_types'] as List).cast<String>(),
      primaryGoal: json['primary_goal'] as String,
      collaboration: json['collaboration'] as String,
      useCaseOther: json['use_case_other'] as String?,
      inventoryOther: json['inventory_other'] as String?,
    );
  }
}

/// Drafts are claimed once, then keyed by account. A late save cannot affect the
/// next signed-in account. Retries replace the same server row, never inventory.
class OnboardingAnswerStore {
  static final Map<String, Future<bool>> _queues = {};
  static const _anonymous = 'findez.setup.anonymous.v1';
  static String _pending(String id) => 'findez.setup.pending.v1.$id';
  static String _saved(String id) => 'findez.setup.saved.v1.$id';
  static Future<void> _write(
    SharedPreferences prefs,
    String key,
    String value,
  ) async {
    if (!await prefs.setString(key, value)) {
      throw StateError('Setup answers were not saved');
    }
  }

  static Future<void> saveDraft(
    OnboardingAnswers answers, {
    String? accountId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (accountId == null) {
      await _write(
        prefs,
        _anonymous,
        jsonEncode({'owner': null, 'answers': answers.toJson()}),
      );
    } else {
      await _write(prefs, _pending(accountId), jsonEncode(answers.toJson()));
    }
  }

  static Future<OnboardingAnswers?> pendingFor(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final owned = prefs.getString(_pending(id));
    final text = prefs.getString(_anonymous);
    if (text == null) {
      return owned == null
          ? null
          : OnboardingAnswers.fromJson(
              jsonDecode(owned) as Map<String, dynamic>,
            );
    }
    final record = jsonDecode(text) as Map<String, dynamic>;
    if (record['owner'] != null && record['owner'] != id) {
      return owned == null
          ? null
          : OnboardingAnswers.fromJson(
              jsonDecode(owned) as Map<String, dynamic>,
            );
    }
    record['owner'] = id;
    await _write(prefs, _anonymous, jsonEncode(record));
    final answers = OnboardingAnswers.fromJson(
      record['answers'] as Map<String, dynamic>,
    );
    await _write(prefs, _pending(id), jsonEncode(answers.toJson()));
    // Keep an owned duplicate if native removal fails; another account cannot claim it.
    await prefs.remove(_anonymous);
    return answers;
  }

  static Future<bool> sync(ApiClient api) {
    final id = api.accountId;
    if (id == null) return Future.value(false);
    final prior = _queues[id] ?? Future.value(false);
    final next = prior.then(
      (_) => _syncOne(api, id),
      onError: (Object _) => _syncOne(api, id),
    );
    _queues[id] = next;
    return next.whenComplete(() {
      if (identical(_queues[id], next)) _queues.remove(id);
    });
  }

  static Future<bool> _syncOne(ApiClient api, String id) async {
    if (api.accountId != id) return false;
    final answers = await pendingFor(id);
    if (answers == null) return false;
    if (api.accountId != id) {
      throw StateError('Account changed before saving setup');
    }
    await api.saveOnboardingAnswers(answers.toJson());
    if (api.accountId != id) return false;
    final prefs = await SharedPreferences.getInstance();
    final serialized = jsonEncode(answers.toJson());
    await _write(prefs, _saved(id), serialized);
    // Do not remove a newer draft entered while the request was in flight.
    if (prefs.getString(_pending(id)) == serialized &&
        !await prefs.remove(_pending(id))) {
      throw StateError('Could not confirm saved setup');
    }
    final anon = prefs.getString(_anonymous);
    if (anon != null) {
      final record = jsonDecode(anon) as Map<String, dynamic>;
      if (record['owner'] == id &&
          jsonEncode(record['answers']) == serialized) {
        await prefs.remove(_anonymous);
      }
    }
    return true;
  }

  static Future<OnboardingAnswers?> cachedFor(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final text = prefs.getString(_pending(id)) ?? prefs.getString(_saved(id));
    return text == null
        ? null
        : OnboardingAnswers.fromJson(jsonDecode(text) as Map<String, dynamic>);
  }
}
