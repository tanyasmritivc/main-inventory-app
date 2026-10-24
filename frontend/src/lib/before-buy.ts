import type { InventoryItem } from "@/lib/api";
export type BeforeIBuyMatch = {
  item: InventoryItem;
  reasons: string[];
  kind: "exact" | "similar";
};
function tokenize(s: string): string[] {
  return (s || "")
    .toLowerCase()
    .split(/[^a-z0-9]+/g)
    .map((t) => t.trim())
    .filter(Boolean);
}

function normalizeToken(t: string): string {
  const s = (t || "").trim().toLowerCase();
  if (!s) return "";
  if (s.length > 4 && s.endsWith("ies")) return `${s.slice(0, -3)}y`;
  if (s.length > 4 && s.endsWith("es")) return s.slice(0, -2);
  if (s.length > 3 && s.endsWith("s")) return s.slice(0, -1);
  return s;
}

function tokenSet(s: string): Set<string> {
  const stop = new Set([
    "a",
    "an",
    "the",
    "to",
    "for",
    "of",
    "and",
    "or",
    "in",
    "on",
    "with",
    "my",
    "your",
    "buy",
    "before",
    "i",
    "me",
  ]);
  const out = new Set<string>();
  for (const raw of tokenize(s)) {
    const t = normalizeToken(raw);
    if (!t) continue;
    if (t.length < 3) continue;
    if (stop.has(t)) continue;
    out.add(t);
  }
  return out;
}

function intersectionCount(a: Set<string>, b: Set<string>): number {
  if (a.size === 0 || b.size === 0) return 0;
  let n = 0;
  for (const t of a) {
    if (b.has(t)) n += 1;
  }
  return n;
}

const CATEGORY_DOMAINS: Record<string, string[]> = {
  food: [
    "food",
    "grocery",
    "snack",
    "pantry",
    "cereal",
    "pasta",
    "rice",
    "spice",
    "coffee",
    "tea",
  ],
  drink: ["drink", "beverage", "soda", "juice", "water"],
  cleaning: [
    "clean",
    "cleaner",
    "soap",
    "detergent",
    "bleach",
    "disinfect",
    "wipe",
    "paper",
    "towel",
    "trash",
  ],
  bathroom: [
    "bath",
    "toilet",
    "shower",
    "tissue",
    "deodorant",
    "shampoo",
    "conditioner",
    "tooth",
    "dental",
  ],
  personal_care: [
    "skincare",
    "lotion",
    "cream",
    "razor",
    "makeup",
    "cosmetic",
    "sunscreen",
  ],
  health: [
    "health",
    "medical",
    "medicine",
    "vitamin",
    "first",
    "aid",
    "bandage",
  ],
  tools: [
    "tool",
    "hardware",
    "hammer",
    "screw",
    "driver",
    "wrench",
    "drill",
    "tape",
    "measure",
  ],
  home_improvement: ["paint", "roller", "brush", "caulk", "glue", "adhesive"],
  office: [
    "office",
    "paper",
    "pen",
    "pencil",
    "marker",
    "notebook",
    "staple",
    "tape",
  ],
  electronics: [
    "electronic",
    "cable",
    "charger",
    "battery",
    "usb",
    "adapter",
    "hdmi",
  ],
  baby: ["baby", "diaper", "wipe", "formula"],
  pet: ["pet", "dog", "cat", "litter", "treat"],
  kitchen: [
    "kitchen",
    "cook",
    "bake",
    "utensil",
    "knife",
    "pan",
    "pot",
    "dish",
  ],
  laundry: ["laundry", "dryer", "washer", "softener"],
  clothing: ["clothing", "shirt", "pant", "sock", "shoe", "jacket"],
};

const LOCATION_DOMAINS: Record<string, string[]> = {
  kitchen: ["kitchen", "counter", "cabinet", "drawer"],
  pantry: ["pantry"],
  fridge: ["fridge", "refrigerator"],
  freezer: ["freezer"],
  bathroom: ["bath", "bathroom"],
  bedroom: ["bed", "bedroom"],
  closet: ["closet"],
  laundry: ["laundry"],
  garage: ["garage"],
  storage: ["storage", "shed", "basement", "attic", "bin", "box"],
  office: ["office", "desk"],
};

function domainsForTokens(
  tokens: Set<string>,
  domains: Record<string, string[]>,
): Set<string> {
  const out = new Set<string>();
  for (const [domain, keys] of Object.entries(domains)) {
    for (const k of keys) {
      if (tokens.has(normalizeToken(k))) {
        out.add(domain);
        break;
      }
    }
  }
  return out;
}

function setIntersects(a: Set<string>, b: Set<string>): boolean {
  if (a.size === 0 || b.size === 0) return false;
  for (const v of a) {
    if (b.has(v)) return true;
  }
  return false;
}

function normalize(s: string): string {
  return (s || "").trim().toLowerCase();
}

export function beforeBuyMatches(
  q: string,
  items: InventoryItem[],
  parsed?: Record<string, unknown>,
): BeforeIBuyMatch[] {
  const queryTokens = tokenSet(q);
  const parsedStrings: string[] = [];
  if (parsed && typeof parsed === "object") {
    for (const v of Object.values(parsed)) {
      if (typeof v === "string") parsedStrings.push(v);
    }
  }
  const parsedTokens = tokenSet(parsedStrings.join(" "));
  const intentTokens = new Set<string>([...queryTokens, ...parsedTokens]);

  const intentCategoryDomains = domainsForTokens(
    intentTokens,
    CATEGORY_DOMAINS,
  );
  const intentLocationDomains = domainsForTokens(
    intentTokens,
    LOCATION_DOMAINS,
  );

  const matches: BeforeIBuyMatch[] = [];
  for (const it of items) {
    const nameNorm = normalize(it.name);
    const categoryNorm = normalize(it.category);
    const locationNorm = normalize(it.location);
    const reasons: string[] = [];

    const exact = nameNorm === normalize(q);
    if (exact) reasons.push("Exact name match");

    const nameTokens = tokenSet(it.name);
    const categoryTokens = tokenSet(it.category || "");
    const locationTokens = tokenSet(it.location || "");

    const nameOverlap = intersectionCount(nameTokens, intentTokens);
    if (nameOverlap > 0) reasons.push("Name overlaps your intent");

    const categoryOverlap = intersectionCount(categoryTokens, intentTokens);
    if (categoryOverlap > 0) reasons.push("Category overlaps your intent");

    const locationOverlap = intersectionCount(locationTokens, intentTokens);
    if (locationOverlap > 0) reasons.push("Location overlaps your intent");

    const categoryDomains = domainsForTokens(categoryTokens, CATEGORY_DOMAINS);
    if (setIntersects(categoryDomains, intentCategoryDomains))
      reasons.push("Category overlaps your intent");

    const locationDomains = domainsForTokens(locationTokens, LOCATION_DOMAINS);
    if (setIntersects(locationDomains, intentLocationDomains))
      reasons.push("Location overlaps your intent");

    const parsedCategoryHit =
      parsedTokens.size > 0 &&
      (intersectionCount(categoryTokens, parsedTokens) > 0 ||
        (categoryNorm &&
          [...parsedTokens].some((t) => categoryNorm.includes(t))));
    if (parsedCategoryHit) reasons.push("Related by search");

    const parsedLocationHit =
      parsedTokens.size > 0 &&
      (intersectionCount(locationTokens, parsedTokens) > 0 ||
        (locationNorm &&
          [...parsedTokens].some((t) => locationNorm.includes(t))));
    if (parsedLocationHit) reasons.push("Related by search");

    const shouldInclude = exact || reasons.length > 0;
    if (!shouldInclude) continue;

    if (!exact && reasons.length === 0) reasons.push("Related by search");

    const kind: "exact" | "similar" = exact ? "exact" : "similar";
    matches.push({ item: it, reasons, kind });
  }

  matches.sort((a, b) => {
    if (a.kind !== b.kind) return a.kind === "exact" ? -1 : 1;
    return (a.item.name || "").localeCompare(b.item.name || "");
  });

  return matches;
}
