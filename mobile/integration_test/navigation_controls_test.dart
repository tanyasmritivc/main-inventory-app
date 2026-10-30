import 'package:flutter_test/flutter_test.dart';
import 'fluid_shell_visual_test.dart' as shell;
import '../test/retained_tab_transition_test.dart' as motion;
import '../test/space_capture_entry_test.dart' as controls;

void main() {
  shell.main();
  group('Motion', motion.main);
  group('Controls', controls.main);
}
