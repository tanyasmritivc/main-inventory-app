import 'package:dio/dio.dart';

/// Maps API error responses to user-friendly strings.
///
/// Handles the structured detail codes the backend returns for plan limits
/// (e.g. FREE_TIER_SHARE_LIMIT with used/max counts) and falls back to
/// safe generic messages for network errors and unexpected exceptions.
///
/// Never returns a raw exception dump or internal stack trace.
String friendlyApiError(
  Object e, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  if (e is DioException) {
    final status = e.response?.statusCode;
    final data = e.response?.data;

    if (data is Map) {
      final detail = data['detail'];
      if (detail is Map) {
        // Structured error code (new backend convention: {error, used, max}).
        final code = detail['error'] as String?;
        final used = detail['used'];
        final max = detail['max'];
        switch (code) {
          case 'FREE_TIER_SHARE_LIMIT':
            return 'Free accounts can have $max active '
                '${(max as int?) == 1 ? 'share' : 'shares'} '
                '(you have $used of $max). '
                'Revoke an old share or join a team.';
          case 'FREE_TIER_SPACE_LIMIT':
            return 'Free accounts can have $max spaces (you have $used of $max).';
          case 'FREE_TIER_BARCODE_LIMIT':
            return 'You\'ve used all $max free barcode scans this month.';
          case 'FREE_TIER_IMPORT_LIMIT':
            return 'You\'ve used all $max free spreadsheet imports this month.';
        }
        // Unknown code but has a human-readable message field.
        final msg = detail['message'] as String?;
        if (msg != null && msg.isNotEmpty) return msg;
        return fallback;
      }

      if (detail is String && detail.isNotEmpty) {
        // Legacy bare-string detail codes (old backend format).
        switch (detail) {
          case 'FREE_TIER_SPACE_LIMIT':
            return 'Free accounts can have 3 spaces. Upgrade or delete a space.';
          case 'FREE_TIER_SHARE_LIMIT':
            return 'Free accounts can have 1 active share. Revoke an old share or join a team.';
        }
        // Return the string only if it looks like a human message, not a raw
        // internal key or a JSON dump.
        if (!detail.startsWith('{') &&
            !detail.startsWith('Exception') &&
            !detail.startsWith('Error:') &&
            !detail.contains('DioException')) {
          return detail;
        }
        return fallback;
      }
    }

    // Generic HTTP status fallbacks.
    if (status == 401) return 'Session expired. Please sign in again.';
    if (status == 403) return 'You\'ve reached the free limit.';
    if (status == 429) return 'Too many requests. Please wait a moment.';
    if (status != null && status >= 500) return 'Server error. Please try again.';

    // Network-level errors.
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Connection timed out. Check your internet.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'Connection error. Check your internet.';
    }

    // DioException.message can be useful (e.g. "Http status error [404]")
    // but avoid showing the full DioException.toString() dump.
    final msg = e.message;
    if (msg != null &&
        msg.isNotEmpty &&
        !msg.startsWith('DioException') &&
        !msg.contains('StackTrace')) {
      return msg;
    }
    return fallback;
  }

  // Non-Dio exception — never show the raw type name or stack trace.
  return fallback;
}
