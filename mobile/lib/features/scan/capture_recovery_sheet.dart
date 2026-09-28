import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/pending_captures.dart';
import '../inventory/world_views.dart';

class CaptureRecoverySheet extends StatelessWidget {
  const CaptureRecoverySheet({
    super.key,
    required this.capture,
    required this.message,
  });

  final PendingCapture capture;
  final String message;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final found = capture.extractedItems ?? const <Map<String, dynamic>>[];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Capture stopped',
                style: TextStyle(color: t.ink, fontSize: 24),
              ),
              const SizedBox(height: 8),
              Text(message, style: TextStyle(color: t.text2, fontSize: 15)),
              const SizedBox(height: 8),
              Text(
                'The photograph is saved on this phone.',
                style: TextStyle(color: t.ink, fontSize: 14),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTokens.radius),
                child: SizedBox(
                  height: 180,
                  child: Image.file(
                    File(capture.photoPath),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => ColoredBox(
                      color: t.s2,
                      child: Center(
                        child: Text(
                          'Photo unavailable',
                          style: TextStyle(color: t.text2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (found.isNotEmpty) ...[
                const SizedBox(height: 14),
                WorldSection(
                  title: 'Already identified',
                  children: [
                    for (final item in found)
                      WorldRow(
                        title: (item['name'] ?? 'Needs a name').toString(),
                        subtitle: (item['category'] ?? '').toString(),
                        count: item['confidence'] is num
                            ? ((item['confidence'] as num).toDouble() * 100)
                                  .toStringAsFixed(0)
                            : '',
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  found.isEmpty ? 'Try again' : 'Review what was found',
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep for later'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
