export type UsageType = "homeowner" | "diy" | "mechanic" | "student" | "other";

export const USAGE_TYPE_OPTIONS: Array<{ value: UsageType; label: string }> = [
  { value: "homeowner", label: "Homeowner / Household" },
  { value: "diy", label: "DIY / Tools / Garage" },
  { value: "mechanic", label: "Mechanic / Workshop" },
  { value: "student", label: "Student / Small space" },
  { value: "other", label: "Other" },
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
      categories: ["Parts", "Tools", "Fluids", "Fasteners", "Electrical", "Consumables"],
      locations: ["Bay 1", "Tool Chest", "Parts Shelf", "Storage Rack", "Workbench", "Cabinet"],
    };
  }

  if (usageType === "student") {
    return {
      categories: ["School", "Snacks", "Tech", "Clothes", "Toiletries", "Supplies"],
      locations: ["Desk", "Backpack", "Closet", "Drawer", "Shelf", "Under bed"],
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
  if (usageType === "mechanic") return 'Try: "oil filters in tool chest"';
  if (usageType === "student") return 'Try: "snacks in backpack"';
  if (usageType === "diy") return 'Try: "drill bits in garage"';
  return 'Try: "items in storage"';
}
