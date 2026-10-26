import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/ui/app_text.dart';

/// Own the root dialog so a nested Space navigator is never popped by cleanup.
Future<T> runWithCaptureProgress<T>({
  required BuildContext context,
  required Future<T> Function() extract,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final route = DialogRoute<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => PopScope(
      canPop: false,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppTheme.adaptive(dialogContext, const Color(0xFF1C1C1E)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: AppTheme.adaptive(dialogContext, Colors.white),
                ),
                const SizedBox(height: 16),
                AppText(
                  'Extracting items…',
                  style: TextStyle(
                    color: AppTheme.foreground(dialogContext, Colors.white),
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  unawaited(navigator.push<void>(route));
  try {
    return await extract();
  } finally {
    // Remove this exact route, even if another sheet was opened in the meantime.
    if (navigator.mounted && route.isActive) navigator.removeRoute(route);
  }
}
