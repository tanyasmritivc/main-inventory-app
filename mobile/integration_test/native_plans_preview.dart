// Interactive simulator harness: real UIKit Settings with synthetic account data.
import 'package:flutter/material.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/profile/account_button.dart';

import '../test/support/hierarchy_fixture.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final fixture = HierarchyFixture();
  await fixture.initialize();
  fixture.respond = (_) => {'user_id': 'actor-a', 'display_name': 'Alex'};
  runApp(
    MaterialApp(
      theme: AppTheme.create(Brightness.light),
      darkTheme: AppTheme.create(Brightness.dark),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Settings navigation preview'),
          actions: [AccountButton(api: fixture.api)],
        ),
        body: const Center(child: Text('Open your profile, then Plans.')),
      ),
    ),
  );
}
