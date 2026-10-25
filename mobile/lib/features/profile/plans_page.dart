import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_theme.dart';
import '../../core/ui/app_text.dart';
import '../../core/ui/glass_control.dart';

const plansNotice =
    'Paid plans are coming soon. Current access is unchanged. No payment will be taken.';

class FindEZPlan {
  const FindEZPlan(
    this.name,
    this.description,
    this.monthly,
    this.annual,
    this.features,
  );
  final String name, description;
  final num monthly, annual;
  final List<String> features;
}

const findEZPlans = [
  FindEZPlan('Free', 'Try FindEZ on your own things.', 0, 0, [
    '100 saved item records',
    '1 person',
    'Unlimited Spaces',
    '10 photo extractions per month',
    '50 AI messages per month',
    'Chat, capture and find',
  ]),
  FindEZPlan('Plus', 'For your home, collections and workshop.', 9.99, 99, [
    '2,500 saved item records',
    '1 person',
    'Unlimited Spaces',
    '50 photo extractions per month',
    '500 AI messages per month',
    'Low-stock reminders',
  ]),
  FindEZPlan('Team', 'Remember more, together.', 29, 299, [
    '10,000 shared item records',
    '5 people included',
    'Unlimited Spaces',
    '200 photo extractions per month, shared',
    '2,000 AI messages per month, shared',
    'Shared inventory, permissions and activity',
  ]),
];

const planPolicies = [
  (
    'Items, not units',
    'M3 screws with a quantity of 500 count as one saved item record.',
  ),
  (
    'Clear AI allowances',
    'One photo extraction means one photo processed for inventory, regardless of how many items it finds. Failed extractions and automatic retries will not use your allowance.',
  ),
  (
    'Everyday access stays simple',
    'Browsing, manual edits, barcode scanning and exports will not use your AI allowance.',
  ),
  (
    'Your inventory stays yours',
    'After a downgrade or a usage limit, you will still be able to view, edit and export saved items.',
  ),
];

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
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [false, true]
                .map(
                  (annual) => Semantics(
                    selected: _annual == annual,
                    child: GlassControl(
                      selected: _annual == annual,
                      radius: 99,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(100, 44),
                          backgroundColor: Colors.transparent,
                        ),
                        onPressed: () => setState(() => _annual = annual),
                        child: AppText(annual ? 'Yearly' : 'Monthly'),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
          ...findEZPlans.map((plan) {
            final price = _annual ? plan.annual : plan.monthly;
            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surface(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.border(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    plan.name,
                    style: TextStyle(color: primary, fontSize: 20),
                  ),
                  const SizedBox(height: 6),
                  AppText(
                    plan.description,
                    style: TextStyle(
                      color: secondary,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppText(
                    '\$$price${price == 0
                        ? ''
                        : _annual
                        ? '/year'
                        : '/month'}',
                    style: TextStyle(color: primary, fontSize: 28),
                  ),
                  if (_annual && price > 0) ...[
                    const SizedBox(height: 6),
                    AppText(
                      'About \$${(price / 12).toStringAsFixed(2)}/month, billed yearly',
                      style: TextStyle(color: secondary, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 16),
                  ...plan.features.map(
                    (feature) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppText(
                        feature,
                        style: TextStyle(
                          color: secondary,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                  if (plan.monthly > 0) ...[
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: null,
                        child: const AppText('Coming soon'),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
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
