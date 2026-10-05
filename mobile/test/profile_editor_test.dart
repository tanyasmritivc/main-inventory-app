import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/core/profile_store.dart';
import 'package:mobile/features/profile/profile_editor_page.dart';
import 'package:mobile/features/profile/profile_hub_page.dart';
import 'package:mobile/features/shell/home_navigation.dart';
import 'package:mobile/core/ui/member_avatar.dart';

const _url =
    'https://api.test/storage/v1/object/sign/profile-photos/owner/avatar.png';
String _photo([String token = 'first']) => '$_url?token=$token';

class _Api extends ApiClient {
  _Api() : super(baseUrl: 'https://api.test');
  Map<String, dynamic> data = {
    'user_id': 'owner',
    'display_name': 'Tanya',
    'email': 'averylongaccountaddress@example.com',
    'avatar_url': _photo(),
    'avatar_color': '#636366',
  };
  Completer<Map<String, dynamic>>? read;
  Completer<void>? save;
  bool failSave = false, failPhoto = false;
  int saves = 0, uploads = 0, deletes = 0;
  @override
  Future<Map<String, dynamic>> getMyProfile() async =>
      read == null ? Map.from(data) : read!.future;
  @override
  Future<void> updateProfile({
    String? displayName,
    String? contactEmail,
    String? avatarColor,
    String? organization,
    String? profileRole,
  }) async {
    saves++;
    if (failSave) throw StateError('SECRET save error');
    if (save != null) await save!.future;
    data.addAll({
      'display_name': displayName,
      'contact_email': contactEmail,
      'organization': organization,
      'profile_role': profileRole,
      'avatar_color': avatarColor,
    });
  }

  @override
  Future<String> uploadProfilePhoto({
    required List<int> bytes,
    required String filename,
  }) async {
    uploads++;
    if (failPhoto) throw StateError('SECRET upload');
    return data['avatar_url'] = _photo('replacement');
  }

  @override
  Future<void> deleteProfilePhoto() async {
    deletes++;
    if (failPhoto) throw StateError('SECRET delete');
    data['avatar_url'] = '';
  }
}

class _DelayedPhoto extends XFile {
  _DelayedPhoto() : super('photo.png');
  final bytes = Completer<Uint8List>();
  @override
  Future<Uint8List> readAsBytes() => bytes.future;
}

Widget _editor(
  _Api api,
  ProfileStore store, {
  Future<XFile?> Function()? picker,
  TextScaler? scaler,
  Brightness brightness = Brightness.dark,
}) => RepaintBoundary(
  key: const ValueKey('profile-qa'),
  child: MaterialApp(
    theme: AppTheme.create(brightness).copyWith(
      textTheme: AppTheme.create(brightness).textTheme.apply(
        fontFamily: const bool.fromEnvironment('FINDEZ_VISUAL_QA')
            ? 'FindEZQA'
            : null,
      ),
    ),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: scaler),
      child: child!,
    ),
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ProfileEditorPage(api: api, store: store, pickPhoto: picker),
            ),
          ),
          child: const Text('Open editor'),
        ),
      ),
    ),
  ),
);
Future<void> _open(
  WidgetTester tester,
  _Api api,
  ProfileStore store, {
  Future<XFile?> Function()? picker,
  TextScaler? scaler,
  Brightness brightness = Brightness.dark,
}) async {
  if (const bool.fromEnvironment('FINDEZ_VISUAL_QA')) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }
  await tester.pumpWidget(
    _editor(api, store, picker: picker, scaler: scaler, brightness: brightness),
  );
  await tester.tap(find.text('Open editor'));
  await tester.pumpAndSettle();
  if (const bool.fromEnvironment('FINDEZ_VISUAL_QA')) {
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('profile-qa')),
      );
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '/private/tmp/findez-profile-editor-qa.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }
}

Future<void> _save(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Save changes'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Save changes'));
  await tester.pumpAndSettle();
}

Future<void> _choose(WidgetTester tester, String choice) async {
  await tester.tap(find.text('Change photo'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(choice));
  await tester.pumpAndSettle();
}

void main() {
  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 2.6]) {
      testWidgets(
        '${brightness.name} profile editor supports $scale text at 320pt',
        (tester) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final api = _Api()..data['avatar_url'] = '';
          final store = ProfileStore(api: api, ownerId: () => 'owner');
          addTearDown(store.dispose);
          await _open(
            tester,
            api,
            store,
            brightness: brightness,
            scaler: TextScaler.linear(scale),
          );
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(find.text('Save changes'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(api.saves, 0);
          expect(find.byType(ColorFiltered), findsNothing);
        },
      );
    }
  }
  setUpAll(() async {
    if (const bool.fromEnvironment('FINDEZ_VISUAL_QA')) {
      final font = FontLoader('FindEZQA')
        ..addFont(
          File(
            '/System/Library/Fonts/SFNS.ttf',
          ).readAsBytes().then(ByteData.sublistView),
        );
      await font.load();
    }
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test',
      authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
      httpClient: MockClient((_) async => http.Response('{}', 200)),
    );
  });
  test('profile MIME and size match the unchanged upload contract', () {
    for (final ext in ['jpg', 'jpeg', 'png', 'webp', 'heic', 'heif']) {
      final file = profilePhotoMultipartFile(
        bytes: [1, 2],
        filename: '../secret.$ext',
      );
      expect(
        file.contentType.toString(),
        ext == 'jpg' || ext == 'jpeg' ? 'image/jpeg' : 'image/$ext',
      );
      expect(file.filename, 'avatar.$ext');
    }
    expect(
      () => profilePhotoMultipartFile(bytes: [], filename: 'a.png'),
      throwsFormatException,
    );
    expect(
      () => profilePhotoMultipartFile(
        bytes: Uint8List(5 * 1024 * 1024 + 1),
        filename: 'a.png',
      ),
      throwsFormatException,
    );
    expect(
      () => profilePhotoMultipartFile(bytes: [1], filename: 'a.svg'),
      throwsFormatException,
    );
  });
  test('avatars reject foreign owners, origins and non-image paths', () {
    String? check(String url, String? owner) => trustedProfilePhotoUrl(
      url,
      owner: owner,
      origins: ['https://api.test'],
    );
    expect(check(_photo(), 'owner'), _photo());
    expect(check(_photo(), null), isNull);
    expect(check(_photo(), 'other'), isNull);
    expect(
      check(_photo().replaceFirst('api.test', 'evil.test'), 'owner'),
      isNull,
    );
    expect(check(_photo().replaceFirst('https:', 'http:'), 'owner'), isNull);
    expect(
      check(_photo().replaceFirst('avatar.png', 'page.svg'), 'owner'),
      isNull,
    );
  });
  test(
    'account changes and late reads cannot restore a previous profile',
    () async {
      String? owner = 'owner';
      final api = _Api()..read = Completer();
      final store = ProfileStore(api: api, ownerId: () => owner);
      addTearDown(store.dispose);
      final read = store.load();
      owner = 'other';
      api.read!.complete(api.data);
      await read;
      expect(store.name, isEmpty);
      expect(store.photoUrl, isEmpty);
      api.read = null;
      api.data = {'user_id': 'other', 'display_name': 'Other'};
      await store.load(force: true);
      expect(store.name, 'Other');
      owner = null;
      expect(store.name, isEmpty);
      expect(store.photoUrl, isEmpty);
    },
  );
  test('a confirmed photo update wins over an older read', () async {
    final api = _Api()..read = Completer();
    final store = ProfileStore(api: api, ownerId: () => 'owner');
    addTearDown(store.dispose);
    final pending = store.load();
    store.applySaved({'avatar_url': _photo('new')}, forOwner: 'owner');
    api.read!.complete(api.data);
    await pending;
    expect(store.photoUrl, _photo('new'));
    expect(store.photoRevision, 1);
  });
  testWidgets('labeled form saves actual fields and returns to its caller', (
    tester,
  ) async {
    final api = _Api();
    final store = ProfileStore(api: api, ownerId: () => 'owner');
    addTearDown(store.dispose);
    await _open(tester, api, store);
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Save'), findsNothing);
    await tester.enterText(find.byType(TextFormField).at(0), 'Tanya Charles');
    await tester.enterText(find.byType(TextFormField).at(1), 'Workshop');
    await _save(tester);
    expect(api.data['display_name'], 'Tanya Charles');
    expect(api.data['organization'], 'Workshop');
    expect(store.name, 'Tanya Charles');
    expect(find.text('Open editor'), findsOneWidget);
  });
  testWidgets(
    'validation and failed saves keep user edits and never claim success',
    (tester) async {
      final api = _Api();
      final store = ProfileStore(api: api, ownerId: () => 'owner');
      addTearDown(store.dispose);
      await _open(tester, api, store);
      await tester.enterText(find.byType(TextFormField).first, '');
      await _save(tester);
      expect(api.saves, 0);
      expect(find.text('Enter your name.'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, 'Keep draft');
      await tester.enterText(find.byType(TextFormField).last, 'invalid');
      await _save(tester);
      expect(api.saves, 0);
      expect(find.text('Enter a valid email.'), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField).last,
        'contact@example.com',
      );
      api.failSave = true;
      await _save(tester);
      expect(find.text('Keep draft'), findsOneWidget);
      expect(store.name, 'Tanya');
      expect(find.textContaining('SECRET'), findsNothing);
      expect(find.text('Profile updated'), findsNothing);
    },
  );
  testWidgets('unsaved back navigation requires an explicit discard', (
    tester,
  ) async {
    final api = _Api();
    final store = ProfileStore(api: api, ownerId: () => 'owner');
    addTearDown(store.dispose);
    await _open(tester, api, store);
    await tester.enterText(find.byType(TextFormField).first, 'Unsaved');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Unsaved'), findsOneWidget);
    expect(api.saves, 0);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('Open editor'), findsOneWidget);
    expect(api.saves, 0);
  });
  testWidgets('replace and remove update shared avatars without losing drafts', (
    tester,
  ) async {
    final api = _Api();
    final store = ProfileStore(api: api, ownerId: () => 'owner');
    addTearDown(store.dispose);
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4nGNgAAAAAgABSK+kcQAAAABJRU5ErkJggg==',
    );
    await _open(
      tester,
      api,
      store,
      picker: () async => XFile.fromData(png, name: 'photo.png'),
    );
    await tester.enterText(find.byType(TextFormField).first, 'Unsaved name');
    await _choose(tester, 'Choose photo');
    expect(store.photoUrl, _photo('replacement'));
    expect(api.uploads, 1);
    expect(find.text('Unsaved name'), findsOneWidget);
    api.failPhoto = true;
    await _choose(tester, 'Remove photo');
    expect(store.photoUrl, _photo('replacement'));
    expect(find.textContaining('SECRET'), findsNothing);
    api.failPhoto = false;
    await _choose(tester, 'Remove photo');
    expect(store.photoUrl, isEmpty);
    expect(find.text('Unsaved name'), findsOneWidget);
  });
  testWidgets('overview and nav use the saved photo and replacement revision', (
    tester,
  ) async {
    final api = _Api();
    final store = ProfileStore(api: api, ownerId: () => 'owner');
    addTearDown(store.dispose);
    await store.load();
    Future<void> noop() async {}
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: ListenableBuilder(
          listenable: store,
          builder: (_, _) => Scaffold(
            body: ProfileHubPage(
              api: api,
              store: store,
              onOpenProfile: noop,
              onOpenSettings: noop,
              onOpenDocuments: noop,
              onOpenNotifications: noop,
              onOpenCheckouts: noop,
              onOpenTour: noop,
            ),
            bottomNavigationBar: HomeNavigation(
              selectedIndex: 4,
              onSelected: (_) {},
              profileAvatar: MemberAvatar(
                key: ValueKey(store.photoRevision),
                name: store.name,
                photoUrl: store.photoUrl,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsWidgets);
    store.applySaved({'avatar_url': _photo('changed')}, forOwner: 'owner');
    await tester.pumpAndSettle();
    for (final widget in tester.widgetList<Image>(find.byType(Image))) {
      expect((widget.image as NetworkImage).url, _photo('changed'));
    }
  });
  testWidgets('an account change while photo bytes load prevents upload', (
    tester,
  ) async {
    String? owner = 'owner';
    final api = _Api();
    final store = ProfileStore(api: api, ownerId: () => owner);
    addTearDown(store.dispose);
    final file = _DelayedPhoto();
    await _open(tester, api, store, picker: () async => file);
    await _choose(tester, 'Choose photo');
    owner = 'other';
    api.data = {'user_id': owner, 'display_name': 'Other account'};
    await store.load(force: true);
    file.bytes.complete(Uint8List.fromList([1, 2]));
    await tester.pumpAndSettle();
    expect(api.uploads, 0);
    expect(store.photoUrl, isEmpty);
    expect(find.text('Tanya'), findsNothing);
    expect(find.text('Other account'), findsOneWidget);
  });
  testWidgets(
    'pending profile saves cannot submit twice or discard mid-write',
    (tester) async {
      final api = _Api()..save = Completer<void>();
      final store = ProfileStore(api: api, ownerId: () => 'owner');
      addTearDown(store.dispose);
      await _open(tester, api, store);
      await tester.enterText(find.byType(TextFormField).first, 'Updated name');
      await tester.ensureVisible(find.text('Save changes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes'));
      await tester.pump();
      expect(api.saves, 1);
      final saving = tester.widget<FilledButton>(
        find.byType(FilledButton).last,
      );
      expect(saving.onPressed, isNull);
      await tester.tap(find.byType(BackButton));
      await tester.pump();
      expect(find.byType(ProfileEditorPage), findsOneWidget);
      expect(find.text('Discard changes?'), findsNothing);
      api.save!.complete();
      await tester.pumpAndSettle();
      expect(store.name, 'Updated name');
      expect(find.byType(ProfileEditorPage), findsNothing);
    },
  );
  testWidgets('narrow keyboard and large text keep fields and save reachable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final api = _Api();
    final store = ProfileStore(api: api, ownerId: () => 'owner');
    addTearDown(store.dispose);
    await _open(tester, api, store, scaler: const TextScaler.linear(2));
    await tester.ensureVisible(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.getBottomLeft(find.text('Save changes')).dy, lessThan(328));
  });
}
