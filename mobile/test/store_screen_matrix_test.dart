// Release-only visual and responsive audit. Synthetic account; no external writes.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/core/legal_links.dart';
import 'package:mobile/core/ui/native_presentation.dart';
import 'package:mobile/features/activity/activity_page.dart';
import 'package:mobile/features/auth/auth_page.dart';
import 'package:mobile/features/auth/password_recovery_page.dart';
import 'package:mobile/features/chat/chat_page.dart';
import 'package:mobile/features/chat/assistant_connections_page.dart';
import 'package:mobile/features/checkout/checkout_page.dart';
import 'package:mobile/features/documents/documents_page.dart';
import 'package:mobile/features/documents/notes_editor_page.dart';
import 'package:mobile/features/inventory/inventory_page.dart';
import 'package:mobile/features/inventory/space_directory.dart';
import 'package:mobile/features/notifications/notifications_page.dart';
import 'package:mobile/features/onboarding/chat_onboarding_page.dart';
import 'package:mobile/features/profile/account_page.dart';
import 'package:mobile/features/profile/profile_editor_page.dart';
import 'package:mobile/features/profile/settings_page.dart';
import 'package:mobile/features/profile/memory_page.dart';
import 'package:mobile/features/profile/plans_page.dart';
import 'package:mobile/features/review/review_queue_page.dart';
import 'package:mobile/features/scan/bom_readiness_page.dart';
import 'package:mobile/features/scan/import_sheet_page.dart';
import 'package:mobile/features/scan/project_kits_page.dart';
import 'package:mobile/features/scan/connector_destination_page.dart';
import 'package:mobile/features/scan/scan_page.dart';
import 'package:mobile/features/sharing/review_invitation_page.dart';
import 'package:mobile/features/sharing/shared_inventory_page.dart';
import 'package:mobile/features/sharing/space_members_page.dart';
import 'package:mobile/features/shopping/shopping_list_page.dart';
import 'package:mobile/features/teams/teams_page.dart';
import 'package:mobile/features/teams/team_board_page.dart';
import 'package:mobile/features/teams/team_documents_page.dart';
import 'package:mobile/features/teams/team_workspace_page.dart';
import 'package:mobile/features/workspaces/hierarchy_page.dart';
import 'package:mobile/features/workspaces/invitation_page.dart';
import 'support/hierarchy_fixture.dart';
import 'memory_controller_test.dart' show MemoryApi;

void main({Future<void> Function(String name, List<int> bytes)? capture}) {
  final fixture = HierarchyFixture();
  const visual = bool.fromEnvironment('FINDEZ_STORE_VISUAL');
  setUpAll(() async {
    await fixture.initialize();
    fixture.respond = (r) {
      if (r.path.endsWith('/profile/me')) {
        return {'user_id': 'actor-a', 'display_name': 'Alex Example'};
      }
      if (r.path.endsWith('/limits')) {
        return {'pilot_mode': true, 'tier': 'free'};
      }
      if (r.path.endsWith('/workspace') || r.path.endsWith('/board')) {
        return {
          'team': {'team_id': 'team-a', 'name': 'Sample Workshop'},
          'role': 'owner',
          'spaces': [],
          'tasks': [],
        };
      }
      if (r.path.endsWith('/organizations/org-a')) {
        return {
          'organization': {
            'organization_id': 'org-a',
            'name': 'Sample Organization',
          },
          'role': 'owner',
        };
      }
      return <String, dynamic>{};
    };
    {
      for (final entry in {
        'PlusJakartaSans': 'assets/fonts/PlusJakartaSans.ttf',
        for (final weight in ['regular', 'medium', 'semiBold', 'bold'])
          'PlusJakartaSans_$weight': 'assets/fonts/PlusJakartaSans.ttf',
        'Ahem': 'assets/fonts/PlusJakartaSans.ttf',
        'Roboto': 'assets/fonts/PlusJakartaSans.ttf',
        'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
        'packages/cupertino_icons/CupertinoIcons':
            'packages/cupertino_icons/assets/CupertinoIcons.ttf',
      }.entries) {
        await (FontLoader(
          entry.key,
        )..addFont(rootBundle.load(entry.value))).load();
      }
    }
  });
  tearDownAll(() => Supabase.instance.dispose());
  setUp(() => debugNativePresentationOverride = false);
  tearDown(() => debugNativePresentationOverride = null);
  final pages = <String, Widget Function()>{
    'onboarding': () => ChatOnboardingPage(api: fixture.api, showWorld: false),
    'sign-in': () => const AuthPage(),
    'password-recovery': () => const PasswordRecoveryPage(),
    'chat': () => ChatPage(api: fixture.api),
    'spaces': () => InventorySpacesPage(api: fixture.api),
    'inventory': () => InventoryPage(api: fixture.api, refreshToken: 0),
    'review': () => ReviewQueuePage(api: fixture.api),
    'scan': () => ScanPage(api: fixture.api, onSaved: () {}),
    'documents': () => DocumentsPage(api: fixture.api),
    'new-note': () => NotesEditorPage(api: fixture.api),
    'activity': () => ActivityPage(api: fixture.api),
    'checkouts': () => CheckoutPage(api: fixture.api),
    'restock': () => ShoppingListPage(api: fixture.api),
    'notifications': () => NotificationsPage(api: fixture.api),
    'account': () => AccountPage(api: fixture.api),
    'profile-edit': () => ProfileEditorPage(api: fixture.api),
    'settings': () => SettingsPage(api: fixture.api),
    'memory': () => MemoryPage(api: MemoryApi()..record['enabled'] = true),
    'plans': () => const PlansPage(),
    'privacy-fallback': () => LegalLinkPage(
      document: LegalDocumentKind.privacy,
      openUrl: (_) async => false,
    ),
    'terms-fallback': () => LegalLinkPage(
      document: LegalDocumentKind.terms,
      openUrl: (_) async => false,
    ),
    'connections': () => AssistantConnectionsPage(api: fixture.api),
    'import-destination': () => ConnectorDestinationPage(api: fixture.api),
    'spreadsheet-import': () =>
        ImportSheetPage(api: fixture.api, location: 'Desk'),
    'bom': () => BomReadinessPage(api: fixture.api, location: 'Desk'),
    'project-kits': () => ProjectKitsPage(api: fixture.api, location: 'Desk'),
    'shared-inventory': () => SharedInventoryPage(
      api: fixture.api,
      shareId: 'share-a',
      shareName: 'Shared Desk',
      permission: 'view',
    ),
    'space-members': () => SpaceMembersPage(
      api: fixture.api,
      shareId: 'share-a',
      spaceName: 'Shared Desk',
    ),
    'review-invitation': () => ReviewInvitationPage(api: fixture.api),
    'access-invitation': () =>
        AccessInvitationPage(api: fixture.api, code: 'unavailable-test-code'),
    'teams': () => TeamsPage(api: fixture.api),
    'team-workspace': () =>
        TeamWorkspacePage(api: fixture.api, initialTeamId: 'team-a'),
    'team-board': () =>
        TeamBoardPage(api: fixture.api, initialTeamId: 'team-a'),
    'team-files': () => TeamDocumentsPage(api: fixture.api, teamId: 'team-a'),
    'organizations': () =>
        HierarchyPage(api: fixture.api, onOpenInventory: (_, _, _) async {}),
  };
  for (final brightness in Brightness.values) {
    for (final profile in [
      (const Size(390, 844), 1.0, 'phone'),
      (const Size(320, 568), 2.6, 'large-text'),
      (const Size(1024, 768), 1.0, 'ipad'),
    ]) {
      for (final entry in pages.entries) {
        testWidgets('${entry.key} ${brightness.name} ${profile.$3}', (
          tester,
        ) async {
          tester.view.physicalSize = profile.$1;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final key = GlobalKey();
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.create(brightness),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(profile.$2),
                  disableAnimations: true,
                  padding: const EdgeInsets.only(top: 24, bottom: 20),
                ),
                child: child!,
              ),
              home: RepaintBoundary(
                key: key,
                child: Scaffold(body: entry.value()),
              ),
            ),
          );
          // Fixed pumping avoids perpetual animations masking layout failures.
          for (var i = 0; i < 8; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          expect(tester.takeException(), isNull, reason: entry.key);
          if ((visual || capture != null) && profile.$3 != 'large-text') {
            await tester.runAsync(() async {
              final frame =
                  await (key.currentContext!.findRenderObject()!
                          as RenderRepaintBoundary)
                      .toImage(pixelRatio: 1);
              final bytes = (await frame.toByteData(
                format: ui.ImageByteFormat.png,
              ))!.buffer.asUint8List();
              if (capture != null) {
                await capture(
                  '${profile.$3}-${brightness.name}-${entry.key}',
                  bytes,
                );
                frame.dispose();
                return;
              }
              final dir = Directory('/private/tmp/findez-store-visual');
              await dir.create(recursive: true);
              await File(
                '${dir.path}/${profile.$3}-${brightness.name}-${entry.key}.png',
              ).writeAsBytes(bytes);
              frame.dispose();
            });
          }
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        });
      }
    }
  }
}
