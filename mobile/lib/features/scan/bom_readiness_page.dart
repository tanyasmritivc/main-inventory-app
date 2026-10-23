import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import 'import_sheet_page.dart';

/// Existing entry point now shares the reviewed connector workflow.
class BomReadinessPage extends StatelessWidget {
  const BomReadinessPage({
    super.key,
    required this.api,
    required this.location,
    this.shareId,
  });
  final ApiClient api;
  final String location;
  final String? shareId;
  @override
  Widget build(BuildContext context) => ImportSheetPage(
    api: api,
    location: location,
    shareId: shareId,
    kind: 'bom',
  );
}
