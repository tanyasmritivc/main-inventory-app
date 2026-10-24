/** A local, unsaved demonstration. Never queries inventory or invents saved stock. */
export const PREVIEW_PROMPT_LIMIT = 2000;
export function previewPrompt(value: unknown): string {
  return typeof value === "string" ? value.replace(/[\u0000-\u0009\u000b-\u001f]/g, " ").trim().slice(0, PREVIEW_PROMPT_LIMIT) : "";
}

export type PreviewItem = { name: string; quantity: number | null; source: "prompt" | "example" };
export type LandingPreview = {
  prompt: string; title: string; space: string; items: PreviewItem[];
  intent: "organize" | "find" | "project"; note: string;
};
const examples: [RegExp, string, string, string[]][] = [
  [/robot|arduino|electronic|circuit|resistor/i, "Electronics", "Parts drawer", ["Arduino board", "Jumper wires", "Resistors"]],
  [/garage|workshop|tool|screw|drill/i, "Workshop", "Workbench", ["Cordless drill", "Screwdriver set", "Fasteners"]],
  [/kitchen|pantry|cook|food/i, "Kitchen", "Pantry", ["Rice", "Pasta", "Olive oil"]],
  [/book|library|reading/i, "Library", "Bookshelf", ["Books to read", "Reference books", "Favorites"]],
  [/office|desk|cable|batter/i, "Everyday essentials", "Storage", ["USB-C cable", "AA batteries", "Notebook"]],
  [/art|paint|craft|studio/i, "Studio", "Supply shelf", ["Paint brushes", "Sketchbooks", "Acrylic paints"]],
  [/travel|camp|hiking/i, "Adventure kit", "Gear storage", ["Backpack", "Flashlight", "Water bottle"]],
];

export function buildLandingPreview(input: string): LandingPreview {
  const prompt = previewPrompt(input);
  const intent = /\b(find|where|do i have|how many|running low|restock)\b/i.test(prompt) ? "find"
    : /\b(project|robot|bom|bill of materials|missing)\b/i.test(prompt) ? "project" : "organize";
  const context = examples.find(([pattern]) => pattern.test(prompt));
  const named = prompt.match(/inventory (?:called|named) ["']?([^"',.;\n]+?)(?=\s+(?:with|and|in|for)\b|["',.;]|$)/i)?.[1];
  const namedSpace = prompt.match(/space (?:called|named) ["']?([^"',.;\n]+?)(?=\s+(?:with|and|in|for)\b|["',.;]|$)/i)?.[1]
    || prompt.match(/with (?:a |an )?([\w -]{1,40}?) space\b/i)?.[1];
  const location = prompt.match(/\b(?:in|into|to) (?:my |the )?((?:[^,.;]*?\s)?(?:drawer|shelf|garage|pantry|storage|workbench|closet|desk))(?:\s|[.,;]|$)/i)?.[1];
  const space = (namedSpace || location || context?.[2] || "My Space").slice(0, 60);
  const title = (named || context?.[1] || "Your world").slice(0, 60);
  const items: PreviewItem[] = [];
  // Extract only explicit count + item phrases, never quantities inferred from a model number.
  if (intent !== "find") {
    const list = prompt.replace(/\b(?:add|bought|received|have|need)\s+/gi, "|")
      .split(/\||,|;|\n|\band\b/i);
    for (const part of list) {
      const match = part.trim().replace(/^(?:a|an)\s+/i, "1 ").match(/^(-?\d+(?:\.\d+)?)\s+(.+)$/);
      if (!match) continue;
      const name = match[2].replace(/\s+(?:in|into|to|for|with)\s+.*$/i, "").replace(/[.!?]+$/, "").trim();
      if (!name || /^(?:items?|spaces?|inventories|drawers?|shelves|more|less|of these|of those)\b/i.test(name)) continue;
      const number = Number(match[1]);
      items.push({ name: name.slice(0, 100), quantity: Number.isSafeInteger(number) && number >= 0 ? number : null, source: "prompt" });
      if (items.length === 24) break;
    }
  }
  if (!items.length && context) items.push(...context[3].map(name => ({ name, quantity: null, source: "example" as const })));
  const explicit = items.some(item => item.source === "prompt");
  let note = intent === "find"
    ? "This shows how saved results can look. Sign in to search your actual inventory."
    : intent === "project"
      ? "A starting layout for your project. Stock, shortages and compatibility need your saved inventory."
      : explicit ? "Items and counts taken from your description. Review them before saving."
        : "A suggested layout to explore. Example items are not things we know you own.";
  if (items.length === 24) note += " Preview limited to 24 entries; your full request is kept.";
  return { prompt, title, space, items, intent, note };
}

/** Carry only the visitor's words, never suggested example stock, into authenticated Ask. */
export function continuePreview(destination: string, input: string): string {
  const prompt = previewPrompt(input);
  if (!prompt) return destination;
  const query = new URLSearchParams({ q: prompt });
  const inventory = new URL(destination, "https://findez.ai").searchParams.get("inventory");
  if (inventory) query.set("inventory", inventory);
  return `/assist?${query}`;
}

export function previewAuthDestination(next: string, input: string, signup: boolean): string {
  const prompt = previewPrompt(input);
  // Invitations and recovery must keep their existing ownership/consent flow.
  if (!prompt || /^\/(?:join|reset-password|auth)(?:[/?]|$)/.test(next)) return next;
  return signup ? `/onboarding?${new URLSearchParams({ prompt })}` : continuePreview(next, prompt);
}
