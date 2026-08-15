const SAFE_INTERNAL_PATH = /^\/[\w\-./?=&%#]*$/;

/**
 * Validate and normalize an app-internal route before navigation.
 * Returns null when the path is missing, external, or otherwise unsafe.
 */
export const getSafeInternalRoute = (path) => {
  if (typeof path !== "string") return null;
  if (!path.startsWith("/") || path.startsWith("//")) return null;
  if (!SAFE_INTERNAL_PATH.test(path)) return null;

  try {
    const url = new URL(path, window.location.origin);
    if (url.origin !== window.location.origin) return null;
    return `${url.pathname}${url.search}${url.hash}`;
  } catch {
    return null;
  }
};

/**
 * Open an external URL in a new tab after protocol validation.
 */
export const openSafeExternalUrl = (urlString, target = "_blank") => {
  if (typeof urlString !== "string") return false;

  try {
    const url = new URL(urlString);
    if (url.protocol !== "https:" && url.protocol !== "http:") return false;
    window.open(url.href, target, "noopener,noreferrer");
    return true;
  } catch {
    return false;
  }
};
