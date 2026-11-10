import 'dart:io' show Platform;
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

@visibleForTesting
bool? debugNativeBottomTabsOverride;
bool get usesNativeBottomTabs =>
    debugNativeBottomTabsOverride ?? (!kIsWeb && Platform.isIOS);

/// Hosts the system UITabBar. iOS owns Liquid Glass and touch motion.
class NativeBottomTabs extends StatefulWidget {
  const NativeBottomTabs({
    super.key,
    required this.selected,
    required this.onSelected,
    this.onScan,
  });
  static const selectionLead = Duration(milliseconds: 300);
  final int selected;
  final ValueChanged<int> onSelected;
  final VoidCallback? onScan;
  @override
  State<NativeBottomTabs> createState() => _NativeBottomTabsState();
}

class _NativeBottomTabsState extends State<NativeBottomTabs> {
  MethodChannel? _channel;
  Timer? _selectionTimer;
  int? _pendingSelection;

  void _cancelPending() {
    _selectionTimer?.cancel();
    _selectionTimer = null;
    _pendingSelection = null;
  }

  void _select(int index) {
    _cancelPending();
    if (index == widget.selected) {
      unawaited(_configure());
      return;
    }
    // UIKit has already moved its selected item. Keep that optimistic selection
    // during unrelated rebuilds, then let the retained page follow it.
    _pendingSelection = index;
    final reduced =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    _selectionTimer = Timer(
      reduced ? Duration.zero : NativeBottomTabs.selectionLead,
      () {
        if (!mounted || _pendingSelection != index) return;
        _cancelPending();
        widget.onSelected(index);
      },
    );
  }

  Map<String, Object> get _configuration => {
    'selected': _pendingSelection ?? widget.selected,
    'scanEnabled': widget.onScan != null,
    'dark': Theme.of(context).brightness == Brightness.dark,
    'reduceMotion':
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context),
  };
  Future<void> _configure() async {
    await _channel?.invokeMethod<void>('configure', _configuration);
  }

  @override
  void didUpdateWidget(NativeBottomTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) _cancelPending();
    unawaited(_configure());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    unawaited(_configure());
  }

  @override
  void dispose() {
    _cancelPending();
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    // Includes UIKit's standard bar and bottom clearance; avoids clipped hits.
    height: 83,
    child: UiKitView(
      viewType: 'com.findez.app/native-tabs',
      creationParamsCodec: const StandardMessageCodec(),
      creationParams: _configuration,
      onPlatformViewCreated: (id) {
        if (!mounted) return;
        _channel = MethodChannel('com.findez.app/native-tabs/$id');
        _channel!.setMethodCallHandler((call) async {
          if (!mounted) return;
          if (call.method == 'scan') {
            _cancelPending();
            unawaited(_configure());
            widget.onScan?.call();
            return;
          }
          if (call.method != 'selected') return;
          final index = call.arguments;
          if (index is int && index >= 0 && index < 2) {
            _select(index);
          }
        });
        unawaited(_configure());
      },
    ),
  );
}
