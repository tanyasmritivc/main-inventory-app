import 'package:flutter/material.dart';
import '../../core/ui/findez_wordmark.dart';
import '../onboarding/onboarding_prefs.dart';

/// First launch introduces the two jobs; setup happens conversationally after auth.
class WorldWelcome extends StatefulWidget {
  const WorldWelcome({super.key, required this.onFinished});
  final VoidCallback onFinished;
  @override
  State<WorldWelcome> createState() => _WorldWelcomeState();
}

class _WorldWelcomeState extends State<WorldWelcome> {
  bool _busy = false;
  String? _error;
  Future<void> _continue() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await OnboardingPrefs.setCompleted(true);
      if (mounted) widget.onFinished();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not continue. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, bounds) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: bounds.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: FindEZWordmark()),
                      const SizedBox(height: 48),
                      const Text(
                        'Your world, remembered.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'CupertinoSystemText',
                          fontSize: 34,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Capture what you have. Ask where it is.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, height: 1.5),
                      ),
                      const SizedBox(height: 48),
                      FilledButton(
                        onPressed: _busy ? null : _continue,
                        child: Text(_busy ? 'Opening…' : 'Get started'),
                      ),
                      TextButton(
                        onPressed: _busy ? null : _continue,
                        child: const Text('I already have an account'),
                      ),
                      if (_error != null)
                        Text(_error!, textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
