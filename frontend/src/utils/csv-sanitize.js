// Guards against CSV / spreadsheet formula injection (a.k.a. CSV injection).
//
// Spreadsheet apps (Excel, Sheets, LibreOffice) treat a cell whose text begins with
// =, +, -, @, or a leading tab / carriage return as a formula. Exported data that
// originates from user- or tenant-controlled values (file names, errors, URLs) can
// therefore execute when an admin opens the exported file. Prefixing such values with a
// single quote forces the cell to be treated as text without altering what is displayed.
const FORMULA_TRIGGERS = ["=", "+", "-", "@", "\t", "\r"];

export const sanitizeCsvCell = (value) => {
  if (value === null || value === undefined) {
    return value;
  }
  // Only string-like content can carry a formula trigger. Numbers/booleans are safe and
  // are returned unchanged so downstream typing/formatting is preserved.
  if (typeof value !== "string") {
    return value;
  }
  if (value.length > 0 && FORMULA_TRIGGERS.includes(value[0])) {
    return `'${value}`;
  }
  return value;
};

// Sanitizes every value of a flat row object, returning a new object.
export const sanitizeCsvRow = (row) => {
  if (!row || typeof row !== "object") {
    return row;
  }
  const out = {};
  for (const key of Object.keys(row)) {
    out[key] = sanitizeCsvCell(row[key]);
  }
  return out;
};
