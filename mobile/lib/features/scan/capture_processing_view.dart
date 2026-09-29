import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

class CaptureProcessingView extends StatelessWidget {
  const CaptureProcessingView({super.key, required this.onKeepShooting});

  final VoidCallback onKeepShooting;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Processing', style: TextStyle(color: t.ink, fontSize: 27)),
              const Spacer(),
              Center(child: CircularProgressIndicator(color: t.accent)),
              const SizedBox(height: 28),
              Text(
                'Looking at this photograph',
                textAlign: TextAlign.center,
                style: TextStyle(color: t.ink, fontSize: 22),
              ),
              const SizedBox(height: 12),
              Text(
                'The photo is saved on this phone. You can keep shooting while it is reviewed.',
                textAlign: TextAlign.center,
                style: TextStyle(color: t.text2, fontSize: 15),
              ),
              const Spacer(),
              FilledButton(
                onPressed: onKeepShooting,
                child: const Text('Keep shooting'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UnidentifiedCaptureSheet extends StatelessWidget {
  const UnidentifiedCaptureSheet({super.key, required this.photoBytes});

  final Uint8List photoBytes;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Not recognised',
              style: TextStyle(color: t.ink, fontSize: 25),
            ),
            const SizedBox(height: 10),
            Text(
              'FindEZ could not identify an object in this photograph. The photo is saved on this phone.',
              style: TextStyle(color: t.text2, fontSize: 15),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTokens.radius),
              child: SizedBox(
                height: 190,
                child: photoBytes.isEmpty
                    ? ColoredBox(
                        color: t.raised,
                        child: Center(
                          child: Text(
                            'Photo unavailable',
                            style: TextStyle(color: t.text2),
                          ),
                        ),
                      )
                    : Image.memory(
                        photoBytes,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => ColoredBox(
                          color: t.raised,
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
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Add by hand'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep photo for later'),
            ),
          ],
        ),
      ),
    );
  }
}
