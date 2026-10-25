import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/ui/app_text.dart';
import '../../core/api_error.dart';
import '../chat/chat_progress.dart';
import 'package:dio/dio.dart';

/// Own the root dialog so a nested Space navigator is never popped by cleanup.
Future<T> runWithCaptureProgress<T>({
  required BuildContext context,
  required Future<T> Function() extract,
  bool retryOnFailure = false,
}) async {
  while (true) {
    try {
      return await _runCapture(context: context, extract: extract);
    } catch (error) {
      final canRetry =
          error is DioException &&
          (error.type == DioExceptionType.receiveTimeout ||
              error.type == DioExceptionType.connectionTimeout ||
              error.type == DioExceptionType.connectionError ||
              (error.response?.statusCode ?? 0) >= 500);
      if (!retryOnFailure ||
          !canRetry ||
          !context.mounted ||
          ModalRoute.of(context)?.isCurrent == false) {
        rethrow;
      }
      final retry = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const AppText('Photo analysis interrupted'),
          content: AppText(friendlyApiError(error)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const AppText('Not now'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const AppText('Retry photo'),
            ),
          ],
        ),
      );
      if (retry != true || !context.mounted) rethrow;
    }
  }
}

Future<T> _runCapture<T>({
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
                const ShinyStatusText('Extracting items…'),
                const SizedBox(height: 12),
                const SizedBox(
                  width: 220,
                  child: AppText(
                    'Reading objects and details. Crowded photos can take longer.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, height: 1.4),
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
