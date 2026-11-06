import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/core/ui/native_presentation.dart';
import 'package:mobile/features/world/native_bottom_tabs.dart';
import 'package:mobile/features/world/retained_tab_transition.dart';

// Native touch/animation audit: run normally, without WidgetTester pointer timing.
// This entry point uses no APIs or customer data. Production targets lib/main.dart.
void main() {
  if (kReleaseMode) throw UnsupportedError('Debug audit only');
  runApp(const _Audit());
}

class _Audit extends StatefulWidget {
  const _Audit();
  @override
  State<_Audit> createState() => _AuditState();
}

class _AuditState extends State<_Audit> {
  int selected = 0;
  bool dark = true;
  @override
  Widget build(BuildContext context) => MaterialApp(
    builder: (context, child) => GestureDetector(
      onTap: MediaQuery.viewInsetsOf(context).bottom > 0
          ? () => FocusManager.instance.primaryFocus?.unfocus()
          : null,
      behavior: HitTestBehavior.translucent,
      child: child,
    ),
    theme: AppTheme.create(dark ? Brightness.dark : Brightness.light),
    home: Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 60),
            Expanded(
              child: RetainedTabTransition(
                index: selected,
                children: [
                  for (final title in ['Ask', 'Spaces', 'More'])
                    Center(
                      child: Builder(
                        builder: (context) => Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(title, style: const TextStyle(fontSize: 30)),
                            TextButton(
                              onPressed: () async {
                                final chosen = await showNativeChoices(
                                  context,
                                  title: 'Inventory',
                                  opaque: true,
                                  rows: [
                                    for (final name in [
                                      'Bathroom',
                                      'Garage',
                                      'Home Workshop',
                                      'Keyboard',
                                      'Travel',
                                    ])
                                      {'id': name, 'title': name},
                                  ],
                                );
                                if (context.mounted && chosen != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(chosen)),
                                  );
                                }
                              },
                              child: const Text('New space'),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => setState(() => dark = !dark),
              child: const Text('Switch appearance'),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Center(
                child: SizedBox(
                  width: 358,
                  child: NativeBottomTabs(
                    selected: selected,
                    onScan: () => setState(() => selected = 0),
                    onSelected: (i) => setState(() => selected = i),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
