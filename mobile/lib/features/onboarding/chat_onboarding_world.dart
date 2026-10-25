import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Only the supplied 3D scene is web content; all controls/chat are Flutter.
class ChatOnboardingWorld extends StatefulWidget {
  const ChatOnboardingWorld({
    super.key,
    required this.mode,
    required this.filled,
    required this.found,
  });
  final String mode;
  final int filled, found;
  @override
  State<ChatOnboardingWorld> createState() => _ChatOnboardingWorldState();
}

class _ChatOnboardingWorldState extends State<ChatOnboardingWorld> {
  WebViewController? _controller;
  Timer? _timeout;
  bool _ready = false, _failed = false;
  bool? _reduce;
  int _generation = 0;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (_reduce != reduce) {
      _reduce = reduce;
      unawaited(_load(reduce));
    }
  }

  Future<void> _load(bool reduce) async {
    final generation = ++_generation;
    _ready = false;
    _timeout?.cancel();
    try {
      final controller = WebViewController();
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setBackgroundColor(Colors.transparent);
      await controller.enableZoom(false);
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) =>
              !_ready &&
                  (request.url == 'about:blank' ||
                      request.url ==
                          'https://onboarding.findez.invalid/${reduce ? '?reduce=1' : ''}')
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
          onWebResourceError: (error) {
            developer.log(
              'Scene load failed: ${error.errorCode}',
              name: 'findez.onboarding',
            );
            _fail(generation);
          },
        ),
      );
      await controller.addJavaScriptChannel(
        'World',
        onMessageReceived: (message) {
          if (!mounted || generation != _generation) return;
          developer.log('Scene: ${message.message}', name: 'findez.onboarding');
          if (message.message == 'ready') {
            _timeout?.cancel();
            _ready = true;
            unawaited(_sync());
          } else if (message.message.startsWith('error')) {
            _fail(generation);
          }
        },
      );
      final html = await rootBundle.loadString(
        'assets/onboarding/onboarding_world.html',
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _controller = controller;
        _failed = false;
      });
      _timeout = Timer(const Duration(seconds: 8), () {
        developer.log('Scene timed out', name: 'findez.onboarding');
        _fail(generation);
      });
      await controller.loadHtmlString(
        reduce
            ? html.replaceAll('/reduce=1/.test(location.search)', 'true')
            : html,
        baseUrl:
            'https://onboarding.findez.invalid/${reduce ? '?reduce=1' : ''}',
      );
    } catch (_) {
      _fail(generation);
    }
  }

  void _fail(int generation) {
    if (mounted && generation == _generation) {
      _timeout?.cancel();
      setState(() => _failed = true);
    }
  }

  Future<void> _sync() async {
    if (!_ready || _failed) return;
    try {
      await _controller?.runJavaScript(
        'FindEZWorld.set(${jsonEncode({'mode': widget.mode, 'filled': widget.filled.clamp(0, 12), 'found': widget.found.clamp(-1, 11)})});',
      );
    } catch (_) {
      _fail(_generation);
    }
  }

  @override
  void didUpdateWidget(covariant ChatOnboardingWorld oldWidget) {
    super.didUpdateWidget(oldWidget);
    unawaited(_sync()); // Current props are the queue until World.ready.
  }

  @override
  void dispose() {
    _generation++;
    _timeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: _failed || _controller == null
        ? const SizedBox.expand()
        : WebViewWidget(key: ObjectKey(_controller), controller: _controller!),
  );
}
