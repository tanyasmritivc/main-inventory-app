import 'package:dio/dio.dart';

enum ErrorKind { sessionExpired, planLimit, notFound, offline, server, generic }

/// Maps API error responses to a user-friendly message and a kind tag.
///
/// Rules:
///  • 401 → sessionExpired
///  • 403 with a known FREE_TIER_* or cap code → planLimit + structured message
///  • 404 → notFound
///  • timeout / connectionError / SocketException → offline
///  • 5xx → server
///  • anything else → generic
///
/// Never returns a raw exception dump or internal stack trace.
(String, ErrorKind) describeError(Object e) {
  if (e is DioException) {
    final status = e.response?.statusCode;
    final data = e.response?.data;

    if (data is Map) {
      final detail = data['detail'];
      if (detail is Map) {
        final code = detail['error'] as String?;
        final used = detail['used'];
        final max = detail['max'];
        final resetsAt = detail['resets_at'] as String?;
        switch (code) {
          case 'FREE_TIER_SHARE_LIMIT':
            return (
              'Free accounts can have $max active '
              '${(max as int?) == 1 ? 'share' : 'shares'} '
              '(you have $used of $max). '
              'Revoke an old share or join a team.',
              ErrorKind.planLimit,
            );
          case 'FREE_TIER_SPACE_LIMIT':
            return (
              'Free accounts can have $max spaces (you have $used of $max).',
              ErrorKind.planLimit,
            );
          case 'FREE_TIER_BARCODE_LIMIT':
            return (
              "You've used all $max free barcode scans this month.",
              ErrorKind.planLimit,
            );
          case 'FREE_TIER_IMPORT_LIMIT':
            return (
              "You've used all $max free spreadsheet imports this month.",
              ErrorKind.planLimit,
            );
          case 'TEAM_SOFT_CAP':
            return (
              "Your team plan has reached its item limit. Contact your team admin.",
              ErrorKind.planLimit,
            );
          case 'CHAT_LIMIT_REACHED':
            return (
              "You've used all ${max ?? 'your'} free AI chats this month"
              "${resetsAt != null ? ' — resets $resetsAt' : ''}.",
              ErrorKind.planLimit,
            );
          case 'SCAN_LIMIT_REACHED':
            return (
              "You've used all ${max ?? 'your'} free photo scans this month"
              "${resetsAt != null ? ' — resets $resetsAt' : ''}.",
              ErrorKind.planLimit,
            );
        }
        // Unrecognised structured code — fall through to HTTP status handlers.
      }

      if (detail is String && detail.isNotEmpty) {
        // Legacy bare-string detail codes.
        switch (detail) {
          case 'FREE_TIER_SPACE_LIMIT':
            return (
              'Free accounts can have 3 spaces. Delete a space or join a team.',
              ErrorKind.planLimit,
            );
          case 'FREE_TIER_SHARE_LIMIT':
            return (
              'Free accounts can have 1 active share. Revoke an old share or join a team.',
              ErrorKind.planLimit,
            );
        }
        // Return the string only if it looks like a human message, not a dump.
        if (!detail.startsWith('{') &&
            !detail.startsWith('Exception') &&
            !detail.startsWith('Error:') &&
            !detail.contains('DioException')) {
          return (detail, ErrorKind.generic);
        }
      }
    }

    if (status == 401) {
      return ('Session expired — sign in again.', ErrorKind.sessionExpired);
    }
    if (status == 403) {
      return ("You've reached the free limit.", ErrorKind.planLimit);
    }
    if (status == 404) {
      return ('This item no longer exists.', ErrorKind.notFound);
    }
    if (status == 429) {
      return ('Too many requests. Please wait a moment.', ErrorKind.generic);
    }
    if (status != null && status >= 500) {
      return ('Server error ($status). Please try again.', ErrorKind.server);
    }

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return (
        "Can't reach the server — check your connection.",
        ErrorKind.offline,
      );
    }
    if (e.type == DioExceptionType.connectionError) {
      return (
        "Can't reach the server — check your connection.",
        ErrorKind.offline,
      );
    }

    final msg = e.message;
    if (msg != null &&
        msg.isNotEmpty &&
        !msg.startsWith('DioException') &&
        !msg.contains('StackTrace')) {
      return (msg, ErrorKind.generic);
    }
    return ('Something went wrong. Please try again.', ErrorKind.generic);
  }

  // Non-Dio exception — check for network-level errors by message content.
  final str = e.toString();
  if (str.contains('SocketException') ||
      str.contains('Connection refused') ||
      str.contains('Network is unreachable') ||
      str.contains('Failed host lookup')) {
    return (
      "Can't reach the server — check your connection.",
      ErrorKind.offline,
    );
  }
  return ('Something went wrong. Please try again.', ErrorKind.generic);
}

/// Convenience wrapper that returns only the message string.
/// Prefer [describeError] for new code.
String friendlyApiError(
  Object e, {
  String fallback = 'Something went wrong. Please try again.',
}) =>
    describeError(e).$1;
