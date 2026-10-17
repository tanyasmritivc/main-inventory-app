// Simulator visual review entry point. Never used by the release target.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'dart:convert';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/core/ui/app_gradient_background.dart';
import 'package:mobile/features/auth/auth_page.dart';
import 'package:mobile/features/onboarding/onboarding_page.dart';
import 'package:mobile/features/onboarding/onboarding_prefs.dart';
import 'package:mobile/features/onboarding/pending_world.dart';

void main() {
  if (!kDebugMode) throw StateError('Visual review requires a debug build');
  WidgetsFlutterBinding.ensureInitialized();
  if (const bool.fromEnvironment('WORLD_PERF')) {
    SchedulerBinding.instance.addTimingsCallback((frames) {
      var ui = 0, raster = 0;
      for (final frame in frames) {
        if (frame.buildDuration.inMicroseconds > ui) {
          ui = frame.buildDuration.inMicroseconds;
        }
        if (frame.rasterDuration.inMicroseconds > raster) {
          raster = frame.rasterDuration.inMicroseconds;
        }
      }
      debugPrint(
        'WORLD_FRAME ${jsonEncode({'frames': frames.length, 'ui_us': ui, 'raster_us': raster})}',
      );
    });
  }
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      showPerformanceOverlay: const bool.fromEnvironment('WORLD_PERF'),
      theme: AppTheme.create(
        Brightness.light,
      ).copyWith(platform: TargetPlatform.iOS),
      home: const AppGradientBackground(child: _VisualEntry()),
    ),
  );
}

class _VisualEntry extends StatefulWidget {
  const _VisualEntry();
  @override
  State<_VisualEntry> createState() => _VisualEntryState();
}

class _VisualEntryState extends State<_VisualEntry> {
  late Future<(bool, PendingWorld?)> _entry;
  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() => setState(() {
    _entry = _read();
  });
  Future<(bool, PendingWorld?)> _read() async =>
      (await OnboardingPrefs.isCompleted(), await WorldSetupStore.draft());
  Future<void> _back() async {
    final draft = await WorldSetupStore.draft();
    if (draft != null) {
      await WorldSetupStore.saveDraft(draft.copyWith(step: WorldStep.world));
    }
    await OnboardingPrefs.setCompleted(false);
    _refresh();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<(bool, PendingWorld?)>(
    future: _entry,
    builder: (context, snapshot) {
      if (!snapshot.hasData) return const Scaffold();
      final (completed, draft) = snapshot.requireData;
      return completed
          ? AuthPage(
              fromOnboarding: draft?.ready ?? false,
              onBackToSetup: _back,
            )
          : OnboardingPage(onFinished: _refresh, onExistingAccount: _refresh);
    },
  );
}
