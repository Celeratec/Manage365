import { blue, orange, indigo, purple, cerulean } from "./colors";

/**
 * Resolves palette keys (e.g. primary), bare CSS colors, or "text.secondary" to a string
 * safe for alpha() and sx. Slots like neutral/grey have no .main; missing values would crash MUI's color parser.
 */
export function resolvePaletteMainColor(theme, colorKey) {
  if (!colorKey || typeof colorKey !== "string") {
    return theme.palette.primary.main;
  }
  const trimmed = colorKey.trim();
  // App actions often use "danger"; MUI palette uses "error"
  if (trimmed === "danger") {
    return theme.palette.error.main;
  }
  if (trimmed === "text.secondary") {
    return theme.palette.text.secondary;
  }
  if (/^(#|rgb|hsl|var\()/i.test(trimmed)) {
    return trimmed;
  }
  const slot = theme.palette[trimmed];
  if (slot && typeof slot.main === "string") {
    return slot.main;
  }
  return theme.palette.primary.main;
}

export const getPrimary = (preset) => {
  switch (preset) {
    case "blue":
      return blue;
    case "orange":
      return orange;
    case "indigo":
      return indigo;
    case "purple":
      return purple;
    case "cerulean":
      return cerulean;
    default:
      console.error(
        'Invalid color preset, accepted values: "blue", "orange", "indigo", "purple" or "cerulean".'
      );
      return cerulean;
  }
};
