import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:mobile/features/onboarding/onboarding_prefs.dart';

class RejectTourWrites extends InMemorySharedPreferencesStore {
  RejectTourWrites()
    : super.withData({'flutter.guided_tour_install_state': 'pending'});
  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'a fresh installation gets exactly one durable claim across restarts',
    () async {
      await OnboardingPrefs.prepareGuidedTourInstall(hasSession: false);
      expect(await OnboardingPrefs.claimGuidedTour(), isTrue);
      await OnboardingPrefs.prepareGuidedTourInstall(hasSession: true);
      expect(await OnboardingPrefs.claimGuidedTour(), isFalse);
      await OnboardingPrefs.setCompleted(false);
      await OnboardingPrefs.prepareGuidedTourInstall(hasSession: false);
      expect(await OnboardingPrefs.claimGuidedTour(), isFalse);
    },
  );

  test(
    'first login after fresh setup stays eligible and competing starts serialize',
    () async {
      await OnboardingPrefs.prepareGuidedTourInstall(hasSession: false);
      await OnboardingPrefs.setCompleted(true);
      await OnboardingPrefs.prepareGuidedTourInstall(hasSession: true);
      expect(
        await Future.wait(
          List.generate(5, (_) => OnboardingPrefs.claimGuidedTour()),
        ),
        [true, false, false, false, false],
      );
    },
  );

  for (final legacy in [
    {'onboarding_completed': true},
    {'onboarding_post_signup_pending': true},
    {'coachmark_pending_old-account': true},
    {'tutorial_done_old-account': false},
    {'space_discovery_done_old-account': false},
  ]) {
    test('legacy flags never re-arm a tour: ${legacy.keys.first}', () async {
      SharedPreferences.setMockInitialValues(legacy);
      await OnboardingPrefs.prepareGuidedTourInstall(hasSession: false);
      expect(await OnboardingPrefs.claimGuidedTour(), isFalse);
    });
  }

  test(
    'an existing authenticated installation is quiet without legacy flags',
    () async {
      await OnboardingPrefs.prepareGuidedTourInstall(hasSession: true);
      expect(await OnboardingPrefs.claimGuidedTour(), isFalse);
    },
  );

  test(
    'uninitialized state and failed writes never authorize display',
    () async {
      expect(await OnboardingPrefs.claimGuidedTour(), isFalse);
      SharedPreferencesStorePlatform.instance = RejectTourWrites();
      expect(await OnboardingPrefs.claimGuidedTour(), isFalse);
      // Reload must not mistake a rejected cached consumed value for disk state.
      expect(await OnboardingPrefs.claimGuidedTour(), isFalse);
      SharedPreferences.setMockInitialValues({});
      await OnboardingPrefs.prepareGuidedTourInstall(hasSession: false);
      expect(await OnboardingPrefs.claimGuidedTour(), isTrue);
    },
  );
}
