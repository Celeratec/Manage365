const formatStructuredError = (obj) => {
  if (!obj || typeof obj !== "object" || Array.isArray(obj)) {
    return null;
  }

  // RFC 7807 Problem Details and Manage365 structured API / edge errors
  if ("detail" in obj || "title" in obj) {
    const parts = [];
    const title = typeof obj.title === "string" ? obj.title.trim() : "";
    const detail = typeof obj.detail === "string" ? obj.detail.trim() : "";

    if (title) {
      parts.push(title);
    }
    if (detail && detail !== title) {
      parts.push(detail);
    }

    const action = obj.what_you_should_do;
    if (typeof action === "string" && action.trim()) {
      parts.push(action.trim());
    } else if (Array.isArray(action)) {
      const actionText = action
        .filter((item) => typeof item === "string" && item.trim())
        .join(" ");
      if (actionText) {
        parts.push(actionText);
      }
    }

    if (parts.length > 0) {
      const statusSuffix =
        obj.status !== undefined && obj.status !== null ? ` (HTTP ${obj.status})` : "";
      return `${parts.join(": ")}${statusSuffix}`;
    }
  }

  return null;
};

const formatErrorValue = (value) => {
  if (value == null) {
    return undefined;
  }
  if (typeof value === "string") {
    return value;
  }
  if (typeof value === "number" || typeof value === "boolean") {
    return String(value);
  }

  if (Array.isArray(value)) {
    const formatted = value.map(formatErrorValue).filter(Boolean);
    return formatted.length > 0 ? formatted.join("\n") : undefined;
  }

  if (typeof value === "object") {
    const structured = formatStructuredError(value);
    if (structured) {
      return structured;
    }

    if (typeof value.resultText === "string" && value.resultText.trim()) {
      return value.resultText;
    }
    if (typeof value.message === "string" && value.message.trim()) {
      return value.message;
    }

    for (const key of ["error", "Error", "result"]) {
      if (value[key] != null && value[key] !== value) {
        const formatted = formatErrorValue(value[key]);
        if (formatted) {
          return formatted;
        }
      }
    }

    try {
      return JSON.stringify(value);
    } catch {
      return String(value);
    }
  }

  return String(value);
};

export const getCippError = (data) => {
  const d = data?.response?.data;

  if (d?.result != null) {
    return formatErrorValue(d.result);
  }
  // Backend PowerShell hashtables serialize with PascalCase keys ("Error"),
  // while some endpoints use lowercase ("error"). Check both.
  if (d?.error != null || d?.Error != null) {
    return formatErrorValue(d.error ?? d.Error);
  }
  if (d?.message != null) {
    return formatErrorValue(d.message);
  }

  if (typeof d === "string" && d.includes("<!DOCTYPE html>")) {
    return formatErrorValue(data?.message);
  }

  if (d?.Results != null) {
    return formatErrorValue(d.Results);
  }

  if (d != null) {
    return formatErrorValue(d);
  }

  // CORS-blocked auth redirect: network error on /api/ call with no response
  // indicates the Azure SWA session has expired and the request was redirected
  // to the identity provider, which failed CORS preflight.
  if (
    !data?.response &&
    data?.code === "ERR_NETWORK" &&
    data?.config?.url?.startsWith("/api/")
  ) {
    return "Your session has expired. Please refresh the page to log in again.";
  }

  if (data?.message != null) {
    return formatErrorValue(data.message);
  }
};
