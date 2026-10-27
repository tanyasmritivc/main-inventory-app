import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/inventory_context.dart';
import 'package:mobile/features/auth/auth_page.dart';
import 'package:mobile/features/onboarding/scan_entry.dart';
import 'package:mobile/features/scan/photo_scan_session.dart';
import 'package:mobile/features/scan/scan_camera_page.dart';
import 'package:mobile/features/scan/scan_destination.dart';
import 'package:mobile/features/scan/scan_experience.dart';
import 'package:mobile/features/world/world_composer.dart';
import 'support/hierarchy_fixture.dart';

class FakeScanCamera implements ScanCameraSource {
  int opened = 0, disposed = 0, captures = 0;
  bool denied = false;
  Completer<Uint8List>? pending;
  @override
  Future<void> open() async {
    opened++;
    if (denied) throw StateError('Denied');
  }

  @override
  Future<void> dispose() async {
    disposed++;
  }

  @override
  Future<Uint8List> capture() async {
    captures++;
    return pending?.future ?? frame();
  }

  @override
  Widget preview() =>
      const ColoredBox(color: Colors.grey, child: Text('Camera preview'));
}

Uint8List frame({bool dark = false}) {
  final image = img.Image(width: 200, height: 200);
  for (var y = 0; y < 200; y++) {
    for (var x = 0; x < 200; x++) {
      final n = dark
          ? 2
          : (x ~/ 8 + y ~/ 8) % 2 == 0
          ? 50
          : 210;
      image.setPixelRgb(x, y, n, n, n);
    }
  }
  return Uint8List.fromList(img.encodeJpg(image));
}

ExtractedInventoryItem detection({
  String name = 'Battery charger',
  int count = 1,
  bool review = false,
}) => ExtractedInventoryItem(
  name: name,
  category: 'Electronics',
  quantity: count,
  brand: 'Example',
  partNumber: 'C100',
  scanEvidence: ScanEvidence(
    quantityBasis: review ? 'unknown' : 'visible_individuals',
    identityConfidence: .99,
    quantityConfidence: .99,
    needsReview: review,
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fixture = HierarchyFixture();
  late ApiClient scoped;
  setUpAll(fixture.initialize);
  tearDownAll(() => Supabase.instance.dispose());
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    fixture.requests.clear();
    fixture.status = 200;
    await fixture.signIn('actor-a');
    scoped = ApiClient.forInventory(
      fixture.api,
      InventoryContext.fromJson(
        inventory('inventory-a'),
        accountId: 'actor-a',
        expectedInventory: 'inventory-a',
      ),
      isCurrent: () => true,
    );
    fixture.respond = (_) => {'items': [], 'parsed': {}};
  });

  test('onboarding intent binds to exactly one account', () async {
    await ScanEntryStore.choose('team');
    expect((await ScanEntryStore.claim('actor-a'))?['path'], 'team');
    expect(await ScanEntryStore.claim('actor-b'), isNull);
    expect((await ScanEntryStore.claim('actor-a'))?['owner'], 'actor-a');
  });
  testWidgets(
    'personal/team precedes authentication without camera permission',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ScanEntryPage()));
      expect(find.text('Personal'), findsOneWidget);
      expect(find.byType(AuthPage), findsNothing);
      await tester.tap(find.text('Team'));
      await tester.pumpAndSettle();
      expect(find.byType(AuthPage), findsOneWidget);
      expect(find.text('Memory for physical things.'), findsOneWidget);
      expect(fixture.requests, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('personal opens its existing gate without provisioning', (
    tester,
  ) async {
    await ScanEntryStore.choose('personal');
    await tester.pumpWidget(
      MaterialApp(
        home: ScanSetupGate(api: fixture.api, child: const Text('Ask')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ask'), findsOneWidget);
    expect(fixture.requests, isEmpty);
    expect((await ScanEntryStore.claim('actor-a'))?['complete'], isTrue);
  });
  testWidgets('team starts with organization name after auth', (tester) async {
    await ScanEntryStore.choose('team');
    await tester.pumpWidget(
      MaterialApp(
        home: ScanSetupGate(api: fixture.api, child: const Text('Ask')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Create your organization'), findsOneWidget);
    expect(find.text('Ask'), findsNothing);
    expect(fixture.requests, isEmpty);
  });
  test(
    'repeated photos do not sum counts; restored receipts keep identity',
    () async {
      final session = PhotoScanSession(scoped, 'space-a', 'Bench');
      await session.accept([detection()]);
      final id = session.rows.single.requestId;
      expect(
        await session.accept([
          detection(name: 'Example C100 charger', count: 2),
        ]),
        isEmpty,
      );
      expect(session.rows.single.item.quantity, 1);
      final restored = PhotoScanSession(scoped, 'space-a', 'Bench');
      await restored.restore();
      expect(restored.rows.single.requestId, id);
      expect(restored.rows.single.item.location, 'Bench');
      final other = PhotoScanSession(scoped, 'space-b', 'Other');
      await other.restore();
      expect(other.rows, isEmpty);
    },
  );
  test(
    'lost save response retries the exact request without a second item',
    () async {
      final saved = <String, Map<String, dynamic>>{};
      var lose = true;
      fixture.respond = (request) {
        if (request.path.endsWith('/spaces')) {
          return {
            'spaces': [
              {'id': 'space-a', 'name': 'Bench'},
            ],
          };
        }
        if (request.path.endsWith('/search_items')) {
          return {'items': [], 'parsed': {}};
        }
        if (request.path.endsWith('/inventory/bulk_create')) {
          final row = Map<String, dynamic>.from(request.data['items'][0]);
          saved.putIfAbsent(
            row['client_request_id'],
            () => {'item_id': 'new-item', ...row},
          );
          if (lose) {
            lose = false;
            throw DioException(
              requestOptions: request,
              type: DioExceptionType.receiveTimeout,
            );
          }
          return {
            'inserted': saved.values.toList(),
            'failures': [],
            'accepted_indices': [0],
          };
        }
        return {};
      };
      var session = PhotoScanSession(scoped, 'space-a', 'Bench');
      await session.accept([detection()]);
      expect(await session.save(session.rows.single), isFalse);
      session = PhotoScanSession(scoped, 'space-a', 'Bench');
      await session.restore();
      expect(session.rows.single.attempted, isTrue);
      expect(await session.save(session.rows.single), isTrue);
      expect(saved.length, 1);
      expect(session.rows.single.savedId, 'new-item');
    },
  );
  test('existing matches and uncertain counts require review', () async {
    fixture.respond = (_) => {
      'spaces': [
        {'id': 'space-a', 'name': 'Bench'},
      ],
      'items': [
        {
          'item_id': 'old',
          'name': 'Charger',
          'category': 'Electronics',
          'quantity': 1,
          'location': 'Bench',
        },
      ],
      'parsed': {},
    };
    final session = PhotoScanSession(scoped, 'space-a', 'Bench');
    await session.accept([detection()]);
    expect(await session.save(session.rows.single), isFalse);
    expect(session.rows.single.issue, contains('Possible existing item'));
    expect(
      fixture.requests.where((r) => r.path.endsWith('/inventory/bulk_create')),
      isEmpty,
    );
    session.rows.single.item = detection(review: true);
    expect(await session.save(session.rows.single), isFalse);
  });
  test('account switching blocks pending writes', () async {
    final session = PhotoScanSession(scoped, 'space-a', 'Bench');
    await session.accept([detection()]);
    await fixture.signIn('actor-b');
    await expectLater(session.save(session.rows.single), throwsA(anything));
    expect(
      fixture.requests.where((r) => r.path.endsWith('/inventory/bulk_create')),
      isEmpty,
    );
  });
  test(
    'suggestions use saved names, expire after three, stay within world',
    () async {
      final first = ScanExperience('actor-a', 'org-a');
      await first.saved(['Battery charger'], 'Bench');
      expect(first.questions, ['Where is my Battery charger?']);
      final other = ScanExperience('actor-a', 'org-b');
      await other.load();
      expect(other.scanned, isTrue);
      expect(other.questions, isEmpty);
      for (var i = 0; i < 3; i++) {
        await first.used();
      }
      final restored = ScanExperience('actor-a', 'org-a');
      await restored.load();
      expect(restored.questions, isEmpty);
      final outsider = ScanExperience('actor-b', 'org-a');
      await outsider.load();
      expect(outsider.scanned, isFalse);
    },
  );

  testWidgets('composer shows Scan then replaces it and mic when typing', (
    tester,
  ) async {
    final controller = TextEditingController();
    final focus = FocusNode();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorldComposer(
            controller: controller,
            focusNode: focus,
            onChanged: (_) {},
            onAttach: () {},
            onVoice: () {},
            onSend: () {},
            onScan: () {},
            busy: false,
            listening: false,
            compact: false,
          ),
        ),
      ),
    );
    expect(find.text('Scan'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Where is my charger?');
    await tester.pump();
    expect(find.text('Scan'), findsNothing);
    expect(find.byTooltip('Hold to speak'), findsNothing);
    expect(find.byTooltip('Send message'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    focus.dispose();
  });
  for (final dark in [false, true]) {
    testWidgets(
      'camera denial still exposes library and fits small large-text screen $dark',
      (tester) async {
        tester.view.physicalSize = const Size(375, 667);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final camera = FakeScanCamera()..denied = true;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              brightness: dark ? Brightness.dark : Brightness.light,
            ),
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(375, 667),
                textScaler: TextScaler.linear(1.6),
              ),
              child: ScanCameraPage(api: scoped, cameraFactory: () => camera),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Photo Library'), findsOneWidget);
        expect(find.textContaining('Camera unavailable'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        expect(camera.disposed, greaterThan(0));
      },
    );
  }
  testWidgets(
    'camera capture cancellation ignores late photo and sends no extraction',
    (tester) async {
      final camera = FakeScanCamera()..pending = Completer<Uint8List>();
      await tester.pumpWidget(
        MaterialApp(
          home: ScanCameraPage(
            api: scoped,
            destination: ScanDestination(scoped, 'space-a', 'Bench'),
            cameraFactory: () => camera,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Take photo'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      camera.pending!.complete(frame());
      await tester.pumpAndSettle();
      expect(fixture.requests, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'team creates once, single referral choice, then opens its organization',
    (tester) async {
      var organizations = 0, workspaces = 0, inventories = 0;
      fixture.respond = (request) {
        if (request.path.endsWith('/spaces')) {
          return {
            'spaces': [
              {'id': 'space-a', 'name': 'Bench'},
            ],
          };
        }
        if (request.method == 'POST') {
          if (request.path == '/organizations') {
            organizations++;
            return {
              'organization': {'organization_id': 'org-new'},
            };
          }
          if (request.path.endsWith('/workspaces')) {
            workspaces++;
            return {
              'workspace': {'workspace_id': 'workspace-new'},
            };
          }
          if (request.path.endsWith('/inventories')) {
            inventories++;
            return {
              'inventory': {'inventory_id': 'inventory-new'},
            };
          }
        }
        if (request.path == '/organizations') return {'organizations': []};
        if (request.path == '/organizations/org-new') return {'workspaces': []};
        return {'inventories': []};
      };
      await ScanEntryStore.choose('team');
      await tester.pumpWidget(
        MaterialApp(
          home: ScanSetupGate(
            api: fixture.api,
            onReady: (_) => const Text('Team Ask'),
            child: const Text('Personal Ask'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Robotics team');
      await tester.pump();
      await tester.tap(find.text('Create organization'));
      await tester.pumpAndSettle();
      expect(
        find.text('How did you hear about FindEZ?'),
        findsOneWidget,
        reason: fixture.requests.map((r) => '${r.method} ${r.path}').join(', '),
      );
      expect(find.text('Team Ask'), findsNothing);
      await tester.tap(find.text('Google'));
      await tester.pump();
      await tester.tap(find.text('App Store'));
      await tester.pump();
      final group = tester.widget<RadioGroup<String>>(
        find.byType(RadioGroup<String>),
      );
      expect(group.groupValue, 'App Store');
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Team Ask'), findsOneWidget);
      final state = await ScanEntryStore.claim('actor-a');
      expect(state?['organization'], 'org-new');
      expect(state?['complete'], isTrue);
      expect(state?['referral'], 'App Store');
      expect([organizations, workspaces, inventories], [1, 1, 1]);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'Undo deletes only the receipt item and a repeated photo cannot re-add it',
    () async {
      fixture.respond = (request) {
        if (request.path.endsWith('/spaces')) {
          return {
            'spaces': [
              {'id': 'space-a', 'name': 'Bench'},
            ],
          };
        }
        if (request.path.endsWith('/inventory/bulk_create')) {
          return {
            'inserted': [
              {'item_id': 'new-item', ...request.data['items'][0]},
            ],
            'accepted_indices': [0],
            'failures': [],
          };
        }
        if (request.path.endsWith('/delete_item')) {
          expect(request.queryParameters['item_id'], 'new-item');
          return {'deleted': true};
        }
        return {'items': [], 'parsed': {}};
      };
      final session = PhotoScanSession(scoped, 'space-a', 'Bench');
      await session.accept([detection()]);
      expect(await session.save(session.rows.single), isTrue);
      expect(await session.undo(session.rows.single), isTrue);
      expect(await session.accept([detection(count: 3)]), isEmpty);
      expect(session.rows.single.ignored, isTrue);
      await session.finish();
      final resumed = PhotoScanSession(scoped, 'space-a', 'Bench');
      await resumed.restore();
      expect(resumed.rows, isEmpty);
    },
  );

  testWidgets(
    'photo goes to review, saves once, and Undo uses the confirmed receipt',
    (tester) async {
      var writes = 0, deletes = 0;
      fixture.respond = (request) {
        if (request.path.endsWith('/spaces')) {
          return {
            'spaces': [
              {'id': 'space-a', 'name': 'Bench'},
            ],
          };
        }
        if (request.path.endsWith('/extract_from_image')) {
          return {
            'items': [detection().toJson()],
          };
        }
        if (request.path.endsWith('/inventory/bulk_create')) {
          writes++;
          return {
            'inserted': [
              {'item_id': 'new-item', ...request.data['items'][0]},
            ],
            'accepted_indices': [0],
            'failures': [],
          };
        }
        if (request.path.endsWith('/delete_item')) {
          deletes++;
          return {'deleted': true};
        }
        return {'items': [], 'parsed': {}};
      };
      final camera = FakeScanCamera();
      await tester.pumpWidget(
        MaterialApp(
          home: ScanCameraPage(
            api: scoped,
            destination: ScanDestination(scoped, 'space-a', 'Bench'),
            cameraFactory: () => camera,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Take photo'));
      for (var i = 0; i < 50; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
        if (find.text('Save 1 item').evaluate().isNotEmpty) break;
      }
      expect(find.text('Battery charger'), findsOneWidget);
      expect(writes, 0);
      await tester.ensureVisible(find.text('Save 1 item'));
      await tester.tap(find.text('Save 1 item'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save to Space'));
      await tester.tap(find.text('Save to Space'));
      await tester.pumpAndSettle();
      expect(writes, 1);
      expect(find.text('Saved'), findsOneWidget);
      await tester.ensureVisible(find.text('Undo'));
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(deletes, 1);
      expect(find.text('Removed'), findsOneWidget);
      final experience = ScanExperience('actor-a', 'org-a');
      await experience.load();
      expect(experience.scanned, isTrue);
      expect(experience.questions, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'cancel reading discards a late extraction without a save or retry',
    (tester) async {
      final response = Completer<Object?>();
      fixture.respond = (request) =>
          request.path.endsWith('/extract_from_image')
          ? response.future
          : {'items': [], 'parsed': {}};
      await tester.pumpWidget(
        MaterialApp(
          home: ScanCameraPage(
            api: scoped,
            destination: ScanDestination(scoped, 'space-a', 'Bench'),
            cameraFactory: FakeScanCamera.new,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Take photo'));
      for (var i = 0; i < 50; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 3)),
        );
        if (fixture.requests.isNotEmpty) break;
      }
      await tester.tap(find.text('Stop reading'));
      await tester.pump();
      response.complete({
        'items': [detection().toJson()],
      });
      await tester.pumpAndSettle();
      expect(find.text('Battery charger'), findsNothing);
      expect(
        fixture.requests
            .where((r) => r.path.endsWith('/extract_from_image'))
            .length,
        1,
      );
      expect(
        fixture.requests.where(
          (r) => r.method == 'POST' && !r.path.endsWith('/extract_from_image'),
        ),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'a Space deleted elsewhere is not recreated by a pending scan',
    () async {
      final session = PhotoScanSession(scoped, 'space-deleted', 'Old shelf');
      await session.accept([detection()]);
      fixture.respond = (_) => {'spaces': []};
      expect(await session.save(session.rows.single), isFalse);
      expect(session.rows.single.issue, contains('Space changed'));
      expect(fixture.requests.where((r) => r.method == 'POST'), isEmpty);
    },
  );

  testWidgets(
    'only Take Photo and Photo Library remain; camera never captures automatically',
    (tester) async {
      final camera = FakeScanCamera();
      await tester.pumpWidget(
        MaterialApp(
          home: ScanCameraPage(
            api: scoped,
            cameraFactory: () => camera,
            libraryPicker: () async => null,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Take Photo'), findsOneWidget);
      expect(find.text('Photo Library'), findsOneWidget);
      expect(find.text('Scan Frames'), findsNothing);
      expect(find.text('Auto-add'), findsNothing);
      await tester.pump(const Duration(seconds: 30));
      expect(camera.captures, 0);
      expect(fixture.requests, isEmpty);
      await tester.tap(find.text('Photo Library'));
      await tester.pumpAndSettle();
      expect(camera.disposed, greaterThan(0));
      expect(fixture.requests, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );
  test('separate unknown detections remain separate for review', () async {
    final session = PhotoScanSession(scoped, 'space-a', 'Bench');
    await session.accept([
      ExtractedInventoryItem(
        name: 'Unknown item',
        category: 'Other',
        quantity: 1,
      ),
      ExtractedInventoryItem(
        name: 'Unknown item',
        category: 'Other',
        quantity: 1,
      ),
      ExtractedInventoryItem(name: '电池', category: 'Other', quantity: 1),
      ExtractedInventoryItem(name: '充电器', category: 'Other', quantity: 1),
    ]);
    expect(session.rows.length, 4);
  });
}
