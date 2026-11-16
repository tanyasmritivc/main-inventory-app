import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// World uses the existing account and inventory through the live web client.
class FindEZWorldPage extends StatefulWidget {
  const FindEZWorldPage({super.key});

  static const origin = 'https://www.findez.ai';
  static final entry = Uri.parse('$origin/world?embed=1');

  static bool isWorldUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host == 'www.findez.ai' &&
        uri.port == 443 &&
        uri.userInfo.isEmpty &&
        (uri.path == '/world' || uri.path.startsWith('/world/'));
  }

  @override
  State<FindEZWorldPage> createState() => _FindEZWorldPageState();
}

class _FindEZWorldPageState extends State<FindEZWorldPage> {
  final _auth = Supabase.instance.client.auth;
  late final String? _accountId;
  StreamSubscription<AuthState>? _authChanges;
  WebViewController? _controller;
  Timer? _timeout;
  int _generation = 0;
  bool _ready = false, _closed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _accountId = _auth.currentUser?.id;
    unawaited(
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]),
    );
    _authChanges = _auth.onAuthStateChange.listen(
      (state) {
        if (state.session?.user.id != _accountId || state.session == null) {
          _retireSession();
        } else if (_ready) {
          unawaited(_sendSession(_generation));
        }
      },
      onError: (Object error, StackTrace stack) {
        _fail(_generation, 'Your connection was interrupted. Try again.');
      },
    );
    unawaited(_load());
  }

  bool _current(int generation) =>
      mounted && !_closed && generation == _generation;

  void _retireSession() {
    if (!mounted || _closed) return;
    _generation++;
    _timeout?.cancel();
    setState(() {
      _controller = null;
      _ready = false;
      _error = 'Your session changed. Close World and open it again.';
    });
  }

  void _fail(int generation, [String? message]) {
    if (!_current(generation)) return;
    _timeout?.cancel();
    setState(() {
      _ready = false;
      _error =
          message ??
          'World could not connect. Check your connection and try again.';
    });
  }

  void _startTimeout(int generation) {
    _timeout?.cancel();
    _timeout = Timer(const Duration(seconds: 25), () => _fail(generation));
  }

  Future<void> _load() async {
    if (_accountId == null || _auth.currentSession?.user.id != _accountId) {
      _retireSession();
      return;
    }
    final generation = ++_generation;
    setState(() {
      _ready = false;
      _error = null;
      _controller = null;
    });
    _startTimeout(generation);
    try {
      final controller = WebViewController();
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setBackgroundColor(const Color(0xfff4f1e9));
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            if (!_current(generation) || !request.isMainFrame) {
              return NavigationDecision.prevent;
            }
            if (FindEZWorldPage.isWorldUrl(request.url)) {
              final uri = Uri.parse(request.url);
              if (uri.path == '/world' && uri.queryParameters['embed'] != '1') {
                unawaited(
                  controller
                      .loadRequest(
                        uri.replace(
                          queryParameters: {
                            ...uri.queryParameters,
                            'embed': '1',
                          },
                        ),
                      )
                      .catchError((Object _) => _fail(generation)),
                );
                return NavigationDecision.prevent;
              }
              return NavigationDecision.navigate;
            }
            unawaited(_openExternal(request.url, generation));
            return NavigationDecision.prevent;
          },
          onPageStarted: (url) {
            if (!_current(generation)) return;
            if (!FindEZWorldPage.isWorldUrl(url)) {
              _fail(generation);
              return;
            }
            setState(() => _ready = false);
            _startTimeout(generation);
          },
          onPageFinished: (url) {
            // Public shares have no account handoff or native ready message.
            if (_current(generation) &&
                FindEZWorldPage.isWorldUrl(url) &&
                Uri.parse(url).path.startsWith('/world/s/') &&
                _error == null) {
              _timeout?.cancel();
              setState(() => _ready = true);
            }
          },
          onUrlChange: (change) {
            if (change.url != null &&
                !FindEZWorldPage.isWorldUrl(change.url!)) {
              _fail(generation);
            }
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame != false) _fail(generation);
          },
          onHttpError: (error) {
            final url = error.request?.uri.toString();
            if (url == null || FindEZWorldPage.isWorldUrl(url)) {
              _fail(generation);
            }
          },
        ),
      );
      await controller.addJavaScriptChannel(
        'FindEZApp',
        onMessageReceived: (message) {
          if (message.message == 'ready' &&
              _current(generation) &&
              _error == null) {
            unawaited(_sendSession(generation));
          }
        },
      );
      if (!_current(generation)) return;
      setState(() => _controller = controller);
      await controller.loadRequest(FindEZWorldPage.entry);
    } catch (_) {
      _fail(generation);
    }
  }

  Future<void> _sendSession(int generation) async {
    final controller = _controller;
    if (!_current(generation) || controller == null || _error != null) return;
    try {
      final url = await controller.currentUrl();
      if (!_current(generation) ||
          url == null ||
          !FindEZWorldPage.isWorldUrl(url)) {
        return;
      }
      final uri = Uri.parse(url);
      if (uri.path != '/world' || uri.queryParameters['embed'] != '1') return;
      final session = _auth.currentSession;
      if (session == null ||
          session.user.id != _accountId ||
          session.refreshToken == null) {
        _retireSession();
        return;
      }
      // Evaluate in the main frame and recheck its destination at execution time.
      // Never send credentials to a share, external page, URL, or log.
      final payload = jsonEncode({
        'type': 'fz-session',
        'access_token': session.accessToken,
        'refresh_token': session.refreshToken,
      });
      await controller.runJavaScript('''
        if (window === window.top && location.origin === "${FindEZWorldPage.origin}" &&
            location.pathname === "/world" &&
            new URLSearchParams(location.search).get("embed") === "1") {
          window.postMessage($payload, "${FindEZWorldPage.origin}");
        }
      ''');
      if (!_current(generation)) return;
      _timeout?.cancel();
      setState(() => _ready = true);
    } catch (_) {
      _fail(generation);
    }
  }

  Future<void> _openExternal(String value, int generation) async {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !const ['https', 'http', 'mailto'].contains(uri.scheme)) {
      return;
    }
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('Unavailable');
      }
    } catch (_) {
      if (mounted && _current(generation)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This link could not be opened.')),
        );
      }
    }
  }

  @override
  void dispose() {
    _closed = true;
    _generation++;
    _timeout?.cancel();
    unawaited(_authChanges?.cancel());
    unawaited(
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
      ]),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xfff4f1e9),
    resizeToAvoidBottomInset: true,
    body: Stack(
      children: [
        if (_controller != null && _error == null)
          Positioned.fill(
            child: WebViewWidget(
              key: ObjectKey(_controller),
              controller: _controller!,
            ),
          ),
        if (!_ready || _error != null)
          Positioned.fill(
            child: ColoredBox(
              color: const Color(0xfff4f1e9),
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_error == null) const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          _error ?? 'Opening World...',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xff242424)),
                        ),
                        if (_error != null &&
                            _accountId != null &&
                            _auth.currentSession?.user.id == _accountId)
                          TextButton(
                            onPressed: _load,
                            child: const Text('Try again'),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          top: 0,
          left: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: IconButton.filledTonal(
                tooltip: 'Close World',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, size: 20),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
