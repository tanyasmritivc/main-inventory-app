const spreadsheetExtensions = ['xlsx', 'csv', 'json'];
const spreadsheetByteLimit = 10 * 1024 * 1024;
const spreadsheetFormats = 'Excel (.xlsx), CSV, or JSON, up to 10 MB';

bool isSpreadsheetFilename(String name) =>
    name.contains('.') &&
    spreadsheetExtensions.contains(name.split('.').last.toLowerCase());
