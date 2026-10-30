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
  });
  final int selected;
  final ValueChanged<int> onSelected;
  @override
  State<NativeBottomTabs> createState() => _NativeBottomTabsState();
}

class _NativeBottomTabsState extends State<NativeBottomTabs> {
  MethodChannel? _channel;
  Map<String, Object> get _configuration => {
    'selected': widget.selected,
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
    unawaited(_configure());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    unawaited(_configure());
  }

  @override
  void dispose() {
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
          if (!mounted || call.method != 'selected') return;
          final index = call.arguments;
          if (index is int &&
              index >= 0 &&
              index < 3 &&
              index != widget.selected) {
            widget.onSelected(index);
          }
        });
        unawaited(_configure());
      },
    ),
  );
}
