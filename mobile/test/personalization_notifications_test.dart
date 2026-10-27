import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/personalization_notifications.dart';
import 'support/hierarchy_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const id = '30000000-0000-0000-0000-000000000001';
  final fixture = HierarchyFixture();
  final payload = <String, dynamic>{
    'action': 'personalization',
    'notification_id': id,
    'recipient_user_id': 'actor-a',
  };
  setUpAll(fixture.initialize);
  tearDownAll(() => Supabase.instance.dispose());
  setUp(() async {
    await fixture.signIn('actor-a');
    fixture.requests.clear();
    fixture.status = 200;
    fixture.respond = (_) => {'saved': true};
  });
  test('only exact recipient and UUID are accepted', () {
    expect(PersonalizationNotifications.identifier(payload, 'actor-a'), id);
    expect(PersonalizationNotifications.identifier(payload, 'actor-b'), isNull);
    expect(PersonalizationNotifications.identifier(payload, null), isNull);
    expect(
      PersonalizationNotifications.identifier({
        ...payload,
        'notification_id': '../../other',
      }, 'actor-a'),
      isNull,
    );
    expect(
      PersonalizationNotifications.identifier({
        ...payload,
        'recipient_user_id': null,
      }, 'actor-a'),
      isNull,
    );
  });
  test(
    'telemetry cannot claim task completion or impersonate a recipient',
    () async {
      await PersonalizationNotifications.feedback(
        fixture.api,
        payload,
        'action_completed',
      );
      await PersonalizationNotifications.feedback(fixture.api, {
        ...payload,
        'recipient_user_id': 'other',
      }, 'opened');
      expect(fixture.requests, isEmpty);
      await PersonalizationNotifications.feedback(
        fixture.api,
        payload,
        'delivered',
      );
      expect(
        fixture.requests.single.path,
        '/personalization/notifications/$id/feedback',
      );
      expect(fixture.requests.single.data, {'outcome': 'delivered'});
    },
  );
  test('telemetry failure is optional', () async {
    fixture.status = 503;
    await PersonalizationNotifications.feedback(
      fixture.api,
      payload,
      'dismissed',
    );
  });
  testWidgets(
    'deleted target fails gracefully without trusting payload entity',
    (tester) async {
      fixture.status = 404;
      fixture.respond = (_) => {
        'detail': 'This item or review is no longer available.',
      };
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (c) {
                context = c;
                return const Text('Existing screen');
              },
            ),
          ),
        ),
      );
      final request = PersonalizationNotifications.open(context, fixture.api, {
        ...payload,
        'entity_id': 'untrusted',
      });
      await tester.pumpAndSettle();
      await request;
      expect(
        fixture.requests.single.path,
        '/personalization/notifications/$id/destination',
      );
      expect(find.text('Existing screen'), findsOneWidget);
      expect(find.textContaining('no longer available'), findsOneWidget);
    },
  );
  for (final kind in ['item', 'review']) {
    testWidgets('opens the exact authorized $kind in the existing sheet', (
      tester,
    ) async {
      fixture.respond = (request) {
        if (request.path.endsWith('/destination')) {
          return {
            'notification_id': id,
            'inventory_id': 'inv',
            'inventory': inventory('inv'),
            'entity_type': kind,
            'entity_id': 'target',
            'resource': {
              kind == 'item' ? 'item_id' : 'review_id': 'target',
              'name': 'Exact authorized part',
              'category': 'Parts',
              'quantity': 2,
              'location': 'Drawer',
              'status': 'pending',
            },
          };
        }
        return {'saved': true, 'photos': [], 'checkouts': []};
      };
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (c) {
                context = c;
                return const Text('Existing screen');
              },
            ),
          ),
        ),
      );
      final opening = PersonalizationNotifications.open(
        context,
        fixture.api,
        payload,
      );
      await tester.pumpAndSettle();
      expect(find.text('Exact authorized part'), findsWidgets);
      expect(
        fixture.requests.where((r) => r.path.endsWith('/feedback')).single.data,
        {'outcome': 'opened'},
      );
      Navigator.of(context).pop();
      await tester.pumpAndSettle();
      await opening;
    });
  }
}
