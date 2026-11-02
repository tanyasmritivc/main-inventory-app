export const BILLING_PLANS = [
  { id: "free", name: "Free", monthly: 0, annual: 0, features: ["30 items", "3 Spaces", "20 AI chats per month", "5 photo scans and 10 barcode scans per month", "2 imports per month", "1 active share"] },
  { id: "pro", name: "Pro", monthly: 19, annual: 149, features: ["2,500 items", "20 Spaces", "Unlimited AI chats and scans, subject to fair use", "Personal inventory and physical memory", "Advanced search and document workflows"] },
  { id: "team", name: "Team", monthly: 99, annual: 790, features: ["Up to 10 users", "10,000 items", "Shared inventories and collaboration", "Team permissions and shared physical memory"] },
  { id: "business", name: "Business", monthly: 299, annual: 2490, features: ["Up to 25 users", "50,000 items", "Advanced shared inventory workflows", "Business onboarding and support"] },
  { id: "enterprise", name: "Enterprise", monthly: null, annual: null, features: ["Custom users, inventory capacity and usage", "Organization-specific requirements", "Tailored onboarding and support", "Custom commercial agreements"] },
] as const;
