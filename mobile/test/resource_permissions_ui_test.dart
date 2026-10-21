import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/features/profile/profile_page.dart';
import 'package:mobile/features/profile/account_page.dart';
import 'package:mobile/features/profile/appearance_settings.dart';
import 'package:mobile/features/profile/profile_editor_page.dart';
import 'package:mobile/features/workspaces/hierarchy_page.dart';
import 'package:mobile/features/workspaces/transfer_ownership.dart';
import 'package:mobile/features/teams/team_board_page.dart';
import 'package:mobile/features/teams/team_documents_page.dart';
import 'package:mobile/features/review/review_queue_page.dart';
import 'package:mobile/features/documents/documents_page.dart';
import 'package:mobile/features/scan/scan_inspection.dart';
import 'support/hierarchy_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fixture = HierarchyFixture();
  setUpAll(() async {
    await fixture.initialize();
    if (const bool.fromEnvironment('FINDEZ_VISUAL_QA')) {
      await (FontLoader(
        'Roboto',
      )..addFont(rootBundle.load('assets/fonts/Geist-Regular.ttf'))).load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      await (FontLoader('packages/cupertino_icons/CupertinoIcons')..addFont(
            rootBundle.load(
              'packages/cupertino_icons/assets/CupertinoIcons.ttf',
            ),
          ))
          .load();
    }
  });
  tearDownAll(() => Supabase.instance.dispose());
  setUp(() {
    fixture.requests.clear();
    fixture.status = 200;
    fixture.respond = (request) {
      if (request.path == '/profile/me') {
        return {'display_name': 'My account', 'email': 'actor-a@example.test'};
      }
      if (request.path == '/teams') {
        return {
          'teams': [
            {'team_id': 'team', 'name': 'Workshop', 'role': 'member'},
          ],
        };
      }
      if (request.path.endsWith('/members')) return {'members': []};
      if (request.path == '/organizations') return {'organizations': []};
      return {
        'items': [],
        'documents': [],
        'tasks': [],
        'members': [],
        'pending_count': 0,
        'role': 'member',
        'unread_count': 0,
        'notifications': [],
      };
    };
  });
  for (final mode in Brightness.values) {
    final cases = <String, Widget Function()>{
      'organizations': () =>
          HierarchyPage(api: fixture.api, onOpenInventory: (_, _, _) async {}),
      'tasks': () => TeamBoardPage(api: fixture.api, initialTeamId: 'team'),
      'files': () => TeamDocumentsPage(api: fixture.api, teamId: 'team'),
      'review': () => ReviewQueuePage(api: fixture.api),
      'documents': () => DocumentsPage(api: fixture.api),
    };
    for (final entry in cases.entries) {
      testWidgets(
        '${mode.name} ${entry.key} has own profile at the top right',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPadding);
          final capture = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: capture,
              child: MaterialApp(
                theme: AppTheme.create(mode),
                home: entry.value(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final button = find.byTooltip('Your profile');
          expect(button, findsOneWidget);
          expect(tester.getCenter(button).dx, greaterThan(340));
          expect(tester.getCenter(button).dy, lessThan(100));
          await tester.tap(button);
          await tester.pumpAndSettle();
          expect(find.byType(AccountPage), findsNothing);
          expect(find.byType(ProfilePage), findsOneWidget);
          expect(find.byType(AppearanceSettings), findsOneWidget);
          expect(find.text('Theme').hitTestable(), findsOneWidget);
          expect(find.text('Notifications').hitTestable(), findsOneWidget);
          expect(
            tester.getTopLeft(find.byType(BottomSheet)).dy,
            greaterThanOrEqualTo(47),
          );
          expect(find.text('Free Pilot'), findsNothing);
          if (const bool.fromEnvironment('FINDEZ_VISUAL_QA') &&
              entry.key == 'organizations') {
            await tester.runAsync(() async {
              final boundary =
                  capture.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final image = await boundary.toImage(pixelRatio: 2);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File(
                '/private/tmp/findez-account-${mode.name}.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          await tester.tap(find.text('Edit profile'));
          await tester.pumpAndSettle();
          expect(find.byType(ProfileEditorPage), findsOneWidget);
          await tester.tap(find.byType(BackButton).last);
          await tester.pumpAndSettle();
          expect(find.byType(AppearanceSettings), findsOneWidget);
          Navigator.of(tester.element(find.byType(AppearanceSettings))).pop();
          await tester.pumpAndSettle();
          expect(find.byTooltip('Your profile'), findsOneWidget);
          expect(
            fixture.requests.where((r) => r.path == '/profile/me'),
            isNotEmpty,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        },
      );
    }
    testWidgets(
      '${mode.name} Viewer preview has no editable or save controls',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.create(mode),
            home: Scaffold(
              body: ScanInspection(
                items: [
                  ExtractedInventoryItem(
                    name: 'M4 bolt',
                    category: 'Hardware',
                    quantity: 2,
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('M4 bolt'), findsOneWidget);
        expect(find.byType(TextField), findsNothing);
        expect(find.textContaining('Nothing was saved'), findsOneWidget);
        expect(fixture.requests, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      '${mode.name} ownership requires a current recipient and exact name',
      (tester) async {
        fixture.respond = (r) => {
          'members': [
            {'user_id': 'actor-a', 'display_name': 'Me'},
            {'user_id': 'other', 'display_name': 'New owner'},
          ],
        };
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.create(mode),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => confirmOwnershipTransfer(
                    context,
                    fixture.api,
                    scope: 'organization',
                    id: 'org',
                    name: 'Acme',
                  ),
                  child: const Text('Transfer'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Transfer'));
        await tester.pumpAndSettle();
        expect(find.text('Me'), findsNothing);
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Confirm transfer'),
              )
              .onPressed,
          isNull,
        );
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('New owner').last);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'acme');
        await tester.pump();
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Confirm transfer'),
              )
              .onPressed,
          isNull,
        );
        await tester.enterText(find.byType(TextField), 'Acme');
        await tester.pump();
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Confirm transfer'),
              )
              .onPressed,
          isNotNull,
        );
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(fixture.requests.where((r) => r.method == 'POST'), isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
