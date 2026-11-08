// Account-free UI harness. Release target remains lib/main.dart.
import 'package:flutter/material.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/chat/native_scan_progress.dart';
import 'package:mobile/features/chat/scan_region.dart';
import 'package:mobile/features/world/native_bottom_tabs.dart';
import 'package:mobile/features/world/retained_tab_transition.dart';

void main() => runApp(const ScanAudit());

class ScanAudit extends StatefulWidget {
  const ScanAudit({super.key});
  @override
  State<ScanAudit> createState() => _ScanAuditState();
}

class _ScanAuditState extends State<ScanAudit> {
  bool dark = true, scanning = true, large = false;
  int stage = 0, selected = 0, stops = 0;
  final elapsed = Stopwatch()..start();
  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: AppTheme.create(dark ? Brightness.dark : Brightness.light),
    home: Builder(
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text('Native scan QA')),
        body: SafeArea(
          child: Column(
            children: [
              Wrap(
                children: [
                  TextButton(
                    onPressed: () => setState(() => dark = !dark),
                    child: const Text('Theme'),
                  ),
                  TextButton(
                    onPressed: () => setState(() => large = !large),
                    child: const Text('Large text'),
                  ),
                  TextButton(
                    onPressed: () => setState(() => stage++),
                    child: const Text('Advance'),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      scanning = true;
                      stage = 0;
                    }),
                    child: const Text('Restart'),
                  ),
                  TextButton(
                    onPressed: () => setState(() => scanning = false),
                    child: const Text('Complete'),
                  ),
                ],
              ),
              Text('Page: ${selected == 0 ? 'Ask' : 'Spaces'} · Stops: $stops'),
              Expanded(
                child: RetainedTabTransition(
                  index: selected,
                  children: [
                    MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        textScaler: TextScaler.linear(large ? 2.6 : 1),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: scanning
                            ? NativeScanProgress(
                                key: ValueKey('scan-$stops'),
                                image: const AssetImage(
                                  'assets/onboarding/sample_workbench.jpg',
                                ),
                                message: stage == 0
                                    ? 'Finding objects...'
                                    : stage == 1
                                    ? 'Reading details...'
                                    : 'Checked 2 of 2',
                                regions: stage == 0
                                    ? []
                                    : [
                                        ScanRegion(
                                          0,
                                          const Rect.fromLTRB(.1, .2, .35, .6),
                                          stage == 1
                                              ? ScanRegionPhase.checking
                                              : ScanRegionPhase.checked,
                                        ),
                                        const ScanRegion(
                                          1,
                                          Rect.fromLTRB(.55, .1, .8, .5),
                                          ScanRegionPhase.unreadable,
                                        ),
                                      ],
                                onStop: () => setState(() {
                                  stops++;
                                  scanning = false;
                                }),
                              )
                            : const Center(
                                child: Text('Existing draft review handoff'),
                              ),
                      ),
                    ),
                    const Center(child: Text('Spaces retained page')),
                  ],
                ),
              ),
              NativeBottomTabs(
                selected: selected,
                onSelected: (index) {
                  debugPrint(
                    'NATIVE_PAGE_COMMIT $index ${elapsed.elapsedMilliseconds}',
                  );
                  setState(() => selected = index);
                },
                onScan: () => setState(() {
                  selected = 0;
                  scanning = true;
                }),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
