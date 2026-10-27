// Stable backend keys. Labels are alphabetically ordered for every inventory group.
export const teamCategories = [
  { value: "agriculture", label: "Agriculture" },
  { value: "art_design", label: "Art & design" },
  { value: "automotive", label: "Automotive" },
  { value: "business", label: "Business" },
  { value: "club", label: "Club or community" },
  { value: "construction", label: "Construction" },
  { value: "custom", label: "Custom category" },
  { value: "education", label: "Education or school" },
  { value: "electronics", label: "Electronics" },
  { value: "engineering", label: "Engineering" },
  { value: "hospitality", label: "Events & hospitality" },
  { value: "manufacturing", label: "Factory & manufacturing" },
  { value: "fll", label: "FIRST LEGO League" },
  { value: "frc", label: "FIRST Robotics Competition" },
  { value: "ftc", label: "FIRST Tech Challenge" },
  { value: "healthcare", label: "Healthcare" },
  { value: "household", label: "Household" },
  { value: "laboratory", label: "Laboratory" },
  { value: "logistics", label: "Logistics & warehouse" },
  { value: "makerspace", label: "Makerspace or workshop" },
  { value: "nonprofit", label: "Nonprofit" },
  { value: "office", label: "Office" },
  { value: "other", label: "Other" },
  { value: "research", label: "Research" },
  { value: "retail", label: "Retail" },
  { value: "robotics", label: "Robotics" },
  { value: "sports", label: "Sports & recreation" },
  { value: "studio", label: "Studio & media" },
  { value: "vex", label: "VEX Robotics" },
] as const;
export type TeamCategory = typeof teamCategories[number]["value"];
export function teamCategoryLabel(program?: string, customCategory?: string | null) {
  if (program === "custom" && customCategory?.trim()) return customCategory.trim();
  return teamCategories.find((category) => category.value === program)?.label ?? "Team";
}
