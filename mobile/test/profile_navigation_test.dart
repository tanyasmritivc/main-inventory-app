import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/core/ui/app_typography.dart';
import 'package:mobile/core/inventory_cache.dart';
import 'package:mobile/core/pro_status.dart';
import 'package:mobile/features/inventory/inventory_page.dart';
import 'package:mobile/features/profile/profile_hub_page.dart';
import 'package:mobile/features/profile/profile_page.dart';
import 'package:mobile/features/profile/profile_editor_page.dart';
import 'package:mobile/features/shell/main_shell.dart';
import 'package:mobile/features/scan/scan_page.dart';

int _deleteRequests = 0;

Future<void> Function(String)? releaseAuditCapture;

class _ProfileApi extends ApiClient {
  _ProfileApi({this.fail = false, this.pending})
    : super(baseUrl: 'https://api.test');
  bool fail;
  final Completer<Map<String, dynamic>>? pending;
  int profiles = 0;
  int limits = 0;
  Map<String, dynamic>? update;
  @override
  Future<SearchItemsResult> searchItems({required String query}) async =>
      SearchItemsResult(items: [], parsed: const {});
  @override
  Future<ReviewQueueResult> getReviewItems({int limit = 100}) async =>
      const ReviewQueueResult(items: [], pendingCount: 0);
  @override
  Future<List<Map<String, dynamic>>> listSpaces() async => [];
  @override
  Future<List<dynamic>> getMyShares() async => [];
  @override
  Future<List<dynamic>> getJoinedShares() async => [];
  @override
  Future<List<Map<String, dynamic>>> getActiveCheckouts() async => [];
  @override
  Future<Map<String, dynamic>> getNotifications() async => {'unread_count': 0};
  @override
  Future<Map<String, dynamic>> getMyProfile() async {
    profiles++;
    if (pending != null) return pending!.future;
    if (fail) throw StateError('SECRET profile stack');
    return {
      'display_name': 'Tanya',
      'avatar_color': 'malformed',
      'organization': 'Workshop',
    };
  }

  @override
  Future<Map<String, dynamic>> getMyLimits() async {
    limits++;
    return {'tier': 'pro', 'pilot_mode': false};
  }

  @override
  Future<void> updateProfile({
    String? displayName,
    String? contactEmail,
    String? avatarColor,
    String? organization,
    String? profileRole,
  }) async {
    if (fail) throw StateError('SECRET profile write');
    update = {
      'display_name': displayName,
      'contact_email': contactEmail,
      'organization': organization,
      'profile_role': profileRole,
    };
  }
}

class _InventoryAppearanceApi extends _ProfileApi {
  @override
  Future<SearchItemsResult> searchItems({required String query}) async =>
      SearchItemsResult(
        items: [
          InventoryItem(
            itemId: 'restock-test',
            name: 'Sample masonry bit with a long descriptive name',
            category: 'Tools',
            location: 'Sample Workshop',
            quantity: 0,
            createdAt: DateTime(2026, 10, 4),
          ),
        ],
        parsed: const {},
      );

  @override
  Future<List<Map<String, dynamic>>> listSpaces() async => [
    {'id': 'empty', 'name': 'Empty Test', 'item_count': 0},
    {'id': 'sample', 'name': 'Sample Workshop', 'item_count': 1},
  ];

  @override
  Future<List<dynamic>> getMyShares() async => [];
  @override
  Future<List<dynamic>> getJoinedShares() async => [];
}

class _PilotProfileApi extends _ProfileApi {
  _PilotProfileApi(this.notice);
  final String? notice;

  @override
  Future<Map<String, dynamic>> getMyLimits() async => {
    'tier': 'free',
    'pilot_mode': true,
    'pilot_notice': notice,
  };
}

class _NotificationRaceApi extends _ProfileApi {
  final firstCount = Completer<Map<String, dynamic>>();
  int reads = 0;
  int writes = 0;
  @override
  Future<Map<String, dynamic>> getNotifications() async {
    if (++reads == 1) return firstCount.future;
    return {
      'unread_count': writes == 0 ? 1 : 0,
      'notifications': [
        {'display_text': 'A teammate joined.', 'is_read': writes > 0},
      ],
    };
  }

  @override
  Future<void> markNotificationsRead() async {
    writes++;
  }
}

Widget _hub(
  _ProfileApi api,
  List<String> opened, {
  TextScaler scaler = TextScaler.noScaling,
  Brightness brightness = Brightness.dark,
}) => MaterialApp(
  theme: AppTheme.create(brightness),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: scaler),
    child: child!,
  ),
  home: Scaffold(
    body: ProfileHubPage(
      api: api,
      unreadCount: 3,
      onOpenProfile: () async => opened.add('profile'),
      onOpenSettings: () async => opened.add('settings'),
      onOpenDocuments: () async => opened.add('documents'),
      onOpenNotifications: () async => opened.add('notifications'),
      onOpenCheckouts: () async => opened.add('checkouts'),
      onOpenTour: () async => opened.add('tour'),
    ),
  ),
);

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      '${brightness.name} confirmed Capture returns to Items, partial refresh stays in Capture',
      (tester) async {
        final api = _ProfileApi();
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.create(brightness),
            home: MainShell(api: api),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(NavigationDestination).at(1));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        final capture = tester.widget<ScanPage>(find.byType(ScanPage));
        capture.onSaved();
        await tester.pump(const Duration(milliseconds: 500));
        expect(
          tester
              .widget<NavigationBar>(find.byType(NavigationBar))
              .selectedIndex,
          1,
        );
        capture.onCaptureCompleted!('Garage');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<NavigationBar>(
                find.byType(NavigationBar, skipOffstage: false),
              )
              .selectedIndex,
          3,
        );
        expect(
          tester.widget<LocationItemsPage>(find.byType(LocationItemsPage)).api,
          same(api),
        );
        expect(
          tester
              .widget<LocationItemsPage>(find.byType(LocationItemsPage))
              .location,
          'Garage',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  if (const bool.fromEnvironment('FINDEZ_VISUAL_QA')) {
    testWidgets(
      'Home and Account renders keep identical weights with OS Bold Text',
      (tester) async {
        await tester.runAsync(() async {
          await (FontLoader('FindEZQA')..addFont(
                File(
                  '/System/Library/Fonts/SFNS.ttf',
                ).readAsBytes().then(ByteData.sublistView),
              ))
              .load();
          await (FontLoader('MaterialIcons')
                ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
              .load();
          await (FontLoader('packages/cupertino_icons/CupertinoIcons')..addFont(
                rootBundle.load(
                  'packages/cupertino_icons/assets/CupertinoIcons.ttf',
                ),
              ))
              .load();
        });
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        Future<List<int>> render(String name) async {
          late List<int> bytes;
          await tester.runAsync(() async {
            final image = await tester
                .renderObject<RenderRepaintBoundary>(
                  find.byKey(const Key('account-qa')),
                )
                .toImage(pixelRatio: 2);
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            bytes = data!.buffer.asUint8List();
            await File('/private/tmp/$name.png').writeAsBytes(bytes);
            image.dispose();
          });
          return bytes;
        }

        for (final brightness in Brightness.values) {
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              FakeAccessibilityFeatures(boldText: false);
          final theme = AppTheme.create(brightness);
          await tester.pumpWidget(
            RepaintBoundary(
              key: const Key('account-qa'),
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: theme.copyWith(
                  listTileTheme: theme.listTileTheme.copyWith(
                    titleTextStyle: theme.listTileTheme.titleTextStyle
                        ?.copyWith(fontFamily: 'FindEZQA'),
                    subtitleTextStyle: theme.listTileTheme.subtitleTextStyle
                        ?.copyWith(fontFamily: 'FindEZQA'),
                  ),
                  textTheme: theme.textTheme.apply(fontFamily: 'FindEZQA'),
                  primaryTextTheme: theme.primaryTextTheme.apply(
                    fontFamily: 'FindEZQA',
                  ),
                  appBarTheme: theme.appBarTheme.copyWith(
                    titleTextStyle: theme.appBarTheme.titleTextStyle?.copyWith(
                      fontFamily: 'FindEZQA',
                    ),
                  ),
                ),
                builder: (_, child) => AppTypography(child: child!),
                home: SafeArea(child: MainShell(api: _ProfileApi())),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final normal = await render('findez-home-account-${brightness.name}');
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              FakeAccessibilityFeatures(boldText: true);
          await tester.pumpAndSettle();
          final bold = await render(
            'findez-home-account-${brightness.name}-bold',
          );
          expect(bold, orderedEquals(normal));
          await tester.tap(find.byTooltip('Account'));
          await tester.pumpAndSettle();
          await render('findez-account-hub-${brightness.name}');
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        }
      },
    );
  }
  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 2.6, 3.4]) {
      testWidgets(
        '${brightness.name} populated Spaces support $scale text at 320pt',
        (tester) async {
          InventoryCache.clear();
          SharedPreferences.setMockInitialValues({
            'low_stock_thresholds:signed-out': '{"restock-test":3}',
          });
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.create(brightness),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: InventoryPage(
                api: _InventoryAppearanceApi(),
                refreshToken: 0,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('1 to buy | 0 on order'), findsOneWidget);
          expect(tester.takeException(), isNull);
          final scrollable = find
              .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable),
              )
              .first;
          for (final label in [
            'Empty Test',
            'Sample Workshop',
            '1 to buy',
            'New Space',
          ]) {
            await tester.scrollUntilVisible(
              find.text(label),
              100,
              scrollable: scrollable,
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: '$scale / $label');
          }
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
  for (final brightness in Brightness.values) {
    testWidgets('${brightness.name} all four tabs support large text at 320pt', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 62, bottom: 34);
      tester.view.viewPadding = const FakeViewPadding(top: 62, bottom: 34);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.create(brightness),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2.6)),
            child: RepaintBoundary(
              key: const Key('release-audit-frame'),
              child: child!,
            ),
          ),
          home: MainShell(api: _ProfileApi()),
        ),
      );
      await tester.pumpAndSettle();
      for (final index in [0, 1, 2, 3]) {
        await tester.tap(find.byType(NavigationDestination).at(index));
        // Capture's intentional shimmer never settles; allow route/read frames.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(
          tester.takeException(),
          isNull,
          reason: '${brightness.name} tab $index',
        );
        expect(
          tester
              .widget<NavigationBar>(find.byType(NavigationBar))
              .selectedIndex,
          index,
        );
        if (releaseAuditCapture != null) {
          // Paint the page fade's final frame; Capture's shimmer never settles.
          await tester.pump(const Duration(milliseconds: 300));
          await releaseAuditCapture!('tab-${brightness.name}-$index');
        }
      }
      await tester.tap(find.byType(NavigationDestination).at(0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byTooltip('Account').hitTestable(), findsOneWidget);
      await tester.tap(find.byTooltip('Account'));
      await tester.pumpAndSettle();
      expect(find.text('Account'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(tester.takeException(), isNull);
      await releaseAuditCapture?.call('account-${brightness.name}');
      await tester.pumpWidget(const SizedBox());
    });
  }
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-anon-key',
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/delete-user')) _deleteRequests++;
        return http.Response('{}', 200);
      }),
    );
  });

  setUp(() {
    _deleteRequests = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.findez.app/push'),
          (_) async => null,
        );
  });

  for (final brightness in Brightness.values) {
    for (final serverNotice in [true, false]) {
      for (final scale in [1.0, 2.6, 3.4]) {
        testWidgets(
          '${brightness.name} plans hidden with ${serverNotice ? 'API' : 'fallback'} notice at $scale text',
          (tester) async {
            SharedPreferences.setMockInitialValues({});
            ProStatus.reset();
            tester.view.physicalSize = const Size(320, 568);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            const notice =
                'Free Pilot: Unlimited access through November 1, 2026. '
                'Standard free-plan limits and optional paid plans begin November 2. '
                'You will not be charged automatically.';
            await tester.pumpWidget(
              MaterialApp(
                theme: AppTheme.create(brightness),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: ProfilePage(
                  api: _PilotProfileApi(serverNotice ? notice : null),
                  settingsOnly: true,
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.text('Plans'), findsNothing);
            expect(find.text('Free Pilot'), findsNothing);
            expect(find.textContaining('begin November 2'), findsNothing);
            expect(find.text('Appearance'), findsOneWidget);
            expect(ProStatus.isPilotMode, isTrue);
            expect(ProStatus.isPro, isFalse);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
            ProStatus.reset();
          },
        );
      }
    }
  }

  testWidgets(
    'account utilities retain their summary without a navigation tab',
    (tester) async {
      await tester.pumpWidget(_hub(_ProfileApi(), []));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('Account'), findsOneWidget);
      expect(find.text('Tanya'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('More'), findsNothing);
      expect(find.byType(Image), findsNothing);
      final settingsSurface = tester.widget<Material>(
        find
            .ancestor(
              of: find.text('Settings'),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(settingsSurface.color, AppTheme.darkSurface);
      expect(settingsSurface.clipBehavior, Clip.antiAlias);
    },
  );

  testWidgets('all profile utilities open their existing destinations', (
    tester,
  ) async {
    final opened = <String>[];
    final api = _ProfileApi();
    await tester.pumpWidget(_hub(api, opened));
    await tester.pumpAndSettle();
    for (final title in [
      'Edit profile',
      'Settings',
      'Documents and notes',
      'Notifications',
      'Lent items',
      'Setup questions',
    ]) {
      await tester.ensureVisible(find.text(title));
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
    }
    expect(opened, [
      'profile',
      'settings',
      'documents',
      'notifications',
      'checkouts',
      'tour',
    ]);
    expect(
      api.profiles,
      2,
    ); // Refresh account summary after the editor returns.
  });

  testWidgets(
    'Home account control opens settings and profile, then returns to four tabs',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: MainShell(api: _ProfileApi()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Where are my cables?');
      await tester.tap(find.byTooltip('Account'));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileHubPage, skipOffstage: false), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Scanning'), 150);
      expect(find.text('Scanning'), findsOneWidget);
      expect(
        tester.widget<ProfilePage>(find.byType(ProfilePage)).settingsOnly,
        isTrue,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit profile'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ProfilePage>(find.byType(ProfilePage)).accountOnly,
        isTrue,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0,
      );
      expect(
        tester
            .widget<NavigationBar>(find.byType(NavigationBar))
            .destinations
            .length,
        4,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Where are my cables?',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox()); // Dispose shell polling timer.
    },
  );

  testWidgets(
    'an old shell count cannot restore an unread badge after an inbox write',
    (tester) async {
      final api = _NotificationRaceApi();
      await tester.pumpWidget(MaterialApp(home: MainShell(api: api)));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Notifications'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ProfileHubPage>(
              find.byType(ProfileHubPage, skipOffstage: false),
            )
            .unreadCount,
        1,
      );
      await tester.tap(find.byTooltip('Mark all as read'));
      await tester.pumpAndSettle();
      expect(api.writes, 1);
      api.firstCount.complete({'unread_count': 7});
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ProfileHubPage>(
              find.byType(ProfileHubPage, skipOffstage: false),
            )
            .unreadCount,
        0,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        tester.widget<ProfileHubPage>(find.byType(ProfileHubPage)).unreadCount,
        0,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('profile failure is safe and retry restores real details', (
    tester,
  ) async {
    final api = _ProfileApi(fail: true);
    await tester.pumpWidget(_hub(api, []));
    await tester.pumpAndSettle();
    expect(find.text('Could not load profile.'), findsOneWidget);
    expect(find.textContaining('SECRET'), findsNothing);
    api.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Tanya'), findsOneWidget);
    expect(find.text('Could not load profile.'), findsNothing);
  });

  testWidgets('a disposed hub ignores a late profile read', (tester) async {
    final pending = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(_hub(_ProfileApi(pending: pending), []));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    pending.complete({'display_name': 'Previous account'});
    await tester.pumpAndSettle();
    expect(find.text('Previous account'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'profile and settings modes avoid duplicated account/settings content',
    (tester) async {
      final api = _ProfileApi();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: ProfilePage(api: api, accountOnly: true),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tanya'), findsOneWidget);
      expect(find.text('Scanning'), findsNothing);
      expect(api.limits, 0);
      expect(
        tester.takeException(),
        isNull,
      ); // Invalid avatar color uses safe fallback.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: ProfilePage(api: api, settingsOnly: true),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        api.profiles,
        1,
      ); // Settings does not reread hidden profile details.
      expect(find.text('Edit'), findsNothing);
      await tester.scrollUntilVisible(find.text('Scanning'), 150);
      expect(find.text('Scanning'), findsOneWidget);
      expect(find.text('Confirm before saving'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Sign out'), 300);
      expect(find.text('Sign out'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Delete account'), 200);
      expect(find.text('Delete account'), findsOneWidget);
    },
  );

  testWidgets('profile details still save through the existing API', (
    tester,
  ) async {
    final api = _ProfileApi();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: ProfilePage(api: api, accountOnly: true),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Tanya Charles');
    await tester.ensureVisible(find.text('Save changes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(api.update?['display_name'], 'Tanya Charles');
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed profile save is visible and retains input', (
    tester,
  ) async {
    final api = _ProfileApi();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: ProfilePage(api: api, accountOnly: true),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Keep this name');
    api.fail = true;
    await tester.ensureVisible(find.text('Save changes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(find.text('Keep this name'), findsOneWidget);
    expect(find.text('Save changes'), findsOneWidget);
    expect(find.textContaining('Couldn\'t save profile'), findsOneWidget);
  });

  testWidgets(
    'profile photo picker denial shows a safe error without losing details',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: ProfileEditorPage(
            api: _ProfileApi(),
            pickPhoto: () async => throw PlatformException(
              code: 'photo_access_denied',
              message: 'SECRET picker detail',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Change photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose photo'));
      await tester.pumpAndSettle();
      expect(find.textContaining('SECRET'), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Tanya'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'delete account still requires confirmation and cancellation makes no write',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: ProfilePage(api: _ProfileApi(), settingsOnly: true),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Delete account'), 300);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete account'));
      await tester.pumpAndSettle();
      expect(find.textContaining('permanently deletes'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(_deleteRequests, 0);
    },
  );

  testWidgets(
    'account utilities stay scrollable with large text on a narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _hub(_ProfileApi(), [], scaler: const TextScaler.linear(2)),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Setup questions'),
        150,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.getBottomLeft(find.text('Setup questions')).dy,
        lessThanOrEqualTo(568),
      );
      expect(find.byType(NavigationBar), findsNothing);
    },
  );
}
