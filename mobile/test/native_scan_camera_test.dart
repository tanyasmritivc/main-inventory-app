import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/scan/native_scan_camera.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late Completer<Object?> result;
  late List<MethodCall> calls;
  setUp(() {
    result = Completer<Object?>();
    calls = [];
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      NativeScanCamera.channel,
      (call) async {
        calls.add(call);
        return call.method == 'present' ? result.future : null;
      },
    );
  });
  tearDown(
    () => binding.defaultBinaryMessenger.setMockMethodCallHandler(
      NativeScanCamera.channel,
      null,
    ),
  );
  test('camera opens directly once and returns the selected photo', () async {
    final camera = NativeScanCamera();
    final selected = camera.pick(dark: true);
    expect(await camera.pick(dark: true), isNull);
    final bytes = Uint8List.fromList([1, 2, 3]);
    result.complete(bytes);
    expect(await selected, bytes);
    expect(calls.map((c) => c.method), ['present']);
  });
  test(
    'cancel dismisses its own presentation and ignores late photo bytes',
    () async {
      final camera = NativeScanCamera();
      final selected = camera.pick(dark: false);
      camera.cancel();
      result.complete(Uint8List.fromList([1]));
      expect(await selected, isNull);
      expect(calls.map((c) => c.method), ['present', 'dismiss']);
      expect(calls.last.arguments['token'], calls.first.arguments['token']);
      result = Completer<Object?>()..complete(null);
      expect(await camera.pick(dark: false), isNull);
    },
  );
  test(
    'combined camera returns barcode without photo and drops late cancel results',
    () async {
      final camera = NativeScanCamera();
      final capture = camera.capture(dark: true);
      result.complete({'barcode': '012345678905'});
      expect((await capture)?.barcode, '012345678905');
      expect(calls.first.arguments['barcodes'], true);
      result = Completer<Object?>();
      final late = camera.capture(dark: false);
      camera.cancel();
      result.complete({'barcode': '012345678905'});
      expect(await late, isNull);
    },
  );
  test('combined camera returns photo bytes', () async {
    final capture = NativeScanCamera().capture(dark: false);
    final bytes = Uint8List.fromList([1, 2]);
    result.complete({'photo': bytes});
    expect((await capture)?.photo, bytes);
  });
  test('native error releases the presentation so retry can succeed', () async {
    final camera = NativeScanCamera();
    final failed = camera.pick(dark: true);
    result.completeError(PlatformException(code: 'photo'));
    await expectLater(failed, throwsA(isA<PlatformException>()));
    result = Completer<Object?>()..complete(null);
    expect(await camera.pick(dark: true), isNull);
  });
}
