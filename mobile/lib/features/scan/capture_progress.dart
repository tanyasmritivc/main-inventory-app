import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/ui/app_text.dart';
import '../../core/api_error.dart';
import '../chat/extraction_progress_panel.dart';
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
  ImageProvider? photo,
}) async {
  while (true) {
    try {
      return await _runCapture(
        context: context,
        extract: extract,
        itemCount: itemCount,
        photo: photo,
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
  ImageProvider? photo,
}) async {
  final token = CaptureProgressToken();
  final progress = ValueNotifier<String>('Preparing your photo...');
  final navigator = Navigator.of(context, rootNavigator: true);
  final route = ModalBottomSheetRoute<void>(
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheet) => PopScope(
      canPop: false,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Material(
          color: Theme.of(sheet).colorScheme.surface,
          borderRadius: BorderRadius.circular(28),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    trailing: IconButton(
                      tooltip: 'Stop extraction',
                      onPressed: () => token.cancel('Stopped by user'),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                  if (photo != null)
                    ScanPhotoFrame(
                      image: photo,
                      height: MediaQuery.sizeOf(sheet).height * .32,
                      scanning: true,
                    ),
                  ValueListenableBuilder<String>(
                    valueListenable: progress,
                    builder: (_, message, _) => ExtractionProgressPanel(
                      message: message,
                      regions: const [],
                    ),
                  ),
                  TextButton(
                    onPressed: () => token.cancel('Stopped by user'),
                    child: const Text('Stop extraction'),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  unawaited(navigator.push(route));
  token.onProgress = (message) => progress.value = message;
  try {
    final result = await Future.any<T>([
      Future<T>.sync(() => extract(token)),
      token.whenCancel.then<T>((_) => throw CaptureCancelled()),
    ]);
    if (token.isCancelled) throw CaptureCancelled();
    if (token.isCancelled) throw CaptureCancelled();
    return result;
  } catch (error) {
    if (token.isCancelled) throw CaptureCancelled();
    rethrow;
  } finally {
    token.onProgress = null;
    if (route.isActive) navigator.removeRoute(route);
    WidgetsBinding.instance.addPostFrameCallback((_) => progress.dispose());
  }
}
