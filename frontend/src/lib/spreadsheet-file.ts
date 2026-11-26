export const spreadsheetAccept = ".csv,.xlsx,.json";
export const spreadsheetFileHint = "Excel (.xlsx), CSV, or JSON, up to 10 MB.";

export function spreadsheetFileError(file: File): string | undefined {
  if (
    !/\.(csv|xlsx|json)$/i.test(file.name) ||
    !file.size ||
    file.size > 10 * 1024 * 1024
  )
    return "Choose a nonempty Excel (.xlsx), CSV, or JSON file up to 10 MB.";
}
