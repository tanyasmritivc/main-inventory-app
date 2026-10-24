import 'dart:async';
import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/ui/launch_loading_screen.dart';
import '../auth/auth_page.dart';
import '../workspaces/inventory_context_host.dart';
import 'onboarding_prefs.dart';
import 'pending_world.dart';

/// Presentation variant only. Auth providers, callbacks and email flows remain
/// owned by the existing AuthPage implementation.
class WorldAuthEntry extends StatefulWidget {
  const WorldAuthEntry({super.key, required this.onAuthChanged});
  final VoidCallback onAuthChanged;
  @override
  State<WorldAuthEntry> createState() => _WorldAuthEntryState();
}

class _WorldAuthEntryState extends State<WorldAuthEntry> {
  late final Future<PendingWorld?> _draft = WorldSetupStore.draft();
  Future<void> _back(PendingWorld setup) async {
    try {
      await WorldSetupStore.saveDraft(setup.copyWith(step: WorldStep.world));
      await OnboardingPrefs.setCompleted(false);
      if (mounted) widget.onAuthChanged();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your setup could not be saved. Try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<PendingWorld?>(
    future: _draft,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const LaunchLoadingScreen();
      }
      // Storage errors must not silently turn a prepared setup into a plain login.
      if (snapshot.hasError) {
        return Scaffold(
          body: Center(
            child: TextButton(
              onPressed: widget.onAuthChanged,
              child: const Text('Setup could not be loaded. Retry'),
            ),
          ),
        );
      }
      final setup = snapshot.data;
      return AuthPage(
        onAuthChanged: widget.onAuthChanged,
        fromOnboarding: setup?.ready ?? false,
        onBackToSetup: setup?.ready == true
            ? () => unawaited(_back(setup!))
            : null,
      );
    },
  );
}

/// Authenticated setup completes before any inventory dashboard mounts. This
/// avoids a flash of Personal and prevents unauthenticated creation calls.
class WorldSetupGate extends StatefulWidget {
  const WorldSetupGate({super.key, required this.api});
  final ApiClient api;
  @override
  State<WorldSetupGate> createState() => _WorldSetupGateState();
}

class _WorldSetupGateState extends State<WorldSetupGate> {
  late Future<WorldLanding?> _setup;
  @override
  void initState() {
    super.initState();
    _setup = _start();
  }

  Future<WorldLanding?> _start() =>
      WorldProvisioner(ExistingWorldApi(widget.api)).run(_choose);
  Future<bool?> _choose(PendingWorld setup) async {
    if (!mounted || widget.api.accountId != setup.owner) return null;
    return showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFFF7F7F6),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add ${setup.isTeam ? setup.orgName : setup.workspacePurpose} to your account?',
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Add it'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Skip'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<WorldLanding?>(
    future: _setup,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(
          backgroundColor: Color(0xFFF7F7F6),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Getting your world ready...'),
              ],
            ),
          ),
        );
      }
      if (snapshot.hasError) {
        return Scaffold(
          backgroundColor: const Color(0xFFF7F7F6),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      "We couldn't finish setting up. Try again.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 18),
                    ),
                  ),
                  if (snapshot.error is SetupOutcomeUncertain) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'The last request is still unconfirmed. Retry checks it before creating anything else.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Color(0xFF6B6965)),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () => setState(() => _setup = _start()),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      final landing = snapshot.data;
      final user = widget.api.accountId;
      return InventoryContextHost(
        api: widget.api,
        initialWorkspaceId: landing?.workspaceId,
        initialInventoryId: landing?.inventoryId,
        initialOrganizationId: landing?.organizationId,
        onInitialInventoryOpened: landing == null || user == null
            ? null
            : () => WorldSetupStore.clearLanding(user, landing.inventoryId),
      );
    },
  );
}
