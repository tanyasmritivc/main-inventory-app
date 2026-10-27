import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/ui/app_text.dart';
import '../../core/api_error.dart';
import '../../widgets/pip_extract_loader.dart';
import 'package:dio/dio.dart';

class CaptureCancelled implements Exception {}

class CaptureProgressToken extends CancelToken {
  ValueChanged<String>? onProgress;
  void report(String message) {
    if (!isCancelled) onProgress?.call(message);
  }
}

/// Own the root dialog so a nested Space navigator is never popped by cleanup.
Future<T> runWithCaptureProgress<T>({
  required BuildContext context,
  required Future<T> Function(CaptureProgressToken cancelToken) extract,
  bool retryOnFailure = false,
  int Function(T result)? itemCount,
}) async {
  while (true) {
    try {
      return await _runCapture(
        context: context,
        extract: extract,
        itemCount: itemCount,
      );
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
  required Future<T> Function(CaptureProgressToken cancelToken) extract,
  int Function(T result)? itemCount,
}) async {
  final token = CaptureProgressToken();
  final loader = showPipExtractLoader(
    context,
    onStop: () => token.cancel('Stopped by user'),
  );
  token.onProgress = loader.update;
  try {
    final result = await Future.any<T>([
      Future<T>.sync(() => extract(token)),
      token.whenCancel.then<T>((_) => throw CaptureCancelled()),
    ]);
    if (token.isCancelled) throw CaptureCancelled();
    if (context.mounted && itemCount != null) {
      await loader.succeed(itemCount(result));
    }
    if (token.isCancelled) throw CaptureCancelled();
    return result;
  } catch (error) {
    if (token.isCancelled) throw CaptureCancelled();
    rethrow;
  } finally {
    token.onProgress = null;
    loader.dismiss();
  }
}
