export type UsageType = "homeowner" | "diy" | "mechanic" | "student" | "other";

export const USAGE_TYPE_OPTIONS: Array<{ value: UsageType; label: string; sub: string; icon: string }> = [
  {
    value: "homeowner",
    label: "Home & household",
    sub: "Groceries, home goods, and storage — never buy duplicates",
    icon: "🏠",
  },
  {
    value: "diy",
    label: "Workshop, garage & tools",
    sub: "Hand tools, power tools, parts, and project supplies",
    icon: "🔧",
  },
  {
    value: "mechanic",
    label: "Team or club gear",
    sub: "Shared inventory for clubs, competitions, and build seasons",
    icon: "👥",
  },
  {
    value: "student",
    label: "Collection or hobby",
    sub: "Anything you want catalogued, searchable, and findable",
    icon: "📦",
  },
  {
    value: "other",
    label: "Something else",
    sub: "We'll figure it out together",
    icon: "✨",
  },
];

export function asUsageType(v: unknown): UsageType | null {
  if (v === "homeowner" || v === "diy" || v === "mechanic" || v === "student" || v === "other") return v;
  return null;
}

export function personaDefaults(usageType: UsageType | null): { categories: string[]; locations: string[] } {
  if (!usageType) return { categories: [], locations: [] };

  if (usageType === "homeowner") {
    return {
      categories: ["Kitchen", "Pantry", "Cleaning", "Bathroom", "Tools", "Home"],
      locations: ["Garage", "Kitchen", "Closet", "Pantry", "Laundry", "Basement"],
    };
  }

  if (usageType === "diy") {
    return {
      categories: ["Tools", "Hardware", "Electrical", "Plumbing", "Paint", "Safety"],
      locations: ["Garage", "Workbench", "Toolbox", "Shed", "Storage Shelf", "Closet"],
    };
  }

  if (usageType === "mechanic") {
    return {
      categories: ["Parts", "Tools", "Electronics", "Fasteners", "Kits", "Consumables"],
      locations: ["Storage Room", "Parts Shelf", "Kit Bin", "Workbench", "Tool Cart", "Cabinet"],
    };
  }

  if (usageType === "student") {
    return {
      categories: ["Collection", "Archived", "Display", "Spares", "Reference"],
      locations: ["Shelf", "Storage Box", "Cabinet", "Display Case", "Archive"],
    };
  }

  return {
    categories: ["Unsorted"],
    locations: ["Unsorted"],
  };
}

export function dashboardSuggestedPrompts(usageType: UsageType | null): string[] {
  if (!usageType) {
    return ["Before I buy ___", "Do I already own ___?", "What should I use instead of buying ___?"];
  }

  if (usageType === "mechanic") {
    return ["Before I buy ___", "Do I already own ___?", "What should I use instead of buying ___?"];
  }

  if (usageType === "student") {
    return ["Before I buy ___", "Do I already own ___?", "What should I use instead of buying ___?"];
  }

  if (usageType === "diy") {
    return ["Before I buy ___", "Do I already own ___?", "What should I use instead of buying ___?"];
  }

  return ["Before I buy ___", "Do I already own ___?", "What should I use instead of buying ___?"];
}

export function dashboardAiInputPlaceholder(usageType: UsageType | null): string {
  if (!usageType) return "Before I buy ";
  if (usageType === "mechanic") return "Before I buy ";
  return "Before I buy ";
}

export function dashboardInventorySearchPlaceholder(usageType: UsageType | null): string {
  if (!usageType) return 'Try: "snacks in pantry"';
  if (usageType === "mechanic") return 'Try: "motors in parts shelf"';
  if (usageType === "student") return 'Try: "items in storage"';
  if (usageType === "diy") return 'Try: "drill bits in garage"';
  return 'Try: "items in storage"';
}
