import type { InventoryItem } from './api';
import { csvCell } from './csv-export';

export type ImportedSheet = { filename: string; sheet: string; headers: string[] };

/** Only use one source schema when every item belongs to that imported sheet. */
export function importedSheetFor(items: InventoryItem[]): ImportedSheet | null {
  const first = items[0]?.import_data;
  if (!first?.fields?.length) return null;
  const headers = first.fields.map(field => field.name);
  const same = items.every(({ import_data: data }) => data?.filename === first.filename &&
    data?.sheet === first.sheet && data?.fields?.length === headers.length &&
    data.fields.every((field, index) => field.name === headers[index]));
  return same ? { filename: first.filename ?? '', sheet: first.sheet ?? '', headers } : null;
}

export function importedCellText(value: unknown): string {
  if (value == null) return '';
  return typeof value === 'object' ? JSON.stringify(value) : String(value);
}

export function importedSheetCsv(sheet: ImportedSheet, items: InventoryItem[]): string {
  // Position matters: duplicate and blank headers must not collapse into keys.
  return [sheet.headers.map(csvCell).join(','), ...items.map(item =>
    sheet.headers.map((_, index) => {
      const value = item.import_data?.fields?.[index]?.value;
      return csvCell(typeof value === 'object' && value !== null ? importedCellText(value) : value);
    }).join(','))].join('\n');
}
