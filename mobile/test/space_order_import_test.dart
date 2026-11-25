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
  for (final duplicate in [false, true]) {
    testWidgets('Scoped file review, duplicate=$duplicate', (tester) async {
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
      await tester.tap(find.text('Choose order file'));
      await tester.pumpAndSettle();
      if (duplicate) {
        expect(find.textContaining('already in organization'), findsOneWidget);
        expect(find.text('Review order lines'), findsNothing);
        expect(calls.length, 1);
        return;
      }
      await tester.tap(find.text('Review order lines'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('40 recorded in Fasteners · A1'),
        findsOneWidget,
      );
      expect(calls.every((s) => s.endsWith('/preview')), isTrue);
      await tester.enterText(find.byType(TextField).first, 'goBILDA');
      await tester.ensureVisible(find.text('Confirm 1 order lines'));
      await tester.tap(find.text('Confirm 1 order lines'));
      await tester.pumpAndSettle();
      expect(calls.where((s) => s.endsWith('/import')).length, 1);
    });
  }
}
