/** Quote CSV fields and keep inventory text from becoming spreadsheet formulas. */
export function csvCell(value: unknown): string {
  let text = String(value ?? '');
  // Preserve actual numeric quantities; neutralize text prefixes, control and
  // full-width variants before escaping separators/quotes. Export is for viewing,
  // and the literal marker can remain visible when reimported as raw CSV data.
  if (typeof value === 'string' && (/^[\t\r\n\0]/.test(text) || /^[\s\uFEFF]*[=+\-@＝＋－＠]/.test(text))) {
    text = "'" + text;
  }
  return `"${text.replaceAll('"', '""')}"`;
}
