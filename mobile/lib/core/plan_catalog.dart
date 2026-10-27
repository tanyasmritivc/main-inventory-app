const plansNotice =
    'Free pre-launch access. Plan quotas are not enforced during this period. '
    'There is no automatic cutoff date. Paid plans are coming soon. '
    'You will not be charged automatically.';

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
    '10 people included',
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
