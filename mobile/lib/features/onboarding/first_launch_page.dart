import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

class FirstLaunchPage extends StatelessWidget {
  const FirstLaunchPage({super.key, required this.onContinue});

  final Future<void> Function({required bool createAccount}) onContinue;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 36, 28, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'FindEZ',
                style: TextStyle(
                  color: t.accent,
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                'Know what you have.\nFind it when you need it.',
                style: TextStyle(
                  color: t.ink,
                  fontSize: 34,
                  fontWeight: FontWeight.w600,
                  height: 1.14,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Photograph your things, review what was found, and keep them organized by place.',
                style: TextStyle(color: t.text2, fontSize: 16, height: 1.4),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => onContinue(createAccount: true),
                child: const Text('Create account'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => onContinue(createAccount: false),
                child: const Text('Sign in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
