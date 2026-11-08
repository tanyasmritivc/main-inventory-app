import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/core/inventory_context.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/scan/import_sheet_page.dart';
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
  testWidgets(
    'direct import fixes Space, bypasses review and resumes the same session after failure',
    (tester) async {
      final picker = _Picker()
        ..result = FilePickerResult([
          PlatformFile(
            name: 'items.json',
            size: 2,
            readStream: Stream.value([91, 93]),
          ),
        ]);
      FilePicker.platform = picker;
      var attempts = 0;
      fixture.requests.clear();
      fixture.respond = (request) {
        if (request.path.endsWith('/connectors/imports')) {
          final fields = Map.fromEntries((request.data as dio.FormData).fields);
          expect(fields['direct'], 'true');
          expect(fields['space_id'], 'garage-space');
          expect(fields['location'], 'Garage');
          return {'id': 'session', 'kind': 'inventory', 'status': 'review'};
        }
        expect(
          request.path,
          '/inventories/inventory-a/connectors/imports/session/import',
        );
        attempts++;
        if (attempts == 1) throw dio.DioException(requestOptions: request);
        return {
          'id': 'session',
          'status': 'complete',
          'counts': {
            'imported': 2,
            'skipped': 0,
            'failed': 0,
            'pending': 0,
            'total': 2,
          },
        };
      };
      final api = ApiClient.forInventory(
        fixture.api,
        InventoryContext.fromJson(
          inventory('inventory-a'),
          accountId: 'actor-a',
          expectedInventory: 'inventory-a',
        ),
        isCurrent: () => true,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.create(Brightness.light),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  final saved = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => ImportSheetPage(
                        api: api,
                        location: 'Garage',
                        spaceId: 'garage-space',
                      ),
                    ),
                  );
                  expect(saved, true);
                },
                child: const Text('Import'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Import'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose file'));
      await tester.pumpAndSettle();
      expect(find.text('Resume import'), findsOneWidget);
      expect(find.text('Review import'), findsNothing);
      await tester.tap(find.text('Resume import'));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(
        fixture.requests
            .where((r) => r.path.endsWith('/connectors/imports'))
            .length,
        1,
      );
      expect(find.text('Import'), findsOneWidget);
      expect(AppTheme.lightBg, const Color(0xFFF6F7F9));
      expect(AppTheme.lightSurface, Colors.white);
    },
  );
}
