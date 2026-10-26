import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api_error.dart';
import 'package:mobile/core/api_client.dart';

DioException responseError(int status, Object? body) => DioException(
  requestOptions: RequestOptions(path: '/items'),
  response: Response(
    requestOptions: RequestOptions(path: '/items'),
    statusCode: status,
    data: body,
  ),
  type: DioExceptionType.badResponse,
);

void main() {
  test('malformed limit details cannot crash the error display', () {
    for (final detail in [
      {'error': 42, 'max': []},
      {'error': 'FREE_TIER_SHARE_LIMIT', 'max': '3', 'used': {}},
      {'error': 'CHAT_LIMIT_REACHED', 'resets_at': []},
    ]) {
      expect(
        () => describeError(responseError(403, {'detail': detail})),
        returnsNormally,
      );
    }
  });
  test('server failures never expose internal detail or credentials', () {
    for (final detail in [
      'relation public.items does not exist',
      'Traceback: private_key=secret',
      '<html>upstream nginx failure</html>',
    ]) {
      final result = describeError(responseError(500, {'detail': detail}));
      expect(result.$2, ErrorKind.server);
      expect(result.$1, isNot(contains(detail)));
    }
  });
  test('parsing and transport internals are not user-facing messages', () {
    expect(
      describeError(
        const FormatException('Unexpected character at offset 0'),
      ).$1,
      isNot(contains('Unexpected character')),
    );
    final error = DioException(
      requestOptions: RequestOptions(path: '/items'),
      message: 'HandshakeException: CERTIFICATE_VERIFY_FAILED',
    );
    expect(describeError(error).$1, isNot(contains('HandshakeException')));
  });
  test('wrapped scope and session failures retain actionable meaning', () {
    final scope = DioException(
      requestOptions: RequestOptions(path: '/items'),
      error: const AskRequestException(
        'You have view-only access to this inventory.',
      ),
    );
    expect(
      describeError(scope).$1,
      'You have view-only access to this inventory.',
    );
  });
  test('safe validation copy and offline guidance remain available', () {
    expect(
      describeError(
        responseError(422, {'detail': 'Enter a quantity greater than zero.'}),
      ).$1,
      'Enter a quantity greater than zero.',
    );
    expect(
      describeError(
        DioException(
          requestOptions: RequestOptions(path: '/items'),
          type: DioExceptionType.connectionError,
        ),
      ).$2,
      ErrorKind.offline,
    );
  });
}
