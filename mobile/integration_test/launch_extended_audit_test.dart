// Synthetic APIs and identities; actual Flutter widgets on iOS.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/core/ui/native_presentation.dart';
import '../test/mobile_audit_test.dart' as audit14;
import '../test/documents_page_test.dart' as audit0;
import '../test/onboarding_page_test.dart' as audit1;
import '../test/onboarding_launch_test.dart' as audit2;
import '../test/organization_place_flow_test.dart' as audit3;
import '../test/inventory_directory_actions_test.dart' as audit4;
import '../test/resource_permissions_ui_test.dart' as audit5;
import '../test/restock_planner_test.dart' as audit6;
import '../test/notifications_page_test.dart' as audit7;
import '../test/memory_page_test.dart' as audit8;
import '../test/scan_review_test.dart' as audit9;
import '../test/imported_item_details_test.dart' as audit10;
import '../test/profile_editor_test.dart' as audit11;
import '../test/invitation_test.dart' as audit12;
import '../test/session_restoration_test.dart' as audit13;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  group('documents_page', audit0.main);
  group('onboarding_page', audit1.main);
  group('onboarding_launch', audit2.main);
  group('organization_place_flow', audit3.main);
  group('inventory_directory_actions', audit4.main);
  // These suites assert Flutter sheet/dialog descendants. UIKit account and
  // confirmation controls need separate native accessibility inspection.
  group('resource_permissions_ui', () {
    setUp(() => debugNativePresentationOverride = false);
    tearDown(() => debugNativePresentationOverride = null);
    audit5.main();
  });
  group('restock_planner', audit6.main);
  group('notifications_page', audit7.main);
  group('memory_page', () {
    setUp(() => debugNativePresentationOverride = false);
    tearDown(() => debugNativePresentationOverride = null);
    audit8.main();
  });
  group('scan_review', audit9.main);
  group('imported_item_details', audit10.main);
  group('profile_editor', audit11.main);
  group('invitation', audit12.main);
  group('session_restoration', audit13.main);
  group('mobile_audit', audit14.main);
}
