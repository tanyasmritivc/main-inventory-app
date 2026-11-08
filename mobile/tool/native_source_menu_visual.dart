// Synthetic, account-free native menu acceptance harness. Never a release target.
import 'package:flutter/material.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/chat/chat_source_menu.dart';

void main() => runApp(const MenuAudit());

class MenuAudit extends StatefulWidget {
  const MenuAudit({super.key});
  @override
  State<MenuAudit> createState() => _MenuAuditState();
}

class _MenuAuditState extends State<MenuAudit> {
  bool dark = true;
  final selected = <String>[];
  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: AppTheme.create(dark ? Brightness.dark : Brightness.light),
    home: Builder(
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text('Native menu QA')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextButton(
                onPressed: () => setState(() => dark = !dark),
                child: Text(dark ? 'Use light mode' : 'Use dark mode'),
              ),
              for (final space in [false, true])
                FilledButton(
                  onPressed: () async {
                    final choice = await showChatSourceMenu(
                      context,
                      GlobalKey(),
                      questionsOnly: space,
                    );
                    if (mounted) {
                      setState(() => selected.add(choice ?? 'dismissed'));
                    }
                  },
                  child: Text(
                    space ? 'Open Space attachments' : 'Open main menu',
                  ),
                ),
              SelectableText('Selected: ${selected.join(', ')}'),
            ],
          ),
        ),
      ),
    ),
  );
}
