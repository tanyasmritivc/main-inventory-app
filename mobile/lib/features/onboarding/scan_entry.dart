import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/api_client.dart';
import '../../core/last_place.dart';
import '../../core/ui/findez_wordmark.dart';
import '../../core/ui/launch_loading_screen.dart';
import '../auth/auth_page.dart';
import '../workspaces/inventory_context_host.dart';
import 'pending_world.dart';
import 'chat_onboarding_draft.dart';

/// This choice is an onboarding intent, never an authorization or entitlement.
/// Claim it before any network request so switching accounts cannot inherit it.
class ScanEntryStore {
  static const pendingKey = 'findez.scan-entry.pending.v1';
  static String accountKey(String id) => 'findez.scan-entry.$id.v1';
  static Future<void> choose(String path) async {
    if (!['personal', 'team', 'returning'].contains(path)) {
      throw ArgumentError.value(path);
    }
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(pendingKey, jsonEncode({'path': path}))) {
      throw StateError('Could not save your choice');
    }
  }

  static Future<Map<String, dynamic>?> claim(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final owned = prefs.getString(accountKey(id));
    final previous = owned == null
        ? null
        : Map<String, dynamic>.from(jsonDecode(owned));
    final raw = prefs.getString(pendingKey);
    if (raw == null ||
        (previous != null &&
            previous['complete'] != true &&
            previous['path'] == 'team')) {
      return previous;
    }
    final value = Map<String, dynamic>.from(jsonDecode(raw));
    if (value['owner'] != null && value['owner'] != id) return previous;
    value['owner'] = id;
    if (!await prefs.setString(pendingKey, jsonEncode(value))) {
      throw StateError('Could not retain your setup');
    }
    await save(id, value);
    await prefs.remove(pendingKey);
    return value;
  }

  static Future<void> save(String id, Map<String, dynamic> value) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(
      accountKey(id),
      jsonEncode({...value, 'owner': id}),
    )) {
      throw StateError('Could not retain your setup');
    }
  }
}

class ScanEntryPage extends StatefulWidget {
  const ScanEntryPage({super.key});
  @override
  State<ScanEntryPage> createState() => _ScanEntryPageState();
}

class _ScanEntryPageState extends State<ScanEntryPage> {
  String? _path, _error;
  bool _busy = false;
  Future<void> _choose(String path) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ScanEntryStore.choose(path);
      if (mounted) setState(() => _path = path);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Your choice could not be saved. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_path != null) {
      return AuthPage(
        welcomeTagline: _path != 'returning',
        onBackToSetup: () => setState(() => _path = null),
      );
    }
    return ScanSetupSurface(
      children: [
        const Center(child: FindEZWordmark(width: 150)),
        const SizedBox(height: 32),
        const Text(
          'Memory for physical things.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            letterSpacing: -.8,
          ),
        ),
        const SizedBox(height: 48),
        const Text(
          'Just you, or a team?',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 24),
        for (final path in ['personal', 'team'])
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(60),
              ),
              onPressed: _busy ? null : () => _choose(path),
              child: Text(path == 'personal' ? 'Personal' : 'Team'),
            ),
          ),
        TextButton(
          onPressed: _busy ? null : () => _choose('returning'),
          child: const Text('Already have an account? Sign in'),
        ),
        if (_error != null) Text(_error!, textAlign: TextAlign.center),
      ],
    );
  }
}

/// Legacy onboarding recovery stays in [child]. New team provisioning reuses
/// the existing durable receipts rather than repeating unconfirmed creates.
class ScanSetupGate extends StatefulWidget {
  const ScanSetupGate({
    super.key,
    required this.api,
    required this.child,
    this.onReady,
  });
  final ApiClient api;
  final Widget child;
  final Widget Function(Widget)? onReady;
  @override
  State<ScanSetupGate> createState() => _ScanSetupGateState();
}

class _ScanSetupGateState extends State<ScanSetupGate> {
  late final String _actor = widget.api.accountId!;
  final _name = TextEditingController();
  Map<String, dynamic>? _state;
  WorldLanding? _landing;
  bool _loading = true, _busy = false;
  String? _error, _referral;
  static const sources = [
    'A friend or teammate',
    'Google',
    'App Store',
    'Instagram',
    'TikTok',
    'YouTube',
    'Reddit',
    'School or work',
    'Other',
  ];
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _current() {
    if (!mounted || widget.api.accountId != _actor) {
      throw StateError('Account changed');
    }
    widget.api.assertCurrentContext();
  }

  Future<void> _load() async {
    try {
      final state = await ScanEntryStore.claim(_actor);
      _current();
      _state = state;
      // Preserve an explicitly retained draft from an older installation when
      // authentication now enters through the new welcome screen.
      final retained = await ChatOnboardingStore.read();
      _current();
      if (retained != null &&
          retained.keep &&
          retained.method.isEmpty &&
          (retained.owner == null || retained.owner == _actor)) {
        retained.method = 'account';
        await ChatOnboardingStore.save(retained);
        _current();
      }
      if (state?['path'] == 'personal' && state?['complete'] != true) {
        await LastPlaceStore(_actor).save(
          const LastPlace.personal(),
          isCurrent: () => mounted && widget.api.accountId == _actor,
        );
        await _save({...state!, 'complete': true});
      }
      _landing = await WorldSetupStore.landing(_actor);
      _current();
      _name.text = state?['name'] as String? ?? '';
    } catch (_) {
      _error = 'Your setup could not be loaded. Try again.';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save(Map<String, dynamic> state) async {
    _current();
    await ScanEntryStore.save(_actor, state);
    _current();
    _state = state;
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    if (_busy || !PendingWorld.validName(name, 60)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _current();
      await _save({..._state!, 'name': name});
      final pending = await WorldSetupStore.claim(_actor);
      _current();
      if (pending == null && _landing == null) {
        await WorldSetupStore.saveOwned(
          PendingWorld(
            path: 'team',
            orgName: name,
            workspacePurpose: name.length > 40 ? 'Workspace' : name,
            inventoryName: 'Inventory',
            step: WorldStep.auth,
            owner: _actor,
            accepted: true,
          ),
        );
      }
      _landing = await WorldProvisioner(
        ExistingWorldApi(widget.api),
      ).run((_) async => true);
      _current();
      if (_landing == null) throw StateError('Setup not confirmed');
      await _save({
        ..._state!,
        'created': true,
        'organization': _landing!.organizationId,
      });
    } catch (_) {
      if (mounted) {
        _error =
            'Setup is not confirmed yet. Retry checks before creating anything else.';
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finish() async {
    if (_busy || _referral == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _current();
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {'findez_referral_source': _referral}),
      );
      _current();
      await _save({..._state!, 'complete': true, 'referral': _referral});
    } catch (_) {
      if (mounted) _error = 'Your answer could not be saved. Try again.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LaunchLoadingScreen();
    if (_state == null && _error != null) {
      return ScanSetupSurface(
        children: [
          Text(_error!),
          TextButton(
            onPressed: () {
              setState(() => _loading = true);
              _load();
            },
            child: const Text('Retry'),
          ),
        ],
      );
    }
    if (_state?['path'] != 'team' || _state?['complete'] == true) {
      if (_state?['path'] == 'team' && _landing != null) {
        final host = InventoryContextHost(
          api: widget.api,
          initialWorkspaceId: _landing!.workspaceId,
          initialInventoryId: _landing!.inventoryId,
          initialOrganizationId: _landing!.organizationId,
          onInitialInventoryOpened: () =>
              WorldSetupStore.clearLanding(_actor, _landing!.inventoryId),
        );
        return widget.onReady?.call(host) ?? host;
      }
      return widget.onReady?.call(widget.child) ?? widget.child;
    }
    final created = _state?['created'] == true;
    return ScanSetupSurface(
      children: [
        Text(
          created
              ? 'How did you hear about FindEZ?'
              : 'Create your organization',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            letterSpacing: -.7,
          ),
        ),
        const SizedBox(height: 28),
        if (!created)
          TextField(
            controller: _name,
            maxLength: 60,
            enabled: !_busy,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Organization name',
              hintText: 'Robotics team',
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _create(),
          )
        else
          RadioGroup<String>(
            groupValue: _referral,
            onChanged: (value) {
              if (!_busy) setState(() => _referral = value);
            },
            child: Column(
              children: [
                for (final source in sources)
                  RadioListTile<String>(
                    value: source,
                    title: Text(source),
                    contentPadding: EdgeInsets.zero,
                  ),
              ],
            ),
          ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed:
              _busy ||
                  (created
                      ? _referral == null
                      : !PendingWorld.validName(_name.text, 60))
              ? null
              : created
              ? _finish
              : _create,
          child: Text(
            _busy
                ? 'Saving…'
                : created
                ? 'Continue'
                : 'Create organization',
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(_error!),
          ),
      ],
    );
  }
}

class ScanSetupSurface extends StatelessWidget {
  const ScanSetupSurface({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, size) => SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (size.maxHeight - 56).clamp(0, double.infinity),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
