import 'dart:convert';
import 'package:findez_dashboard/dashboard_api.dart';
import 'package:findez_dashboard/demo_requests.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dashboard_test.dart' show sessionFixture;

void main() {
  testWidgets('founder can open a prospect and save an internal note', (
    tester,
  ) async {
    final notes = <String>[];
    final api = DashboardApi(
      client: MockClient((request) async {
        expect(request.headers['Authorization'], startsWith('Bearer '));
        final path = request.url.path;
        if (path.endsWith('/action')) {
          final action = jsonDecode(request.body);
          expect(action['action'], 'note');
          notes.add(action['value']);
        }
        final result = path == '/internal/demo-sales'
            ? {
                'items': [
                  {
                    'id': 'test',
                    'name': 'Test Visitor',
                    'organization': 'Test Lab',
                    'status': 'New Request',
                    'email': 'visitor@example.org',
                  },
                ],
                'statuses': ['New Request'],
                'more': false,
                'integrations': {},
                'metrics': {
                  'organizations': {'Research': 1},
                },
              }
            : {
                'submitted': {'name': 'Test Visitor'},
                'email': 'visitor@example.org',
                'created': 1,
                'owner': '',
                'status': 'New Request',
                'pilot': {},
                'brief_state': 'pending',
                'followups': [],
                'mail': [],
                'history': [
                  for (final note in notes)
                    {'action': 'Internal note', 'detail': note, 'at': 1},
                ],
              };
        return http.Response(jsonEncode(result), 200);
      }),
    )..session = sessionFixture();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DemoRequests(api: api)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Test Visitor · Test Lab'));
    await tester.tap(find.text('Test Visitor · Test Lab'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Status and notes'));
    await tester.tap(find.text('Status and notes'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Add note').hitTestable(),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add note'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField),
      'Discuss BOM shortages.',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(notes, ['Discuss BOM shortages.']);
    expect(tester.takeException(), isNull);
  });
}
