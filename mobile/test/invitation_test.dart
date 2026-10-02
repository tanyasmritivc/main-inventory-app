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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/invitation.dart';
import 'package:mobile/features/sharing/invitation_dialog.dart';
import 'package:mobile/features/sharing/invitation_host.dart';
import 'package:mobile/features/sharing/share_space_sheet.dart';

String owner = 'recipient';
Map<String, dynamic> metadata = {};
Map<String, dynamic> user() => {
  'id': owner,
  'aud': 'authenticated',
  'role': 'authenticated',
  'email': 'test@example.test',
  'created_at': '2026-01-01T00:00:00Z',
  'app_metadata': {},
  'user_metadata': metadata,
};
String token() =>
    '${base64Url.encode(utf8.encode('{"alg":"HS256"}'))}.${base64Url.encode(utf8.encode(jsonEncode({'sub': owner, 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600})))}.signature';
Future<void> login([String id = 'recipient']) async {
  owner = id;
  await Supabase.instance.client.auth.signInWithPassword(
    email: 'test@example.test',
    password: 'test-password',
  );
}

class Api extends ApiClient {
  Api() : super(baseUrl: 'https://api.test');
  int joins = 0, creates = 0, inviteReads = 0, teamReads = 0;
  bool failPreview = false, failJoin = false;
  Completer<Map<String, dynamic>>? waitPreview;
  Map<String, dynamic> preview = {
    'name': 'Garage',
    'target_id': 'space-1',
    'permission': 'view',
    'already_joined': false,
  };
  @override
  Future<Map<String, dynamic>> previewInvitation(
    String kind,
    String code,
  ) async {
    if (failPreview) throw StateError('SECRET database failure');
    return waitPreview?.future ?? preview;
  }

  @override
  Future<Map<String, dynamic>> joinShare(String code) async {
    joins++;
    if (failJoin) throw StateError('SECRET write failure');
    return {
      'share_id': 'space-1',
      'share_name': 'Garage',
      'permission': 'view',
    };
  }

  @override
  Future<Map<String, dynamic>> joinTeam(String code) async {
    joins++;
    return {
      'membership': {'team_id': 'team-1', 'role': 'member'},
    };
  }

  @override
  Future<List<dynamic>> getMyShares() async => [];
  @override
  Future<List<dynamic>> getJoinedShares() async => [];
  @override
  Future<Map<String, dynamic>> createShare({
    required String shareName,
    required String permission,
  }) async {
    creates++;
    return {'share_id': 'space-1'};
  }

  @override
  Future<Map<String, dynamic>> getSpaceInvite(String shareId) async {
    inviteReads++;
    return {
      'share_id': 'space-1',
      'share_name': 'Garage',
      'permission': 'view',
      'share_code': 'ABC123',
    };
  }

  @override
  Future<Map<String, dynamic>> getTeamInvite(String teamId) async {
    teamReads++;
    return {'team_name': 'Robotics', 'join_code': 'TEAM23'};
  }
}

Invitation invite([String kind = 'space']) => Invitation(
  kind: kind,
  code: kind == 'team' ? 'TEAM23' : 'ABC123',
  createdAt: DateTime.now().millisecondsSinceEpoch,
);

class FailingInbox extends InvitationInbox {
  int binds = 0;
  @override
  Future<void> bind(String owner) async {
    binds++;
    throw StateError('Device storage unavailable');
  }
}

Future<void> openDialog(
  WidgetTester tester,
  Api api, [
  String kind = 'space',
  TextScaler? scale,
]) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: scale ?? TextScaler.noScaling),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showDialog(
              context: context,
              builder: (_) => InvitationDialog(
                api: api,
                invitation: invite(kind),
                userId: 'recipient',
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
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
      url: 'https://auth.test',
      anonKey: 'test',
      authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
      httpClient: MockClient((request) async {
        if (request.method == 'PUT') {
          metadata.addAll(
            Map<String, dynamic>.from(jsonDecode(request.body)['data']),
          );
        }
        final data = request.url.path.endsWith('/token')
            ? {
                'access_token': token(),
                'refresh_token': 'refresh-test',
                'expires_in': 3600,
                'token_type': 'bearer',
                'user': user(),
              }
            : request.url.path.endsWith('/user')
            ? user()
            : {};
        return http.Response(
          jsonEncode(data),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    metadata = {};
    await login();
  });
  test(
    'strict links accept only supported domains, schemes and exact routes',
    () {
      for (final url in [
        'https://www.findez.ai/join/abc123',
        'https://findez.ai/join?code=ABC123',
        'findez://space-invite?code=ABC123',
      ]) {
        expect(Invitation.fromUri(Uri.parse(url))?.kind, 'space');
      }
      expect(
        Invitation.fromUri(
          Uri.parse('https://www.findez.ai/join/team/TEAM23'),
        )?.kind,
        'team',
      );
      for (final url in [
        'http://findez.ai/join/ABC123',
        'https://evil.test/join/ABC123',
        'https://www.findez.ai.evil.test/join/ABC123',
        'https://user@findez.ai/join/ABC123',
        'https://findez.ai:8443/join/ABC123',
        'https://findez.ai/join/ABC123/more',
        'findez://space-invite?code=ABC!23',
        'findez://space-invite?code=ABC123456',
      ]) {
        expect(Invitation.fromUri(Uri.parse(url)), isNull, reason: url);
      }
    },
  );
  test(
    'metadata handoffs expire and cannot forge a role or malformed code',
    () {
      final valid = invite().toData();
      expect(
        Invitation.fromData({
          ...valid,
          'role': 'owner',
        })!.toData().containsKey('role'),
        isFalse,
      );
      expect(Invitation.fromData({...valid, 'code': 'ABC!23'}), isNull);
      expect(Invitation.fromData({...valid, 'kind': 'owner'}), isNull);
      expect(Invitation.fromData({...valid, 'created_at': 0}), isNull);
      expect(
        Invitation.fromData({
          ...valid,
          'created_at': DateTime.now()
              .add(const Duration(days: 1))
              .millisecondsSinceEpoch,
        }),
        isNull,
      );
    },
  );
  test(
    'inbox survives restart/sign-in and binds to the accepting account',
    () async {
      final first = InvitationInbox();
      await first.queue(invite());
      final restored = InvitationInbox();
      await restored.restore();
      expect(restored.availableFor('recipient'), isTrue);
      await restored.bind('recipient');
      final next = InvitationInbox();
      await next.restore();
      expect(next.availableFor('other'), isFalse);
      expect(next.availableFor('recipient'), isTrue);
      await next.clear(next.pending!);
      final cleared = InvitationInbox();
      await cleared.restore();
      expect(cleared.pending, isNull);
    },
  );
  test('consuming an old invitation cannot remove a newer one', () async {
    final inbox = InvitationInbox(), old = invite(), newer = invite('team');
    await inbox.queue(old);
    await inbox.queue(newer);
    await inbox.clear(old);
    expect(inbox.pending?.key, newer.key);
  });
  testWidgets('space preview never joins until the user chooses Join', (
    tester,
  ) async {
    final api = Api();
    await openDialog(tester, api);
    expect(find.text('Garage'), findsOneWidget);
    expect(find.text('Access: View only'), findsOneWidget);
    expect(api.joins, 0);
    await tester.tap(find.text('Join space'));
    await tester.pumpAndSettle();
    expect(api.joins, 1);
    expect(find.text('Garage'), findsNothing);
  });
  testWidgets('team preview and Not now never add membership', (tester) async {
    final api = Api();
    await openDialog(tester, api, 'team');
    expect(find.text('Join team'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(api.joins, 0);
  });
  testWidgets(
    'preview and accept failures are visible, scrubbed and retryable',
    (tester) async {
      final api = Api()..failPreview = true;
      await openDialog(tester, api);
      expect(find.textContaining('SECRET'), findsNothing);
      expect(find.text('Try again'), findsOneWidget);
      expect(api.joins, 0);
      api.failPreview = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      api.failJoin = true;
      await tester.tap(find.text('Join space'));
      await tester.pumpAndSettle();
      expect(find.textContaining('SECRET'), findsNothing);
      expect(find.text('Join space'), findsOneWidget);
    },
  );
  testWidgets('late preview data is discarded after account switch', (
    tester,
  ) async {
    final api = Api()..waitPreview = Completer();
    await tester.pumpWidget(
      MaterialApp(
        home: InvitationDialog(
          api: api,
          invitation: invite(),
          userId: 'recipient',
        ),
      ),
    );
    await tester.pump();
    await login('other');
    api.waitPreview!.complete({'name': 'PRIVATE LATE NAME'});
    await tester.pump();
    expect(find.text('PRIVATE LATE NAME'), findsNothing);
    expect(api.joins, 0);
  });
  testWidgets('dialog remains usable with large text and a long space name', (
    tester,
  ) async {
    final api = Api()
      ..preview['name'] =
          'Workshop with a long descriptive name for shared inventory';
    await openDialog(tester, api, 'space', TextScaler.linear(2));
    await tester.ensureVisible(find.text('Not now'));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'joined-space sharing uses the existing owner link, not createShare',
    (tester) async {
      final api = Api();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: ShareSpaceSheet(
              api: api,
              spaceName: 'Garage',
              shareId: 'space-1',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(api.inviteReads, 1);
      expect(api.creates, 0);
      expect(find.text('Create invitation link'), findsNothing);
      expect(find.text('Share link'), findsOneWidget);
      expect(find.text('https://www.findez.ai/join/ABC123'), findsOneWidget);
    },
  );
  testWidgets('team-space sharing uses the authorized Team invitation', (
    tester,
  ) async {
    final api = Api();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShareSpaceSheet(api: api, spaceName: 'Parts', teamId: 'team-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(api.teamReads, 1);
    expect(api.creates, 0);
    expect(api.inviteReads, 0);
    expect(find.text('https://www.findez.ai/join/team/TEAM23'), findsOneWidget);
  });
  testWidgets(
    'saved account invitation appears without granting access after sign-in',
    (tester) async {
      final api = Api(),
          key = GlobalKey<NavigatorState>(),
          links = StreamController<Uri>.broadcast();
      metadata[Invitation.metadataKey] = invite().toData();
      await login();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: key,
          theme: ThemeData.dark(),
          builder: (_, child) => InvitationHost(
            api: api,
            navigatorKey: key,
            ready: true,
            incomingLinks: links.stream,
            initialLink: () async => null,
            child: child!,
          ),
          home: const Scaffold(body: Text('Home')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Garage'), findsOneWidget);
      expect(api.joins, 0);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(find.text('Garage'), findsNothing);
      expect(metadata[Invitation.metadataKey], isNull);
      await tester.pumpWidget(const SizedBox());
      await links.close();
    },
  );

  testWidgets(
    'cold-start link waits for sign-in and duplicate warm links show one prompt',
    (tester) async {
      await tester.runAsync(
        () => Supabase.instance.client.auth.signOut(scope: SignOutScope.local),
      );
      final api = Api(),
          key = GlobalKey<NavigatorState>(),
          links = StreamController<Uri>.broadcast();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: key,
          theme: ThemeData.dark(),
          builder: (_, child) => InvitationHost(
            api: api,
            navigatorKey: key,
            ready: true,
            incomingLinks: links.stream,
            initialLink: () async =>
                Uri.parse('https://www.findez.ai/join/ABC123'),
            child: child!,
          ),
          home: const Scaffold(body: Text('Account entry')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Garage'), findsNothing);
      expect(api.joins, 0);
      final restored = InvitationInbox();
      await restored.restore();
      expect(restored.pending?.code, 'ABC123');
      await login();
      await tester.pumpAndSettle();
      expect(find.text('Garage'), findsOneWidget);
      links.add(Uri.parse('findez://space-invite?code=ABC123'));
      await tester.pumpAndSettle();
      expect(find.byType(InvitationDialog), findsOneWidget);
      expect(api.joins, 0);
      await tester.pumpWidget(const SizedBox());
      await links.close();
    },
  );

  testWidgets(
    'account switch dismisses a visible invitation without joining the other account',
    (tester) async {
      final api = Api(),
          key = GlobalKey<NavigatorState>(),
          links = StreamController<Uri>.broadcast();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: key,
          theme: ThemeData.dark(),
          builder: (_, child) => InvitationHost(
            api: api,
            navigatorKey: key,
            ready: true,
            incomingLinks: links.stream,
            initialLink: () async =>
                Uri.parse('findez://team-invite?code=TEAM23'),
            child: child!,
          ),
          home: const Scaffold(body: Text('Home')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(InvitationDialog), findsOneWidget);
      await login('other');
      await tester.pumpAndSettle();
      expect(find.byType(InvitationDialog), findsNothing);
      expect(api.joins, 0);
      await tester.pumpWidget(const SizedBox());
      await links.close();
    },
  );

  testWidgets('a storage failure does not loop or grant membership', (
    tester,
  ) async {
    final api = Api(),
        key = GlobalKey<NavigatorState>(),
        inbox = FailingInbox();
    final links = StreamController<Uri>.broadcast();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: key,
        builder: (_, child) => InvitationHost(
          api: api,
          navigatorKey: key,
          ready: true,
          inbox: inbox,
          incomingLinks: links.stream,
          initialLink: () async =>
              Uri.parse('findez://space-invite?code=ABC123'),
          child: child!,
        ),
        home: const Scaffold(body: Text('Home')),
      ),
    );
    await tester.pumpAndSettle();
    expect(inbox.binds, 1);
    expect(api.joins, 0);
    expect(find.byType(InvitationDialog), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await links.close();
  });

  testWidgets('invitation portrait visual acceptance', (tester) async {
    if (!const bool.fromEnvironment('FINDEZ_VISUAL_QA')) return;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = Api();
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('invite-qa'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark().copyWith(
            textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'FindEZQA'),
          ),
          home: Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: InvitationDialog(
                api: api,
                invitation: invite(),
                userId: 'recipient',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('invite-qa')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2),
          bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '/private/tmp/findez-invitation-dialog.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    expect(tester.takeException(), isNull);
  });
}
