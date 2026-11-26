import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';

import 'package:mobile/features/world/space_order_import.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'support/hierarchy_fixture.dart';

class _Picker extends FilePicker {
  FilePickerResult? result;
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async => result;
}

void main() {
  final fixture = HierarchyFixture();
  setUpAll(fixture.initialize);
  tearDownAll(() => Supabase.instance.dispose());
  testWidgets('Order setup fits a narrow phone at large text sizes', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: SpaceOrderImport(
          api: fixture.api,
          organizationId: 'team',
          spaceId: 'shelf',
          spaceName: 'Haas Engineering Workshop',
        ),
      ),
    );
    expect(find.text('Destination Space'), findsOneWidget);
    await tester.dragUntilVisible(
      find.byType(Switch).hitTestable(),
      find.byType(ListView),
      const Offset(0, -140),
    );
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    final choose = find.text('Choose order file');
    await tester.dragUntilVisible(
      choose.hitTestable(),
      find.byType(ListView),
      const Offset(0, -100),
    );
    expect(choose.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final name in ['screenshot.png', 'orders.zip']) {
    testWidgets('Rejects $name before uploading', (tester) async {
      FilePicker.platform = _Picker()
        ..result = FilePickerResult([PlatformFile(name: name, size: 8)]);
      fixture.respond = (_) => fail('Unsupported file reached the API');
      await tester.pumpWidget(
        MaterialApp(
          home: SpaceOrderImport(
            api: fixture.api,
            organizationId: 'team',
            spaceId: 'shelf',
            spaceName: 'Fasteners',
          ),
        ),
      );
      await tester.tap(find.text('Choose order file'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Choose an Excel'), findsOneWidget);
    });
  }
  for (final scenario in ['review', 'duplicate', 'direct']) {
    final duplicate = scenario == 'duplicate';
    testWidgets('Scoped order import: $scenario', (tester) async {
      FilePicker.platform = _Picker()
        ..result = FilePickerResult([
          PlatformFile(
            name: 'order.csv',
            size: 4,
            readStream: Stream.value([1, 2, 3, 4]),
          ),
        ]);
      final calls = <String>[];
      fixture.respond = (request) {
        final body = Map.fromEntries((request.data as dio.FormData).fields);
        expect(body['space_id'], 'shelf');
        calls.add(request.path);
        if (request.path.endsWith('/preview')) {
          return {
            'digest': 'hash',
            'tables': [],
            'documents': [],
            'assignments': [],
            'space_review': {
              'duplicate': duplicate,
              'matches': [
                {
                  'name': 'M4 screws',
                  'sku': 'S4',
                  'item_name': 'M4 screws',
                  'space_name': 'Fasteners',
                  'location': 'A1',
                  'recorded_quantity': 40,
                },
              ],
            },
            'rows': [
              {
                'name': 'M4 screws',
                'sku': 'S4',
                'order': 'O1',
                'line': '1',
                'status': 'ordered',
                'quantity': '2',
                'pack': '50',
                'source_file': 'order.csv',
                'source_sheet': '',
                'source_row': 2,
              },
            ],
          };
        }
        expect(request.path, '/commerce/organizations/team/orders/import');
        expect(body['supplier'], 'goBILDA');
        expect(jsonDecode(body['rows']!)[0]['pack'], '50');
        return {'created': 1};
      };
      await tester.pumpWidget(
        MaterialApp(
          home: SpaceOrderImport(
            api: fixture.api,
            organizationId: 'team',
            spaceId: 'shelf',
            spaceName: 'Fasteners',
          ),
        ),
      );
      if (scenario == 'direct') {
        await tester.enterText(find.byType(TextField).first, 'goBILDA');
      }
      await tester.tap(find.text('Choose order file'));
      await tester.pumpAndSettle();
      if (scenario == 'direct') {
        expect(calls.map((path) => path.split('/').last), [
          'preview',
          'import',
        ]);
        return;
      }
      if (duplicate) {
        expect(find.textContaining('already in organization'), findsOneWidget);
        expect(find.text('Review order lines'), findsNothing);
        expect(calls.length, 1);
        return;
      }
      await tester.scrollUntilVisible(
        find.textContaining('40 recorded in Fasteners'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.textContaining('40 recorded in Fasteners · A1'),
        findsOneWidget,
      );
      expect(calls.every((s) => s.endsWith('/preview')), isTrue);
      await tester.scrollUntilVisible(
        find.byType(TextField).first,
        -180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(find.byType(TextField).first, 'goBILDA');
      await tester.scrollUntilVisible(
        find.text('Confirm 1 order line'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Confirm 1 order line'));
      await tester.pumpAndSettle();
      expect(calls.where((s) => s.endsWith('/import')).length, 1);
    });
  }
}
