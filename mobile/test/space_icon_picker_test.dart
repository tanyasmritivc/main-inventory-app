import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/core/inventory_cache.dart';
import 'package:mobile/core/space_icon_preferences.dart';
import 'package:mobile/features/inventory/inventory_page.dart';
import 'package:mobile/features/inventory/space_icon_picker.dart';
import 'package:mobile/features/teams/team_workspace_page.dart';

class _Storage implements SpaceIconStorage {
  final values = <String, String>{};
  bool failRead = false, failWrite = false;
  int writes = 0;
  @override
  Future<String?> read(String key) async {
    if (failRead) throw StateError('SECRET read');
    return values[key];
  }

  @override
  Future<bool> write(String key, String value) async {
    writes++;
    if (failWrite) return false;
    values[key] = value;
    return true;
  }
}

class _Api extends ApiClient {
  _Api() : super(baseUrl: 'https://api.test');
  String name = 'Workshop';
  @override
  Future<SearchItemsResult> searchItems({required String query}) async =>
      SearchItemsResult(items: [], parsed: const {});
  @override
  Future<List<Map<String, dynamic>>> listSpaces() async => [
    {'id': 'stable-id', 'name': name, 'item_count': 0},
  ];
  @override
  Future<List<dynamic>> getMyShares() async => [];
  @override
  Future<List<dynamic>> getJoinedShares() async => [
    {
      'share_id': 'joined-id',
      'team_shares': {
        'share_id': 'joined-id',
        'share_name': 'Joined Space',
        'permission': 'view',
      },
    },
  ];
  @override
  Future<Map<String, dynamic>> getTeamWorkspace(String teamId) async => {
    'role': 'viewer',
    'team': {'name': 'Test Team', 'program': 'makerspace'},
  };
  @override
  Future<Map<String, dynamic>> getTeamSpaces(String teamId) async => {
    'spaces': await listSpaces(),
  };
}

Widget _app(
  Widget child, {
  Brightness brightness = Brightness.light,
  double scale = 1,
  double keyboard = 0,
}) => MaterialApp(
  theme: AppTheme.create(brightness),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(scale),
      viewInsets: EdgeInsets.only(bottom: keyboard),
    ),
    child: child!,
  ),
  home: Scaffold(body: child),
);

Finder get _search => find.descendant(
  of: find.byType(SpaceIconPicker),
  matching: find.byType(TextField),
);
Finder _choice(String id) => find.byKey(ValueKey('space-icon-$id'));
Finder _leading(String name) => find.byTooltip('Change icon for $name');

Future<void> _filter(WidgetTester tester, String text) async {
  await tester.enterText(_search, text);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://auth.test',
      anonKey: 'test',
      authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
      httpClient: MockClient((request) async {
        final user = {
          'id': 'account-a',
          'aud': 'authenticated',
          'role': 'authenticated',
          'email': 'test@example.test',
          'created_at': '2026-01-01T00:00:00Z',
          'app_metadata': {},
          'user_metadata': {},
        };
        final jwt =
            '${base64Url.encode(utf8.encode('{"alg":"HS256"}'))}.'
            '${base64Url.encode(utf8.encode(jsonEncode({'sub': 'account-a', 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600})))}.signature';
        return http.Response(
          jsonEncode(
            request.url.path.endsWith('/token')
                ? {
                    'access_token': jwt,
                    'refresh_token': 'refresh-test',
                    'expires_in': 3600,
                    'token_type': 'bearer',
                    'user': user,
                  }
                : user,
          ),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await Supabase.instance.client.auth.signInWithPassword(
      email: 'test@example.test',
      password: 'test-password',
    );
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    InventoryCache.clear();
  });

  testWidgets('icon target opens only picker; cancel, save, rename and reset', (
    tester,
  ) async {
    final storage = _Storage();
    final preferences = SpaceIconPreferences(storage: storage);
    int spaceOpens = 0;
    Widget card(String name) => _app(
      GestureDetector(
        onTap: () => spaceOpens++,
        child: Row(
          children: [
            SpaceIconButton(
              spaceId: 'stable-id',
              spaceName: name,
              preferences: preferences,
              accountId: () => 'account-a',
            ),
            Text(name),
          ],
        ),
      ),
    );
    await tester.pumpWidget(card('Workshop'));
    await tester.pumpAndSettle();
    expect(tester.getSize(_leading('Workshop')), const Size(44, 44));
    await tester.tap(_leading('Workshop'));
    await tester.pumpAndSettle();
    expect(spaceOpens, 0);
    expect(find.byType(SpaceIconPicker), findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(
      tester.widget<BottomSheet>(find.byType(BottomSheet)).showDragHandle,
      isTrue,
    );
    await _filter(tester, 'Gear');
    await tester.tap(_choice('gear'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(storage.writes, 0);
    expect(find.byIcon(CupertinoIcons.wrench), findsOneWidget);
    await tester.tap(_leading('Workshop'));
    await tester.pumpAndSettle();
    await _filter(tester, 'Gear');
    await tester.tap(_choice('gear'));
    await tester.tap(find.text('Save icon'));
    await tester.pumpAndSettle();
    expect(find.byType(SpaceIconPicker), findsNothing);
    expect(find.byIcon(CupertinoIcons.gear_alt), findsOneWidget);
    await tester.pumpWidget(card('Renamed Space'));
    await tester.pumpAndSettle();
    expect(find.byIcon(CupertinoIcons.gear_alt), findsOneWidget);
    await tester.tap(_leading('Renamed Space'));
    await tester.pumpAndSettle();
    await tester.tap(_choice('automatic'));
    await tester.tap(find.text('Save icon'));
    await tester.pumpAndSettle();
    expect(find.byIcon(CupertinoIcons.archivebox), findsOneWidget);
    await tester.tap(find.text('Renamed Space'));
    expect(spaceOpens, 1);
    await tester.pumpWidget(const SizedBox());
    preferences.dispose();
  });

  testWidgets('search/no results and save failure preserve draft for retry', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final storage = _Storage()..failWrite = true;
    final prefs = SpaceIconPreferences(storage: storage);
    await tester.pumpWidget(
      _app(
        SpaceIconButton(
          spaceId: 'id',
          spaceName: 'Test Space',
          preferences: prefs,
          accountId: () => 'account-a',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(_leading('Test Space'));
    await tester.pumpAndSettle();
    await _filter(tester, 'nothing matches this');
    expect(find.text('No matching icons. Try another name.'), findsOneWidget);
    await _filter(tester, 'Gear');
    await tester.tap(_choice('gear'));
    await tester.tap(find.text('Save icon'));
    await tester.pumpAndSettle();
    expect(find.byType(SpaceIconPicker), findsOneWidget);
    expect(
      find.text('Could not save this Space icon. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('SECRET'), findsNothing);
    expect(
      tester.getSemantics(_choice('gear')).flagsCollection.isSelected,
      ui.Tristate.isTrue,
    );
    storage.failWrite = false;
    await tester.tap(find.text('Save icon'));
    await tester.pumpAndSettle();
    expect(find.byType(SpaceIconPicker), findsNothing);
    expect(find.byIcon(CupertinoIcons.gear_alt), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    prefs.dispose();
    semantics.dispose();
  });

  testWidgets('read retry initializes saved choice instead of resetting it', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final storage = _Storage()..failRead = true;
    storage.values[SpaceIconPreferences.keyFor(
          accountId: 'account-a',
          namespace: 'space',
          id: 'id',
        )] =
        'gear';
    final prefs = SpaceIconPreferences(storage: storage);
    await tester.pumpWidget(
      _app(
        SpaceIconButton(
          spaceId: 'id',
          spaceName: 'Test Space',
          preferences: prefs,
          accountId: () => 'account-a',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(_leading('Test Space'));
    await tester.pumpAndSettle();
    await _filter(tester, 'Gear');
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    storage.failRead = false;
    await tester.ensureVisible(find.text('Retry'));
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(_choice('gear')).flagsCollection.isSelected,
      ui.Tristate.isTrue,
    );
    await tester.tap(find.text('Save icon'));
    await tester.pumpAndSettle();
    expect(find.byIcon(CupertinoIcons.gear_alt), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    prefs.dispose();
    semantics.dispose();
  });

  testWidgets('an open picker cannot save its draft into a switched account', (
    tester,
  ) async {
    String? actor = 'account-a';
    final storage = _Storage();
    final preferences = SpaceIconPreferences(storage: storage);
    final controller = SpaceIconController(
      preferences: preferences,
      accountId: () => actor,
      namespace: 'space',
      id: 'id',
      validIconIds: spaceIconOptions.map((option) => option.id).toSet(),
    );
    await controller.load();
    await tester.pumpWidget(
      _app(
        SpaceIconPicker(
          controller: controller,
          spaceName: 'Test Space',
          fallbackIcon: CupertinoIcons.archivebox,
        ),
      ),
    );
    await _filter(tester, 'Gear');
    await tester.tap(_choice('gear'));
    actor = 'account-b';
    await controller.load();
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(
      find.text('Account changed. Close this picker and reopen it.'),
      findsOneWidget,
    );
    expect(storage.writes, 0);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    preferences.dispose();
  });

  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 2.6, 3.4]) {
      testWidgets(
        '${brightness.name} picker supports $scale text/keyboard at 320pt',
        (tester) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final prefs = SpaceIconPreferences(storage: _Storage());
          await tester.pumpWidget(
            _app(
              SpaceIconButton(
                spaceId: 'id',
                spaceName: 'A long Workshop Space name',
                preferences: prefs,
                accountId: () => 'account-a',
              ),
              brightness: brightness,
              scale: scale,
              keyboard: 180,
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(_leading('A long Workshop Space name'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          // Scrolling dismisses a real keyboard. Drop the injected inset to
          // model that transition before selecting a fully visible icon tile.
          await tester.pumpWidget(
            _app(
              SpaceIconButton(
                spaceId: 'id',
                spaceName: 'A long Workshop Space name',
                preferences: prefs,
                accountId: () => 'account-a',
              ),
              brightness: brightness,
              scale: scale,
            ),
          );
          await tester.pumpAndSettle();
          final scrollable = find
              .descendant(
                of: find.byType(SpaceIconPicker),
                matching: find.byType(Scrollable),
              )
              .first;
          await tester.scrollUntilVisible(
            _choice('star'),
            150,
            scrollable: scrollable,
          );
          await tester.tap(_choice('star'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final button = tester.widget<FilledButton>(find.byType(FilledButton));
          expect(button.onPressed, isNotNull);
          await tester.tap(find.text('Save icon'));
          await tester.pumpAndSettle();
          expect(find.byIcon(CupertinoIcons.star), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          prefs.dispose();
        },
      );
    }
  }

  testWidgets(
    'personal and view-only joined Space icons open without navigating',
    (tester) async {
      final api = _Api();
      await tester.pumpWidget(_app(InventoryPage(api: api, refreshToken: 0)));
      await tester.pumpAndSettle();
      for (final name in ['Workshop', 'Joined Space']) {
        await tester.scrollUntilVisible(
          _leading(name),
          100,
          scrollable: find
              .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.tap(_leading(name));
        await tester.pumpAndSettle();
        expect(find.byType(SpaceIconPicker), findsOneWidget);
        expect(find.byType(LocationItemsPage), findsNothing);
        await _filter(tester, 'Gear');
        await tester.tap(_choice('gear'));
        await tester.tap(find.text('Save icon'));
        await tester.pumpAndSettle();
      }
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(
          SpaceIconPreferences.keyFor(
            accountId: 'account-a',
            namespace: 'space',
            id: 'stable-id',
          ),
        ),
        'gear',
      );
      expect(
        prefs.getString(
          SpaceIconPreferences.keyFor(
            accountId: 'account-a',
            namespace: 'share',
            id: 'joined-id',
          ),
        ),
        'gear',
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Team viewer can personalize icon without entering or editing Space',
    (tester) async {
      await tester.pumpWidget(
        _app(TeamWorkspacePage(api: _Api(), initialTeamId: 'team-id')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Spaces'));
      await tester.pumpAndSettle();
      await tester.tap(_leading('Workshop'));
      await tester.pumpAndSettle();
      expect(find.byType(SpaceIconPicker), findsOneWidget);
      expect(find.byType(TeamSpaceInventoryPage), findsNothing);
      await _filter(tester, 'Gear');
      await tester.tap(_choice('gear'));
      await tester.tap(find.text('Save icon'));
      await tester.pumpAndSettle();
      expect(find.byIcon(CupertinoIcons.gear_alt), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
