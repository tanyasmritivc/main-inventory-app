import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/features/announcements/announcement_host.dart';
import 'package:mobile/features/announcements/announcement_widgets.dart';
import '../test/support/announcement_fixture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    AppTheme.create(Brightness.dark);
    AppTheme.create(Brightness.light);
    await GoogleFonts.pendingFonts();
  });
  for (final mode in Brightness.values) {
    for (final variant in [
      'access',
      'pricing',
      'whats_new',
      'banner',
      'plan',
    ]) {
      testWidgets('announcement ${mode.name} $variant', (tester) async {
        final boundary = GlobalKey();
        late BuildContext launcher;
        var clicked = false, closed = false;
        final campaign = <String, dynamic>{
          ...welcomeCampaign,
          'design': variant,
          'title': switch (variant) {
            'pricing' => 'FindEZ is free to explore.',
            'whats_new' => 'Photos scan on their own.',
            _ => "You're in early.",
          },
          if (variant == 'pricing')
            'body': "Paid plans may come later. Here's what stays free.",
          if (variant == 'whats_new') 'cta': 'Try it',
          if (variant == 'whats_new') 'action': 'capture',
        };
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.create(mode),
              home: Builder(
                builder: (context) {
                  launcher = context;
                  return Scaffold(
                    body: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 32),
                            const Text(
                              'FindEZ',
                              style: TextStyle(fontSize: 24),
                            ),
                            const SizedBox(height: 24),
                            if (variant == 'banner')
                              AnnouncementBanner(
                                planName: 'Free pre-launch access',
                                onTap: () => clicked = true,
                                onDismiss: () => closed = true,
                              ),
                            if (variant == 'plan')
                              AnnouncementPlanRow(
                                access: announcementAccess,
                                onTap: () => clicked = true,
                              ),
                            if (variant != 'banner' && variant != 'plan')
                              const Expanded(
                                child: Center(
                                  child: Text("Find what's in your world."),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (variant != 'banner' && variant != 'plan' && launcher.mounted) {
          Navigator.of(
            launcher,
          ).push(announcementRoute(launcher, campaign, announcementAccess));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 900));
        }
        expect(tester.takeException(), isNull);
        final frame =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final bytes = (await frame.toByteData(
          format: ui.ImageByteFormat.png,
        ))!.buffer.asUint8List();
        final file = File(
          '${Directory.systemTemp.path}/announcement-${mode.name}-$variant.png',
        );
        await file.writeAsBytes(bytes);
        frame.dispose();
        debugPrint('ANNOUNCEMENT_IMAGE ${file.path}');
        if (variant == 'banner') {
          await tester.tap(find.textContaining('Free right now'));
          expect(clicked, true);
          await tester.tap(find.byTooltip('Dismiss announcement banner'));
          expect(closed, true);
        } else if (variant == 'plan') {
          await tester.tap(find.text('Your plan'));
          expect(clicked, true);
        } else if (variant == 'access') {
          await tester.dragFrom(
            tester.getTopLeft(find.byType(AnnouncementSheet)) +
                const Offset(180, 12),
            const Offset(0, 650),
          );
          await tester.pumpAndSettle();
          expect(find.byType(AnnouncementSheet), findsNothing);
        } else {
          await tester.ensureVisible(
            find.text(variant == 'whats_new' ? 'Try it' : 'Got it'),
          );
          await tester.tap(
            find.text(variant == 'whats_new' ? 'Try it' : 'Got it'),
          );
          await tester.pumpAndSettle();
          expect(find.byType(AnnouncementSheet), findsNothing);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    for (final scale in [1.0, 2.6]) {
      testWidgets('native viewport $size text $scale reduced motion', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final boundary = GlobalKey();
        late BuildContext launcher;
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.create(Brightness.dark),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  disableAnimations: true,
                  textScaler: TextScaler.linear(scale),
                ),
                child: child!,
              ),
              home: Builder(
                builder: (context) {
                  launcher = context;
                  return const Scaffold(body: Center(child: Text('FindEZ')));
                },
              ),
            ),
          ),
        );
        if (!launcher.mounted) return;
        Navigator.of(launcher).push(
          announcementRoute(launcher, welcomeCampaign, announcementAccess),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final frame =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final bytes = (await frame.toByteData(
          format: ui.ImageByteFormat.png,
        ))!.buffer.asUint8List();
        final file = File(
          '${Directory.systemTemp.path}/announcement-native-${size.width.toInt()}-$scale.png',
        );
        await file.writeAsBytes(bytes);
        frame.dispose();
        debugPrint('ANNOUNCEMENT_IMAGE ${file.path}');
        await tester.scrollUntilVisible(
          find.text('Got it'),
          200,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(find.text('Got it'));
        await tester.pumpAndSettle();
        expect(find.byType(AnnouncementSheet), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
