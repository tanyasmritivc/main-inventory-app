import '../../core/app_theme.dart';
import 'package:flutter/material.dart';
import 'findez_wordmark.dart';
import 'package:mobile/core/ui/app_text.dart';

class LaunchLoadingScreen extends StatelessWidget {
  const LaunchLoadingScreen({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final text = message ?? 'Preparing your workspace…';

    return Scaffold(
      backgroundColor: AppTheme.adaptive(context, Colors.black),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FindEZWordmark(),
            const SizedBox(height: 8),
            AppText(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.foreground(
                  context,
                  Colors.white.withValues(alpha: 0.45),
                ),
                fontSize: 14,
                fontWeight: FontWeight.normal,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppTheme.adaptive(
                    context,
                    Colors.white.withValues(alpha: 0.25),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
