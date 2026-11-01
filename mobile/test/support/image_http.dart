import 'dart:async';
import 'dart:io';
import 'package:image/image.dart' as image;

/// Deterministic decoded thumbnails without contacting an image service.
class ImageTestClient implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _Request();
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Headers implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Request implements HttpClientRequest {
  @override
  final headers = _Headers();
  @override
  Future<HttpClientResponse> close() async => _Response();
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  final bytes = image.encodePng(
    image.Image(width: 2, height: 2, numChannels: 3),
  );
  @override
  int get statusCode => 200;
  @override
  int get contentLength => bytes.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.value(bytes).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
