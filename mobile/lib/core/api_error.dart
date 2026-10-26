import 'package:dio/dio.dart';
import 'api_client.dart' show AskRequestException, SessionExpiredException;

enum ErrorKind {
  sessionExpired,
  planLimit,
  permissionDenied,
  notFound,
  offline,
  server,
  generic,
}

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
  if (e is AskRequestException) {
    return (_safeMessage(e.message) ?? _genericMessage, ErrorKind.generic);
  }
  if (e is SessionExpiredException) {
    return ('Session expired. Please sign in again.', ErrorKind.sessionExpired);
  }
  if (e is FormatException) {
    return (_safeMessage(e.message) ?? _genericMessage, ErrorKind.generic);
  }
  if (e is DioException) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    if (status == 401) {
      return (
        'Session expired. Please sign in again.',
        ErrorKind.sessionExpired,
      );
    }
    // Server failures are not validation messages, even when detail is a string.
    if (status != null && status >= 500) {
      return (
        'FindEZ could not complete this request. Please try again.',
        ErrorKind.server,
      );
    }
    if (e.error is AskRequestException || e.error is SessionExpiredException) {
      return describeError(e.error!);
    }

    if (data is Map) {
      final detail = data['detail'];
      if (detail is Map) {
        final code = detail['error'] is String
            ? detail['error'] as String
            : null;
        final used = _count(detail['used']);
        final max = _count(detail['max']);
        final resetValue = detail['resets_at'];
        final resetsAt =
            resetValue is String && DateTime.tryParse(resetValue) != null
            ? resetValue
            : null;
        if (max != null && used != null ||
            ![
              'FREE_TIER_SHARE_LIMIT',
              'FREE_TIER_SPACE_LIMIT',
              'FREE_TIER_BARCODE_LIMIT',
              'FREE_TIER_IMPORT_LIMIT',
            ].contains(code)) {
          switch (code) {
            case 'FREE_TIER_SHARE_LIMIT':
              return (
                'Free accounts can have $max active '
                    '${max == 1 ? 'share' : 'shares'} '
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
        final safeDetail = _safeMessage(detail);
        if (safeDetail != null) {
          return (
            safeDetail,
            e.response?.statusCode == 403
                ? ErrorKind.permissionDenied
                : ErrorKind.generic,
          );
        }
      }
    }

    if (status == 403) {
      return (
        'You do not have permission to access this resource.',
        ErrorKind.permissionDenied,
      );
    }
    if (status == 404) {
      return ('This item no longer exists.', ErrorKind.notFound);
    }
    if (status == 429) {
      return ('Too many requests. Please wait a moment.', ErrorKind.generic);
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
}) {
  final message = describeError(e).$1;
  return message == _genericMessage ? fallback : message;
}

const _genericMessage = 'Something went wrong. Please try again.';

int? _count(Object? value) {
  if (value is int && value >= 0) return value;
  return null;
}

// Preserve concise validation copy, never transport/parser/SQL dumps. Endpoint
// errors still need server-side scrubbing; this is a final presentation boundary.
String? _safeMessage(String value) {
  final message = value.trim();
  if (message.isEmpty ||
      message.length > 320 ||
      RegExp(r'[<>\r\n{}\[\]]').hasMatch(message) ||
      RegExp(
        r'(exception|traceback|stacktrace|unexpected character|unexpected end|invalid radix|invalid number|offset \d|postgres|sqlstate|pgrst|relation .*does not exist|select .*from |certificate_verify|handshake|https?://|bearer |api[_ -]?key|private[_ -]?key|access[_ -]?token)',
        caseSensitive: false,
      ).hasMatch(message) ||
      RegExp(r'^[A-Z_0-9]+$').hasMatch(message)) {
    return null;
  }
  return message;
}
