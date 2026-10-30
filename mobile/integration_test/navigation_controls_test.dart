import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/ui/navigation_motion.dart';
import 'fluid_shell_visual_test.dart' as shell;
import '../test/retained_tab_transition_test.dart' as motion;
import '../test/space_capture_entry_test.dart' as controls;

void main() {
  shell.main();
  testWidgets('UIKit motion preferences are available on the native host', (
    tester,
  ) async {
    final preferences = await NativeMotionPreferences.channel
        .invokeMapMethod<String, dynamic>('preferences');
    expect(preferences?['reduceMotion'], isA<bool>());
    expect(preferences?['preferCrossFade'], isA<bool>());
  });
  group('Motion', motion.main);
  group('Controls', controls.main);
}
