// Display catalog only. Purchases and server entitlements are not activated here.
export const PLANS_NOTICE = "Free pre-launch access. Plan quotas are not enforced during this period. There is no automatic cutoff date. Paid plans are coming soon. You will not be charged automatically.";
export const BILLING_PLANS = [
  { id: "free", name: "Free", description: "Try FindEZ on your own things.", monthly: 0, annual: 0, features: ["100 saved item records", "1 person", "Unlimited Spaces", "10 photo extractions per month", "50 AI messages per month", "Chat, capture and find"] },
  { id: "plus", name: "Plus", description: "For your home, collections and workshop.", monthly: 9.99, annual: 99, features: ["2,500 saved item records", "1 person", "Unlimited Spaces", "50 photo extractions per month", "500 AI messages per month", "Low-stock reminders"] },
  { id: "team", name: "Team", description: "Remember more, together.", monthly: 29, annual: 299, features: ["10,000 shared item records", "5 people included", "Unlimited Spaces", "200 photo extractions per month, shared", "2,000 AI messages per month, shared", "Shared inventory, permissions and activity"] },
] as const;

export const PLAN_POLICIES = [
  ["Items, not units", "M3 screws with a quantity of 500 count as one saved item record."],
  ["Clear AI allowances", "One photo extraction means one photo processed for inventory, regardless of how many items it finds. Failed extractions and automatic retries will not use your allowance."],
  ["Everyday access stays simple", "Browsing, manual edits, barcode scanning and exports will not use your AI allowance."],
  ["Your inventory stays yours", "After a downgrade or a usage limit, you will still be able to view, edit and export saved items."],
] as const;
