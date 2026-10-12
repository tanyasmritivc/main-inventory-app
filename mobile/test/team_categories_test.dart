import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/teams/create_team_sheet.dart';
import 'package:mobile/features/teams/team_categories.dart';

class _Api extends ApiClient {
  _Api() : super(baseUrl: 'https://api.test');
  bool fail = true;
  final writes = <Map<String, dynamic>>[];
  @override
  Future<Map<String, dynamic>> createTeam({
    required String name,
    required String program,
    String? customCategory,
  }) async {
    writes.add({
      'name': name,
      'program': program,
      'custom_category': customCategory,
    });
    if (fail) throw Exception('Could not save team');
    return {
      'team_id': 'team',
      'name': name,
      'program': program,
      'custom_category': customCategory,
    };
  }
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test',
      httpClient: MockClient((_) async => http.Response('{}', 200)),
    );
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'custom Team category validates and retains failed draft in $brightness',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final api = _Api();
        Map<String, dynamic>? saved;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.create(brightness),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    saved = await showModalBottomSheet<Map<String, dynamic>>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => CreateTeamSheet(api: api),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.text('Choose a category'), findsOneWidget);
        await tester.tap(find.byKey(const Key('team-save')));
        await tester.pumpAndSettle();
        expect(api.writes, isEmpty);
        await tester.enterText(
          find.byKey(const Key('team-name')),
          ' Costumes ',
        );
        await tester.tap(find.byKey(const Key('team-category')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Custom category').last);
        await tester.tap(find.text('Custom category').last);
        await tester.pumpAndSettle();
        final custom = find.byKey(const Key('team-custom-category'));
        await tester.ensureVisible(custom);
        await tester.enterText(custom, ' Costume department ');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.ensureVisible(find.byKey(const Key('team-save')));
        await tester.tap(find.byKey(const Key('team-save')));
        await tester.pumpAndSettle();
        expect(
          find.text('Something went wrong. Please try again.'),
          findsOneWidget,
        );
        expect(find.text(' Costume department '), findsOneWidget);
        api.fail = false;
        await tester.tap(find.byKey(const Key('team-save')));
        await tester.pumpAndSettle();
        expect(saved?['custom_category'], 'Costume department');
        expect(api.writes.last, {
          'name': 'Costumes',
          'program': 'custom',
          'custom_category': 'Costume department',
        });
        expect(
          teamCategoryLabel(saved?['program'], saved?['custom_category']),
          'Costume department',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
