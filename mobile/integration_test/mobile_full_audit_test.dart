// Synthetic fixtures only. No production accounts or inventory writes.
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/ui/native_presentation.dart';
import 'package:mobile/features/chat/native_scan_progress.dart';
import 'package:mobile/features/world/native_bottom_tabs.dart';
import 'launch_extended_audit_test.dart' as audit0;
import 'release_audit_test.dart' as audit1;
import 'store_screen_audit_test.dart' as audit2;
import 'world_audit_test.dart' as audit3;
import 'capture_audit_test.dart' as audit4;
import 'appearance_audit_test.dart' as audit5;
import 'chat_follow_through_test.dart' as audit6;
import 'chat_onboarding_test.dart' as audit7;
import 'chat_attachment_menu_test.dart' as audit8;
import 'context_chat_test.dart' as audit9;
import 'account_consistency_test.dart' as audit10;
import 'onboarding_recovery_test.dart' as audit11;
import 'onboarding_v5_test.dart' as audit12;
import 'photo_attachment_audit_test.dart' as audit13;
import 'scan_polish_test.dart' as audit14;
import 'scan_box_audit_test.dart' as audit15;
import 'scan_live_review_audit_test.dart' as audit16;
import 'sources_audit_test.dart' as audit17;
import 'space_flow187_audit_test.dart' as audit18;
import 'spaces_audit_test.dart' as audit19;
import 'voice_composer_audit_test.dart' as audit20;
import 'voice_input_audit_test.dart' as audit21;
import 'native_scan_progress_test.dart' as audit22;
import 'system_typography_test.dart' as audit23;
import 'fluid_shell_visual_test.dart' as audit24;
import 'fluid_surfaces_audit_test.dart' as audit25;
import 'space_chat_layout_test.dart' as audit26;
import 'response_feedback_test.dart' as audit27;
import 'extraction_progress_test.dart' as audit28;
import '../test/world_setup_error_test.dart' as audit29;

// Standalone suites may leave a singleton or control override behind. Reset
// them so each audit uses its own transport, identity, and native controls.
Future<void> resetAuditState() async {
  debugNativePresentationOverride = null;
  debugNativeBottomTabsOverride = null;
  debugNativeScanProgressOverride = null;
  Supabase? instance;
  try {
    instance = Supabase.instance;
  } on AssertionError {
    return; // No initialized client.
  }
  if (instance.isInitialized) await instance.dispose();
}

void audit(String name, void Function() register) {
  group(name, () {
    setUpAll(resetAuditState);
    tearDownAll(resetAuditState);
    register();
  });
}

void main() {
  audit('world_setup_error', audit29.main);
  audit('launch_extended_audit', audit0.main);
  audit('release_audit', audit1.main);
  audit('store_screen_audit', audit2.main);
  audit('world_audit', audit3.main);
  audit('capture_audit', audit4.main);
  audit('appearance_audit', audit5.main);
  audit('chat_follow_through', audit6.main);
  audit('chat_onboarding', audit7.main);
  audit('chat_attachment_menu', audit8.main);
  audit('context_chat', audit9.main);
  audit('account_consistency', audit10.main);
  audit('onboarding_recovery', audit11.main);
  audit('onboarding_v5', audit12.main);
  audit('photo_attachment_audit', audit13.main);
  audit('scan_polish', audit14.main);
  audit('scan_box_audit', audit15.main);
  audit('scan_live_review_audit', audit16.main);
  audit('sources_audit', audit17.main);
  audit('space_flow187_audit', audit18.main);
  audit('spaces_audit', audit19.main);
  audit('voice_composer_audit', audit20.main);
  audit('voice_input_audit', audit21.main);
  audit('native_scan_progress', audit22.main);
  audit('system_typography', audit23.main);
  audit('fluid_shell_visual', audit24.main);
  audit('fluid_surfaces_audit', audit25.main);
  audit('space_chat_layout', audit26.main);
  audit('response_feedback', audit27.main);
  audit('extraction_progress', audit28.main);
}
