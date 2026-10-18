import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/core/ui/member_avatar.dart';
import 'package:mobile/features/teams/team_board_page.dart';
import 'support/hierarchy_fixture.dart';

class TaskAvatarApi extends ApiClient {
  TaskAvatarApi() : super(baseUrl: 'https://api.test');
  String photo = 'https://api.test/saved-avatar.png?revision=1';
  @override
  Future<List<Map<String, dynamic>>> listTeams() async => [
    {'team_id': 'workspace', 'name': 'Workshop'},
  ];
  @override
  Future<Map<String, dynamic>> getTeamBoard(String id) async => {
    'role': 'viewer',
    'tasks': [
      {
        'task_id': 'task',
        'title': 'Find the drill',
        'status': 'todo',
        'assigned_to': 'ada',
        'created_by': 'ada',
      },
    ],
  };
  @override
  Future<List<Map<String, dynamic>>> getTeamMembers(String id) async => [
    {'user_id': 'ada', 'display_name': 'Ada', 'avatar_url': photo},
  ];
  @override
  Future<Map<String, dynamic>> getMyProfile() async => {};
  @override
  Future<Map<String, dynamic>> getNotifications() async => {'unread_count': 0};
}

void main() {
  final fixture = HierarchyFixture();
  setUpAll(fixture.initialize);
  tearDownAll(() => Supabase.instance.dispose());
  for (final mode in Brightness.values) {
    testWidgets(
      '${mode.name} task avatars follow saved photo replacement and removal',
      (tester) async {
        final api = TaskAvatarApi();
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.create(mode),
            home: TeamBoardPage(api: api, initialTeamId: 'workspace'),
          ),
        );
        await tester.pumpAndSettle();
        Finder saved(String url) => find.byWidgetPredicate(
          (widget) =>
              widget is MemberAvatar &&
              widget.name == 'Ada' &&
              widget.photoUrl == url,
        );
        expect(saved(api.photo), findsOneWidget);
        expect(find.text('Assigned to Ada'), findsOneWidget);
        await tester.tap(find.text('Find the drill'));
        await tester.pumpAndSettle();
        expect(find.text('Created by Ada'), findsOneWidget);
        expect(find.text('Delete'), findsNothing);
        Navigator.of(tester.element(find.text('Created by Ada'))).pop();
        await tester.pumpAndSettle();
        api.photo = 'https://api.test/saved-avatar.png?revision=2';
        await tester.pump(const Duration(seconds: 16));
        await tester.pumpAndSettle();
        expect(saved(api.photo), findsOneWidget);
        expect(
          saved('https://api.test/saved-avatar.png?revision=1'),
          findsNothing,
        );
        api.photo = '';
        await tester.pump(const Duration(seconds: 16));
        await tester.pumpAndSettle();
        expect(saved(''), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
