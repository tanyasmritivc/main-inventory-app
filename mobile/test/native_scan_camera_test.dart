import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/scan/native_scan_camera.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late Completer<Uint8List?> result;
  late List<MethodCall> calls;
  setUp(() {
    result = Completer<Uint8List?>();
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
      result = Completer<Uint8List?>()..complete(null);
      expect(await camera.pick(dark: false), isNull);
    },
  );
  test('native error releases the presentation so retry can succeed', () async {
    final camera = NativeScanCamera();
    final failed = camera.pick(dark: true);
    result.completeError(PlatformException(code: 'photo'));
    await expectLater(failed, throwsA(isA<PlatformException>()));
    result = Completer<Uint8List?>()..complete(null);
    expect(await camera.pick(dark: true), isNull);
  });
}
