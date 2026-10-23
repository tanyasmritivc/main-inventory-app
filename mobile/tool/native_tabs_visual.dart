import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/world/native_bottom_tabs.dart';

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
            Text(
              ['Ask', 'Spaces', 'More'][selected],
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 30,
                color: dark ? Colors.white : Colors.black,
              ),
            ),
            TextButton(
              onPressed: () => setState(() => dark = !dark),
              child: const Text('Switch appearance'),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Center(
                child: SizedBox(
                  width: 288,
                  child: NativeBottomTabs(
                    selected: selected,
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
