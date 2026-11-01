/** Bounded landing prompt handoff shared by signup, signin and onboarding. */
export const PREVIEW_PROMPT_LIMIT = 2000;
export function previewPrompt(value: unknown): string {
  return typeof value === "string"
    ? value
        .replace(/[\u0000-\u0009\u000b-\u001f]/g, " ")
        .trim()
        .slice(0, PREVIEW_PROMPT_LIMIT)
    : "";
}

/** Carry the visitor's original words into authenticated Ask for review. */
export function continuePreview(destination: string, input: string): string {
  const prompt = previewPrompt(input);
  if (!prompt) return destination;
  const query = new URLSearchParams({ q: prompt });
  const inventory = new URL(destination, "https://findez.ai").searchParams.get(
    "inventory",
  );
  if (inventory) query.set("inventory", inventory);
  return inventory ? `/assist?${query}` : `/worlds?${query}`;
}

export function previewAuthDestination(
  next: string,
  input: string,
  _signup: boolean,
): string {
  void _signup;
  const prompt = previewPrompt(input);
  // Invitations and recovery must keep their existing ownership/consent flow.
  if (!prompt || /^\/(?:join|reset-password|auth)(?:[/?]|$)/.test(next))
    return next;
  return continuePreview(next, prompt);
}
