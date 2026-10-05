import 'package:flutter/material.dart';

import 'onboarding_page.dart';

/// Compatibility entry point. All tours use the same account-free introduction.
class OnboardingFlow extends StatelessWidget {
  const OnboardingFlow({super.key, this.onFinished});

  final VoidCallback? onFinished;

  @override
  Widget build(BuildContext context) => OnboardingPage(onFinished: onFinished);
}
