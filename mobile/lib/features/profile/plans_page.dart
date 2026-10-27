import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_theme.dart';
import '../../core/ui/app_text.dart';
import 'plan_widgets.dart';

import '../../core/plan_catalog.dart';
export '../../core/plan_catalog.dart';

/// Planned prices do not activate purchases or change account entitlements.
class PlansPage extends StatefulWidget {
  const PlansPage({super.key});

  @override
  State<PlansPage> createState() => _PlansPageState();
}

class _PlansPageState extends State<PlansPage> {
  bool _annual = false;

  Future<void> _contactSupport() async {
    try {
      if (await launchUrl(
        Uri(
          scheme: 'mailto',
          path: 'info@findez.ai',
          queryParameters: {'subject': 'FindEZ plans'},
        ),
      )) {
        return;
      }
    } catch (_) {
      // The address remains available if this device has no mail application.
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: AppText('Email info@findez.ai for plan questions.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = AppTheme.textPrimary(context);
    final secondary = AppTheme.textSecondary(context);
    return Scaffold(
      backgroundColor: AppTheme.surface2(context),
      appBar: AppBar(title: const AppText('Plans')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          AppText(
            'Remember more of your world.',
            style: TextStyle(color: primary, fontSize: 26, height: 1.2),
          ),
          const SizedBox(height: 12),
          AppText(
            plansNotice,
            style: TextStyle(color: secondary, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 20),
          PlanPeriodSelector(
            annual: _annual,
            onChanged: (value) => setState(() => _annual = value),
          ),
          const SizedBox(height: 20),
          ...findEZPlans.map(
            (plan) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: PlanCard(plan: plan, annual: _annual),
            ),
          ),
          const SizedBox(height: 14),
          AppText(
            'How the planned limits work',
            style: TextStyle(color: primary, fontSize: 20),
          ),
          const SizedBox(height: 16),
          ...planPolicies.map(
            (policy) => Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    policy.$1,
                    style: TextStyle(color: primary, fontSize: 15),
                  ),
                  const SizedBox(height: 5),
                  AppText(
                    policy.$2,
                    style: TextStyle(
                      color: secondary,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AppText(
            'Need a larger team? Contact us.',
            style: TextStyle(color: secondary, fontSize: 14, height: 1.5),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _contactSupport,
              child: const AppText('Contact info@findez.ai'),
            ),
          ),
          const SizedBox(height: 16),
          AppText(
            'Planned pricing in USD. All plan allowances start when subscriptions launch. AI allowances may be adjusted before launch based on measured usage. In-app subscription prices and terms will appear before purchase.',
            style: TextStyle(color: secondary, fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }
}
