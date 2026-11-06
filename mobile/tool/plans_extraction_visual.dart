// Synthetic, network-free audit. Never imported by the production application.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/profile/plans_page.dart';
import 'package:mobile/features/chat/extraction_details_sheet.dart';

void main() {
  if (kReleaseMode) throw UnsupportedError('Debug audit only');
  runApp(const Audit());
}

class Audit extends StatefulWidget {
  const Audit({super.key});
  @override
  State<Audit> createState() => _AuditState();
}

class _AuditState extends State<Audit> {
  bool dark = true;
  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: AppTheme.create(dark ? Brightness.dark : Brightness.light),
    home: Builder(
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text('Plans and extraction audit')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const PlansPage()),
                ),
                child: const Text('Plans'),
              ),
              for (final count in [2, 1000])
                TextButton(
                  onPressed: () => showExtractionDetails(context, [
                    for (var i = 0; i < count; i++)
                      {
                        'selected': true,
                        'item': {
                          'name': i == 0
                              ? 'H1B'
                              : i == 1
                              ? 'Eraser'
                              : 'Part $i',
                          'category': i == 0 ? 'Other' : 'Stationery',
                          'quantity': i == 0 ? 2 : 1,
                          if (i == 1) 'scan_evidence': {'needs_review': true},
                        },
                      },
                  ]),
                  child: Text('Extraction $count'),
                ),
              TextButton(
                onPressed: () => setState(() => dark = !dark),
                child: const Text('Switch appearance'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
