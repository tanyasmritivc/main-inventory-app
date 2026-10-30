import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/ui/navigation_motion.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('UIKit preferences load once and refresh on resume', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    var calls = 0;
    var crossFade = false;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(NativeMotionPreferences.channel, (
      _,
    ) async {
      calls++;
      return {'reduceMotion': true, 'preferCrossFade': crossFade};
    });
    final preferences = NativeMotionPreferences();
    addTearDown(() {
      preferences.dispose();
      messenger.setMockMethodCallHandler(NativeMotionPreferences.channel, null);
    });
    await preferences.initialize();
    await preferences.initialize();
    expect(calls, 1);
    expect(preferences.value.reduceMotion, true);
    expect(preferences.value.preferCrossFade, false);
    crossFade = true;
    await preferences.refresh();
    expect(preferences.value.preferCrossFade, true);
    final data = const StandardMethodCodec().encodeMethodCall(
      const MethodCall('changed', {
        'reduceMotion': false,
        'preferCrossFade': false,
      }),
    );
    await messenger.handlePlatformMessage(
      'com.findez.app/motion',
      data,
      (_) {},
    );
    expect(preferences.value.reduceMotion, false);
    expect(preferences.value.preferCrossFade, false);
    preferences.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);
    expect(preferences.value.preferCrossFade, true);
  });
}
