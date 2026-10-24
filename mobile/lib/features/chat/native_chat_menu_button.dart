import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

bool get usesNativeChatMenu => !kIsWeb && Platform.isIOS;

/// Transparent native hit target over the FindEZ Attach row only.
class NativeChatMenuButton extends StatefulWidget {
  const NativeChatMenuButton({
    super.key,
    required this.enabled,
    required this.onSelected,
    this.menuOpen = false,
  });
  final bool enabled;
  final ValueChanged<String> onSelected;
  final bool menuOpen;
  @override
  State<NativeChatMenuButton> createState() => NativeChatMenuButtonState();
}

class NativeChatMenuButtonState extends State<NativeChatMenuButton> {
  MethodChannel? _channel;
  Future<void> _configure() async {
    await _channel?.invokeMethod<void>('configure', {
      'enabled': widget.enabled,
      'dark': Theme.of(context).brightness == Brightness.dark,
      'menuOpen': widget.menuOpen,
    });
  }

  @override
  void didUpdateWidget(NativeChatMenuButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _configure();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _configure();
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 48,
    child: UiKitView(
      viewType: 'com.findez.app/chat-menu',
      creationParamsCodec: const StandardMessageCodec(),
      creationParams: {
        'enabled': widget.enabled,
        'dark': Theme.of(context).brightness == Brightness.dark,
      },
      onPlatformViewCreated: (id) {
        _channel = MethodChannel('com.findez.app/chat-menu/$id');
        _channel!.setMethodCallHandler((call) async {
          if (call.method == 'selected' &&
              mounted &&
              widget.enabled &&
              call.arguments is String) {
            widget.onSelected(call.arguments as String);
          }
        });
        _configure();
      },
    ),
  );
}
