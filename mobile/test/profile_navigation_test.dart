import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/features/profile/profile_hub_page.dart';
import 'package:mobile/features/profile/profile_page.dart';
import 'package:mobile/features/shell/home_navigation.dart';
import 'package:mobile/features/shell/main_shell.dart';

int _deleteRequests = 0;

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

Widget _hub(
  _ProfileApi api,
  List<String> opened, {
  TextScaler scaler = TextScaler.noScaling,
}) => MaterialApp(
  theme: ThemeData.dark(),
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
    bottomNavigationBar: HomeNavigation(selectedIndex: 4, onSelected: (_) {}),
  ),
);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key',
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

  testWidgets('profile destination retains rounded pill and selected circle', (
    tester,
  ) async {
    await tester.pumpWidget(_hub(_ProfileApi(), []));
    await tester.pumpAndSettle();
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 4);
    expect(bar.destinations.length, 5);
    final profile = bar.destinations.last as NavigationDestination;
    expect((profile.icon as Icon).icon, CupertinoIcons.person_crop_circle);
    expect(
      (profile.selectedIcon as Icon).icon,
      CupertinoIcons.person_crop_circle_fill,
    );
    expect(find.text('Tanya'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('More'), findsNothing);
    expect(find.byType(Image), findsNothing);
    final settingsSurface = tester.widget<Material>(
      find
          .ancestor(of: find.text('Settings'), matching: find.byType(Material))
          .first,
    );
    expect(settingsSurface.color, const Color(0xFF171719));
    expect(settingsSurface.clipBehavior, Clip.antiAlias);
  });

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
      'App tour',
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
    'shell routes Profile to settings and back without changing tab order',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: MainShell(api: _ProfileApi()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileHubPage), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        4,
      );
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
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
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox()); // Dispose shell polling timer.
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
      expect(find.text('Scanning'), findsOneWidget);
      expect(find.text('Confirm before saving'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
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
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Tanya Charles');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(api.update?['display_name'], 'Tanya Charles');
    expect(find.text('Tanya Charles'), findsOneWidget);
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
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Keep this name');
    api.fail = true;
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Keep this name'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.textContaining('Couldn\'t save profile'), findsOneWidget);
  });

  testWidgets(
    'profile photo picker denial shows a safe error without losing details',
    (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/image_picker'),
            (_) async => throw PlatformException(
              code: 'photo_access_denied',
              message: 'SECRET picker detail',
            ),
          );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: ProfilePage(api: _ProfileApi(), accountOnly: true),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Edit profile photo'));
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
      await tester.ensureVisible(find.text('Delete account'));
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
    'five-tab pill and profile stay scrollable with large text on a narrow screen',
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
        find.text('App tour'),
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
        tester.getBottomLeft(find.text('App tour')).dy,
        lessThan(tester.getTopLeft(find.byType(HomeNavigation)).dy),
      );
    },
  );
}
