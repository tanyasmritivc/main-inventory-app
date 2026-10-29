import 'package:flutter/material.dart';
import '../../core/ui/app_text.dart';
import '../../core/plan_catalog.dart';

/// Static highlights keep the glass finish calm and respect reduced motion.
class BluePlanSurface extends StatelessWidget {
  const BluePlanSurface({super.key, required this.child});
  final Widget child;
  static const ink = Color(0xFF373737);
  static const muted = Color(0xFF5B5B5B);
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF8F8F8), Color(0xFFDBDBDB), Color(0xFFEBEBEB)],
        stops: [0, .48, 1],
      ),
      border: Border.all(color: const Color(0xFFF3F3F3)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x22BBBBBB),
          blurRadius: 16,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: DefaultTextStyle.merge(
      style: const TextStyle(color: ink),
      child: child,
    ),
  );
}

class PlanPeriodSelector extends StatelessWidget {
  const PlanPeriodSelector({
    super.key,
    required this.annual,
    required this.onChanged,
  });
  final bool annual;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [false, true]
        .map(
          (value) => ChoiceChip(
            label: AppText(value ? 'Yearly' : 'Monthly'),
            selected: annual == value,
            selectedColor: const Color(0xFFEBEBEB),
            labelStyle: TextStyle(
              color: annual == value ? BluePlanSurface.ink : null,
            ),
            checkmarkColor: BluePlanSurface.ink,
            onSelected: (_) => onChanged(value),
          ),
        )
        .toList(),
  );
}

class PlanCard extends StatelessWidget {
  const PlanCard({super.key, required this.plan, required this.annual});
  final FindEZPlan plan;
  final bool annual;
  @override
  Widget build(BuildContext context) {
    final price = annual ? plan.annual : plan.monthly;
    return BluePlanSurface(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              plan.name,
              style: const TextStyle(color: BluePlanSurface.ink, fontSize: 20),
            ),
            const SizedBox(height: 6),
            AppText(
              plan.description,
              style: const TextStyle(
                color: BluePlanSurface.muted,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            AppText(
              '\$$price${price == 0
                  ? ''
                  : annual
                  ? '/year'
                  : '/month'}',
              style: const TextStyle(color: BluePlanSurface.ink, fontSize: 28),
            ),
            if (annual && price > 0) ...[
              const SizedBox(height: 6),
              AppText(
                'About \$${(price / 12).toStringAsFixed(2)}/month, billed yearly',
                style: const TextStyle(
                  color: BluePlanSurface.muted,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 16),
            ...plan.features.map(
              (feature) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: BluePlanSurface.ink,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppText(
                        feature,
                        style: const TextStyle(
                          color: BluePlanSurface.ink,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (price > 0)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: null,
                  style: OutlinedButton.styleFrom(
                    disabledForegroundColor: BluePlanSurface.muted,
                    side: const BorderSide(color: Color(0x558D8D8D)),
                  ),
                  child: const AppText('Coming soon'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
