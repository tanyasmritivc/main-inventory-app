import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/ui/app_text.dart';
import '../../core/ui/glass_control.dart';

class FindEZPlan {
  const FindEZPlan(this.name, this.monthly, this.annual, this.features);
  final String name;
  final int? monthly, annual;
  final List<String> features;
}

const findEZPlans = [
  FindEZPlan('Free', 0, 0, [
    '30 items and 3 Spaces',
    '20 AI chats per month',
    '5 photo scans and 10 barcode scans per month',
    '2 imports per month and 1 active share',
  ]),
  FindEZPlan('Pro', 19, 149, [
    '2,500 items and 20 Spaces',
    'Unlimited AI chats and scans, subject to fair use',
    'Personal inventory and physical memory',
    'Advanced search and document workflows',
  ]),
  FindEZPlan('Team', 99, 790, [
    'Up to 10 users and 10,000 items',
    'Shared inventories and collaboration',
    'Team permissions and shared physical memory',
  ]),
  FindEZPlan('Business', 299, 2490, [
    'Up to 25 users and 50,000 items',
    'Advanced shared inventory workflows',
    'Business onboarding and support',
  ]),
  FindEZPlan('Enterprise', null, null, [
    'Custom users, inventory capacity and usage',
    'Organization-specific requirements',
    'Tailored onboarding and support',
    'Custom commercial agreements',
  ]),
];

/// Planned prices do not activate purchases or change account entitlements.
class PlansPage extends StatefulWidget {
  const PlansPage({super.key});

  @override
  State<PlansPage> createState() => _PlansPageState();
}

class _PlansPageState extends State<PlansPage> {
  bool _annual = false;

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
            'More room for what matters.',
            style: TextStyle(color: primary, fontSize: 26, height: 1.2),
          ),
          const SizedBox(height: 12),
          AppText(
            'Paid plans are coming soon. Current access is unchanged. No payment will be taken.',
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
                  const SizedBox(height: 12),
                  AppText(
                    price == null
                        ? 'Custom'
                        : '\$$price${price == 0
                              ? ''
                              : _annual
                              ? '/year'
                              : '/month'}',
                    style: TextStyle(color: primary, fontSize: 28),
                  ),
                  if (_annual && price != null && price > 0) ...[
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
                ],
              ),
            );
          }),
          AppText(
            'Planned pricing in USD. Paid plan limits apply when subscriptions launch. In-app subscription prices and terms will appear before purchase.',
            style: TextStyle(color: secondary, fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }
}
