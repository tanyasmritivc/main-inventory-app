import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/teams/physical_memory_page.dart';

final catalog = <String, dynamic>{
  'memory_id': null,
  'native_label': null,
  'connection_id': 'store-a',
  'variant_gid': 'variant-a',
  'product_title': 'Hoodie',
  'variant_title': 'Black M',
  'sku': 'same-sku',
  'placements': [],
};
final options = <String, dynamic>{
  'can_confirm': true,
  'spaces': [
    {
      'id': 'space-a',
      'name': 'Stockroom',
      'bins': [
        {'id': 'bin-a', 'name': 'Bin 12'},
      ],
    },
  ],
};
Map<String, dynamic> answer(List<Map<String, dynamic>> rows) => {
  'kind': rows.length > 1 ? 'clarification' : 'locations',
  'assistant_message': rows.length > 1
      ? 'Choose the variant you mean.'
      : 'No physical location is confirmed.',
  'answer_context': {'sources': [], 'rows': []},
  'result': {'candidates': rows, 'truncated': false},
};
DioException denied() => DioException(
  requestOptions: RequestOptions(path: '/physical'),
  response: Response(
    requestOptions: RequestOptions(path: '/physical'),
    statusCode: 403,
  ),
);

class PhysicalTestApi extends ApiClient {
  PhysicalTestApi() : super(baseUrl: 'https://api.test');
  String actor = 'actor-a';
  @override
  String? get accountId => actor;
  List<Map<String, dynamic>> rows = [catalog];
  final writes = <Map<String, dynamic>>[], queries = <Map<String, dynamic>>[];
  Object? failure;
  Completer<Map<String, dynamic>>? saving, reading;
  bool revoked = false;
  @override
  Future<Map<String, dynamic>> getPhysicalOptions(String team) async {
    if (revoked) throw denied();
    return options;
  }

  @override
  Future<Map<String, dynamic>> askPhysical(
    String team,
    Map<String, dynamic> query,
  ) async {
    queries.add({'team': team, ...query});
    return reading == null ? answer(rows) : await reading!.future;
  }

  @override
  Future<Map<String, dynamic>> confirmPhysical(
    String team,
    Map<String, dynamic> payload,
  ) async {
    writes.add({'team': team, ...payload});
    if (failure != null) throw failure!;
    return saving == null
        ? {
            'memory_id': 'memory-a',
            'placement_id': 'place-a',
            'observation_id': 'event-a',
            'revision': 1,
          }
        : await saving!.future;
  }

  @override
  Future<Map<String, dynamic>> getPhysicalHistory(
    String team,
    String placement,
  ) async {
    if (revoked) throw denied();
    return {'observations': []};
  }
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      150,
      scrollable: find
          .descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> form(
  WidgetTester tester,
  PhysicalTestApi api, {
  Map<String, dynamic>? record,
  bool viewer = false,
  ValueChanged<String>? saved,
  VoidCallback? access,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.create(Brightness.light),
      home: Scaffold(
        body: ListView(
          children: [
            PhysicalLocationForm(
              api: api,
              teamId: 'team-a',
              candidate: record ?? catalog,
              options: {...options, 'can_confirm': !viewer},
              isCurrent: () => api.actor == 'actor-a',
              onBusy: (_) {},
              onSaved: (value) async {
                saved?.call(value);
              },
              onAccessDenied: access ?? () {},
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> fill(WidgetTester tester, {String count = ''}) async {
  await tester.enterText(
    find.byKey(const Key('physical-native-name')),
    'Our hoodie',
  );
  await tap(tester, find.byKey(const Key('physical-space')));
  await tap(tester, find.text('Stockroom').last);
  await tap(tester, find.byKey(const Key('physical-bin')));
  await tap(tester, find.text('Bin 12').last);
  await tester.ensureVisible(find.byKey(const Key('physical-count')));
  await tester.enterText(find.byKey(const Key('physical-count')), count);
}

Future<void> page(
  WidgetTester tester,
  PhysicalTestApi api, {
  String team = 'team-a',
  Brightness brightness = Brightness.light,
  double scale = 1,
}) async {
  addTearDown(() => tester.pumpWidget(const SizedBox()));
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.create(brightness),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: RepaintBoundary(
        key: const Key('physical-qa'),
        child: TeamPhysicalMemoryPage(api: api, teamId: team),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> search(WidgetTester tester, String question) async {
  await tester.enterText(find.byKey(const Key('physical-question')), question);
  await tap(tester, find.byKey(const Key('physical-find')));
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
  testWidgets('failed confirmation keeps the draft and retry identity', (
    tester,
  ) async {
    final api = PhysicalTestApi()..failure = Exception('Connection failed');
    await form(tester, api);
    await fill(tester);
    await tap(tester, find.byKey(const Key('physical-confirm')));
    expect(api.writes.single['observed_count'], isNull);
    expect(api.writes.single['bin_id'], 'bin-a');
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('physical-native-name')))
          .controller!
          .text,
      'Our hoodie',
    );
    await tap(tester, find.byKey(const Key('physical-confirm')));
    expect(api.writes.length, 2);
    expect(api.writes.last['request_id'], api.writes.first['request_id']);
  });
  testWidgets('zero count and pending save wait for a verified receipt', (
    tester,
  ) async {
    final api = PhysicalTestApi()..saving = Completer<Map<String, dynamic>>();
    String? saved;
    await form(tester, api, saved: (v) => saved = v);
    await fill(tester, count: '0');
    await tap(tester, find.byKey(const Key('physical-confirm')));
    expect(api.writes.single['observed_count'], 0);
    expect(saved, isNull);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('physical-confirm')))
          .onPressed,
      isNull,
    );
    api.saving!.complete({
      'memory_id': 'memory-a',
      'observation_id': 'event-a',
    });
    await tester.pumpAndSettle();
    expect(saved, 'memory-a');
  });
  testWidgets('viewer cannot confirm and denial clears private history', (
    tester,
  ) async {
    final api = PhysicalTestApi();
    final record = {
      ...catalog,
      'memory_id': 'memory-a',
      'native_label': 'Our hoodie',
      'placements': [
        {
          'placement_id': 'place-a',
          'space_id': 'space-a',
          'space_name': 'Stockroom',
          'bin_id': 'bin-a',
          'bin_name': 'Bin 12',
          'revision': 3,
          'observed_count': 4,
          'actor_label': 'Alex',
          'confirmed_at': '2026-10-13T10:00:00Z',
        },
      ],
    };
    bool lost = false;
    await form(
      tester,
      api,
      record: record,
      viewer: true,
      access: () => lost = true,
    );
    expect(find.byKey(const Key('physical-confirm')), findsNothing);
    api.revoked = true;
    await tap(tester, find.text('History'));
    expect(lost, isTrue);
    expect(api.writes, isEmpty);
  });
  testWidgets('reconfirmation sends native identity and known revision', (
    tester,
  ) async {
    final api = PhysicalTestApi()..failure = Exception('Conflict');
    final record = {
      ...catalog,
      'memory_id': 'memory-a',
      'native_label': 'Our hoodie',
      'placements': [
        {
          'placement_id': 'place-a',
          'space_id': 'space-a',
          'space_name': 'Stockroom',
          'bin_id': 'bin-a',
          'bin_name': 'Bin 12',
          'revision': 3,
          'observed_count': 4,
          'actor_label': 'Alex',
          'confirmed_at': '2026-10-13T10:00:00Z',
        },
      ],
    };
    await form(tester, api, record: record);
    await tap(tester, find.text('Add another location'));
    await tap(tester, find.text('Stockroom / Bin 12').last);
    await tap(tester, find.byKey(const Key('physical-confirm')));
    expect(api.writes.single['expected_revision'], 3);
    expect(api.writes.single['memory_id'], 'memory-a');
    expect(api.writes.single.containsKey('connection_id'), isFalse);
  });
  testWidgets(
    'ambiguous variants require selection and barcode preserves zeros',
    (tester) async {
      final api = PhysicalTestApi()
        ..rows = [
          catalog,
          {...catalog, 'variant_gid': 'variant-b', 'variant_title': 'Black L'},
        ];
      await page(tester, api);
      await tap(tester, find.text('Search by barcode'));
      await search(tester, '0012');
      expect(api.queries.single['barcode'], '0012');
      expect(find.byKey(const Key('physical-confirm')), findsNothing);
      api.rows = [catalog];
      await tap(tester, find.text('Hoodie / Black L'));
      expect(api.queries.last['variant_gid'], 'variant-b');
      expect(find.text('Confirm a physical location'), findsOneWidget);
    },
  );
  testWidgets('late private lookup is ignored after an account switch', (
    tester,
  ) async {
    final api = PhysicalTestApi()..reading = Completer<Map<String, dynamic>>();
    await page(tester, api);
    await search(tester, 'hoodie');
    api.actor = 'actor-b';
    api.reading!.complete(answer([catalog]));
    await tester.pumpAndSettle();
    expect(find.text('Confirm a physical location'), findsNothing);
  });
  testWidgets('periodic revocation clears the displayed private result', (
    tester,
  ) async {
    final api = PhysicalTestApi();
    await page(tester, api);
    await search(tester, 'hoodie');
    expect(find.text('Confirm a physical location'), findsOneWidget);
    api.revoked = true;
    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();
    expect(find.text('Confirm a physical location'), findsNothing);
  });
  for (final brightness in Brightness.values) {
    testWidgets(
      'physical memory scrolls safely at 320pt and 3.4x in $brightness',
      (tester) async {
        tester.view.physicalSize = const Size(320, 780);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await page(
          tester,
          PhysicalTestApi(),
          brightness: brightness,
          scale: 3.4,
        );
        await search(tester, 'hoodie');
        await tester.scrollUntilVisible(
          find.byKey(const Key('physical-native-name')),
          150,
          scrollable: find
              .descendant(
                of: find.byType(ListView).first,
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
  if (const bool.fromEnvironment('FINDEZ_VISUAL_QA')) {
    testWidgets('physical memory sample layout capture', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await page(tester, PhysicalTestApi());
      await search(tester, 'hoodie');
      await tester.ensureVisible(find.text('Confirm a physical location'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('physical-qa')),
        );
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '/private/tmp/findez-physical-memory-qa.png',
        ).writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    });
  }
}
