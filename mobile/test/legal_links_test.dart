import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/legal_links.dart';

void main() {
  test('both legal documents use the public canonical HTTPS site', () {
    expect(
      legalDocumentUrl(LegalDocumentKind.privacy).toString(),
      'https://findez.ai/privacy',
    );
    expect(
      legalDocumentUrl(LegalDocumentKind.terms).toString(),
      'https://findez.ai/terms',
    );
  });
  testWidgets(
    'opening a document launches once and returns to the previous screen',
    (tester) async {
      final seen = <Uri>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => LegalLinkPage(
                    document: LegalDocumentKind.privacy,
                    openUrl: (uri) async {
                      seen.add(uri);
                      return true;
                    },
                  ),
                ),
              ),
              child: const Text('Privacy'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Privacy'));
      await tester.pumpAndSettle();
      expect(seen, [Uri.parse('https://findez.ai/privacy')]);
      expect(find.text('Privacy'), findsOneWidget);
      expect(find.byType(LegalLinkPage), findsNothing);
    },
  );
  testWidgets('a failed browser launch exposes the canonical URL and a retry', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: LegalLinkPage(
          document: LegalDocumentKind.terms,
          openUrl: (_) async {
            attempts++;
            return false;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('https://findez.ai/terms'), findsOneWidget);
    expect(find.textContaining('browser could not open'), findsOneWidget);
    await tester.tap(find.text('Open Terms of Service'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Copy link'), findsOneWidget);
  });
  testWidgets('a late browser result cannot update a disposed page', (
    tester,
  ) async {
    final result = Completer<bool>();
    await tester.pumpWidget(
      MaterialApp(
        home: LegalLinkPage(
          document: LegalDocumentKind.privacy,
          openUrl: (_) => result.future,
        ),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    result.complete(false);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
