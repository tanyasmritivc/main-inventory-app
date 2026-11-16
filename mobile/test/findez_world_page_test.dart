import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/world/findez_world_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// The fake implements the already installed WebView plugin's platform contract.
// ignore: depend_on_referenced_packages
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'support/hierarchy_fixture.dart';

class WorldWebPlatform extends WebViewPlatform {
  final controllers = <WorldWebController>[];
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    final controller = WorldWebController(params);
    controllers.add(controller);
    return controller;
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => WorldNavigation(params);
  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => WorldWebWidget(params);
}

class WorldWebWidget extends PlatformWebViewWidget {
  WorldWebWidget(super.params) : super.implementation();
  @override
  Widget build(BuildContext context) =>
      const SizedBox.expand(key: ValueKey('web-surface'));
}

class WorldNavigation extends PlatformNavigationDelegate {
  WorldNavigation(super.params) : super.implementation();
  late NavigationRequestCallback navigate;
  late PageEventCallback started, finished;
  late WebResourceErrorCallback failed;
  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback callback,
  ) async {
    navigate = callback;
  }

  @override
  Future<void> setOnPageStarted(PageEventCallback callback) async {
    started = callback;
  }

  @override
  Future<void> setOnPageFinished(PageEventCallback callback) async {
    finished = callback;
  }

  @override
  Future<void> setOnWebResourceError(WebResourceErrorCallback callback) async {
    failed = callback;
  }

  @override
  Future<void> setOnUrlChange(UrlChangeCallback callback) async {}
  @override
  Future<void> setOnHttpError(HttpResponseErrorCallback callback) async {}
}

class WorldWebController extends PlatformWebViewController {
  WorldWebController(super.params) : super.implementation();
  late WorldNavigation navigation;
  late JavaScriptChannelParams channel;
  String? url;
  Completer<String?>? pendingUrl;
  final scripts = <String>[];
  @override
  Future<void> setJavaScriptMode(JavaScriptMode mode) async {}
  @override
  Future<void> setBackgroundColor(Color color) async {}
  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {
    navigation = handler as WorldNavigation;
  }

  @override
  Future<void> addJavaScriptChannel(JavaScriptChannelParams params) async {
    channel = params;
  }

  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    url = params.uri.toString();
    navigation.started(url!);
  }

  @override
  Future<String?> currentUrl() => pendingUrl?.future ?? Future.value(url);
  @override
  Future<void> runJavaScript(String script) async {
    scripts.add(script);
  }

  void ready() =>
      channel.onMessageReceived(const JavaScriptMessage(message: 'ready'));
}

void main() {
  final fixture = HierarchyFixture();
  late WorldWebPlatform platform;
  final orientations = <List<dynamic>>[];
  setUpAll(fixture.initialize);
  tearDownAll(() => Supabase.instance.dispose());
  setUp(() async {
    await fixture.signIn('actor-a');
    platform = WorldWebPlatform();
    WebViewPlatform.instance = platform;
    orientations.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'SystemChrome.setPreferredOrientations') {
            orientations.add(call.arguments as List<dynamic>);
          }
          return null;
        });
  });
  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: FindEZWorldPage()));
    await tester.pump();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  test('only the exact World HTTPS origin and path are trusted', () {
    for (final value in [
      'https://www.findez.ai/world?embed=1',
      'https://www.findez.ai/world/s/token',
    ]) {
      expect(FindEZWorldPage.isWorldUrl(value), isTrue);
    }
    for (final value in [
      'http://www.findez.ai/world',
      'https://www.findez.ai.evil.test/world',
      'https://www.findez.ai:444/world',
      'https://evil@www.findez.ai/world',
      'https://www.findez.ai/worlds',
      'https://www.findez.ai/world/../signin',
      'javascript:alert(1)',
    ]) {
      expect(FindEZWorldPage.isWorldUrl(value), isFalse, reason: value);
    }
  });

  testWidgets(
    'ready handoff and refresh stay in the trusted main page; exit restores portrait',
    (tester) async {
      await mount(tester);
      final controller = platform.controllers.single;
      expect(controller.url, 'https://www.findez.ai/world?embed=1');
      expect(controller.scripts, isEmpty);
      expect(find.text('Opening World...'), findsOneWidget);
      expect(orientations.single, [
        'DeviceOrientation.portraitUp',
        'DeviceOrientation.landscapeLeft',
        'DeviceOrientation.landscapeRight',
      ]);
      controller.ready();
      await tester.pump();
      expect(find.text('Opening World...'), findsNothing);
      expect(controller.scripts.single, contains('window === window.top'));
      expect(controller.scripts.single, contains('"type":"fz-session"'));
      expect(
        controller.scripts.single,
        contains('"refresh_token":"test-refresh"'),
      );
      await Supabase.instance.client.auth.refreshSession();
      await tester.pump();
      expect(controller.scripts.length, 2);
      expect(
        await controller.navigation.navigate(
          const NavigationRequest(
            url: 'https://www.findez.ai/world/s/test',
            isMainFrame: false,
          ),
        ),
        NavigationDecision.prevent,
      );
      controller.url = 'https://external.test/world';
      controller.ready();
      await tester.pump();
      expect(controller.scripts.length, 2);
      await close(tester);
      expect(orientations.last, ['DeviceOrientation.portraitUp']);
    },
  );

  testWidgets('account switch retires a pending session handoff', (
    tester,
  ) async {
    await mount(tester);
    final controller = platform.controllers.single;
    controller.pendingUrl = Completer<String?>();
    controller.ready();
    await fixture.signIn('actor-b');
    await tester.pump();
    controller.pendingUrl!.complete(FindEZWorldPage.entry.toString());
    await tester.pump();
    expect(controller.scripts, isEmpty);
    expect(
      find.text('Your session changed. Close World and open it again.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('web-surface')), findsNothing);
    expect(find.text('Try again'), findsNothing);
    await close(tester);
  });

  testWidgets(
    'offline timeout retries with a fresh controller and ignores late ready',
    (tester) async {
      await mount(tester);
      final old = platform.controllers.single;
      await tester.pump(const Duration(seconds: 26));
      expect(find.text('Try again'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pump();
      old.ready();
      await tester.pump();
      expect(old.scripts, isEmpty);
      expect(platform.controllers.length, 2);
      platform.controllers.last.ready();
      await tester.pump();
      expect(find.text('Try again'), findsNothing);
      await close(tester);
    },
  );

  testWidgets('keyboard resizes the native WebView in landscape', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = FakeViewPadding(bottom: 190);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await mount(tester);
    platform.controllers.single.ready();
    await tester.pump();
    expect(
      tester.getSize(find.byKey(const ValueKey('web-surface'))).height,
      200,
    );
    expect(tester.takeException(), isNull);
    await close(tester);
  });
}
