import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/core/appearance_controller.dart';
import 'package:mobile/core/profile_store.dart';
import 'package:mobile/core/ui/native_menu_button.dart';
import 'package:mobile/core/ui/native_presentation.dart';
import 'package:mobile/features/chat/chat_history_sheet.dart';
import 'package:mobile/features/chat/native_chat_menu_button.dart';
import 'package:mobile/features/profile/native_account_menu.dart';
import '../test/support/hierarchy_fixture.dart';

// Normal native runtime audit with isolated synthetic data. Never a release target.
Future<void> main() async {
  if (kReleaseMode) throw UnsupportedError('Debug audit only');
  WidgetsFlutterBinding.ensureInitialized();
  final fixture = HierarchyFixture();
  await fixture.initialize();
  var rows = [
    {
      'id': 'chat-a',
      'title': 'Find my drill',
      'updated_at': '2026-10-23T12:00:00Z',
      'created_at': '2026-10-23T12:00:00Z',
    },
    {
      'id': 'chat-b',
      'title': 'Organize my workshop',
      'updated_at': '2026-10-22T12:00:00Z',
      'created_at': '2026-10-22T12:00:00Z',
    },
  ];
  fixture.respond = (request) {
    if (request.path.endsWith('/profile/me')) {
      return {'user_id': 'actor-a', 'display_name': 'Alex Example'};
    }
    if (request.method == 'DELETE') {
      rows = rows.where((r) => !request.path.endsWith(r['id']!)).toList();
      return {};
    }
    if (request.path.contains('/conversations')) return rows;
    return <String, dynamic>{};
  };
  final appearance = AppearanceController();
  await appearance.load();
  await appearance.setThemeMode(ThemeMode.dark);
  final profile = ProfileStore(api: fixture.api);
  await profile.load();
  runApp(
    AnimatedBuilder(
      animation: appearance,
      builder: (context, _) => AppearanceScope(
        controller: appearance,
        child: MaterialApp(
          theme: AppTheme.create(Brightness.light),
          darkTheme: AppTheme.create(Brightness.dark),
          themeMode: appearance.themeMode,
          builder: (context, child) => GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: MediaQuery.viewInsetsOf(context).bottom > 0
                ? () => FocusManager.instance.primaryFocus?.unfocus()
                : null,
            child: child,
          ),
          home: _Audit(fixture: fixture, profile: profile),
        ),
      ),
    ),
  );
}

class _Audit extends StatefulWidget {
  const _Audit({required this.fixture, required this.profile});
  final HierarchyFixture fixture;
  final ProfileStore profile;
  @override
  State<_Audit> createState() => _AuditState();
}

class _AuditState extends State<_Audit> {
  String result = 'Ready';
  void record(Object? value) {
    if (mounted) setState(() => result = value?.toString() ?? 'Cancelled');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Native controls audit')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(result, key: const Key('result')),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () async => record(
              await showChatHistory(
                context,
                api: widget.fixture.api,
                currentId: 'chat-a',
              ),
            ),
            child: const Text('Open history'),
          ),
          TextButton(
            onPressed: () => showNativeAccountMenu(
              context,
              api: widget.fixture.api,
              profile: widget.profile,
            ),
            child: const Text('Open settings'),
          ),
          TextButton(
            onPressed: () async => record(
              await showNativeNamePrompt(
                context,
                title: 'New Space',
                placeholder: 'Space name',
              ),
            ),
            child: const Text('New Space'),
          ),
          TextButton(
            onPressed: () async => record(
              await showAppConfirmation(
                context,
                title: 'Delete test item?',
                message: 'This is a local visual test.',
              ),
            ),
            child: const Text('Delete test item'),
          ),
          const TextField(
            decoration: InputDecoration(labelText: 'Keyboard test'),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              SizedBox(
                width: 160,
                height: 48,
                child: Stack(
                  children: [
                    const Center(child: Text('Attach')),
                    NativeChatMenuButton(enabled: true, onSelected: record),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              AppMenuButton(
                items: const [
                  AppMenuItem('rename', 'Rename', 'pencil'),
                  AppMenuItem('delete', 'Delete', 'trash', destructive: true),
                ],
                onSelected: record,
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
