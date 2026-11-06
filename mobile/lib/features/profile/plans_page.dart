import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        title: const AppText('Plans'),
        backgroundColor: AppTheme.bg(context),
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
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
          CupertinoSlidingSegmentedControl<bool>(
            groupValue: _annual,
            backgroundColor: AppTheme.surface2(context),
            thumbColor: AppTheme.surface(context),
            onValueChanged: (value) {
              if (value != null) setState(() => _annual = value);
            },
            children: {
              for (final annual in [false, true])
                annual: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: AppText(
                    annual ? 'Yearly' : 'Monthly',
                    style: TextStyle(color: primary, fontSize: 14),
                  ),
                ),
            },
          ),
          const SizedBox(height: 20),
          ...findEZPlans.map(
            (plan) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: PlanCard(plan: plan, annual: _annual, adaptive: true),
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
