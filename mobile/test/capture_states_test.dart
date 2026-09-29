import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/app_theme.dart';
import 'package:mobile/core/pending_captures.dart';
import 'package:mobile/features/scan/capture_processing_view.dart';
import 'package:mobile/features/scan/capture_recovery_sheet.dart';

void main() {
  testWidgets('processing lets the user keep shooting', (tester) async {
    var closed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: CaptureProcessingView(onKeepShooting: () => closed = true),
      ),
    );
    expect(find.text('Looking at this photograph'), findsOneWidget);
    await tester.tap(find.text('Keep shooting'));
    expect(closed, isTrue);
  });

  testWidgets('capture recovery keeps previously extracted objects', (
    tester,
  ) async {
    final capture = PendingCapture(
      id: 'one',
      userId: 'user-one',
      workspaceId: 'personal',
      place: 'Workshop',
      createdAt: DateTime(2026),
      photoPath: '/does-not-exist.jpg',
      extractedItems: const [
        {'name': 'Clamp', 'category': 'Tools', 'confidence': 0.9},
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: CaptureRecoverySheet(
            capture: capture,
            message: 'No connection. The photo will wait until you try again.',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Capture stopped'), findsOneWidget);
    expect(find.text('Clamp'), findsOneWidget);
    expect(find.text('Review what was found'), findsOneWidget);
  });

  testWidgets('unrecognized photo offers manual add and retained photo', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: UnidentifiedCaptureSheet(photoBytes: Uint8List(0)),
        ),
      ),
    );
    expect(find.text('Not recognised'), findsOneWidget);
    expect(find.text('Add by hand'), findsOneWidget);
    expect(find.text('Keep photo for later'), findsOneWidget);
  });
}
