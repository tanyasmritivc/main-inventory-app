import 'dart:io';

import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_client.dart';
import 'package:mobile/features/import/import_sheet_page.dart';

class _ImportApi extends ApiClient {
  _ImportApi() : super(baseUrl: 'https://invalid.test');

  bool called = false;

  @override
  Future<SpreadsheetImportResult> importSpreadsheet({
    required dio.MultipartFile file,
    required String location,
    String? shareId,
  }) async {
    called = true;
    expect(file.filename, 'items.json');
    expect(location, 'Garage');
    return SpreadsheetImportResult(inserted: 1, failures: 0, totalFound: 1);
  }
}

void main() {
  testWidgets('a shared JSON inventory file reaches the import API', (
    tester,
  ) async {
    late Directory directory;
    late File file;
    await tester.runAsync(() async {
      directory = await Directory.systemTemp.createTemp('findez-json-import-');
      file = File('${directory.path}/items.json');
      await file.writeAsString('[{"name":"Screwdriver","quantity":1}]');
    });
    addTearDown(() => directory.delete(recursive: true));
    final api = _ImportApi();

    await tester.pumpWidget(
      MaterialApp(
        home: ImportSheetPage(
          api: api,
          location: 'Garage',
          initialFilePath: file.path,
        ),
      ),
    );
    for (var attempt = 0; attempt < 20 && !api.called; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pump(const Duration(milliseconds: 300));

    expect(api.called, isTrue);
    expect(find.text('Import complete'), findsOneWidget);
  });
}
