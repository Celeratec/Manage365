export const QUARANTINE_DAYS_OPTIONS = [
  { label: "Last 24 hours", value: 1 },
  { label: "Last 7 days", value: 7 },
  { label: "Last 30 days", value: 30 },
];

export const QUARANTINE_TIME_PRESETS = [
  { key: "24h", label: "Last 24 hours", days: 1 },
  { key: "7d", label: "Last 7 days", days: 7 },
  { key: "30d", label: "Last 30 days", days: 30 },
];

export const QUARANTINE_TYPE_OPTIONS = [
  { label: "Spam", value: "Spam" },
  { label: "Bulk", value: "Bulk" },
  { label: "Phish", value: "Phish" },
  { label: "High Confidence Phish", value: "HighConfPhish" },
  { label: "Malware", value: "Malware" },
  { label: "Transport Rule", value: "TransportRule" },
  { label: "Data Loss Prevention", value: "DataLossPrevention" },
];

export const RELEASE_STATUS_OPTIONS = [
  { label: "Not Released", value: "NOTRELEASED" },
  { label: "Released", value: "RELEASED" },
  { label: "Release Requested", value: "REQUESTED" },
  { label: "Denied", value: "DENIED" },
  { label: "Failed", value: "ERROR" },
  { label: "Approved", value: "APPROVED" },
  { label: "Preparing to Release", value: "PREPARINGTORELEASE" },
];

export const POLICY_TYPE_OPTIONS = [
  { label: "Anti-spam policy", value: "HostedContentFilterPolicy" },
  { label: "Anti-phishing policy", value: "AntiPhishPolicy" },
  { label: "Anti-malware policy", value: "AntiMalwarePolicy" },
  { label: "Safe attachments", value: "SafeAttachmentPolicy" },
  { label: "Transport rule", value: "ExchangeTransportRule" },
  { label: "DLP rule", value: "DataLossPreventionRule" },
];

export const RELEASE_STATUS_COLOR_MAP = {
  RELEASED: "success",
  DENIED: "error",
  NOTRELEASED: "warning",
  REQUESTED: "info",
  ERROR: "error",
  APPROVED: "success",
  PREPARINGTORELEASE: "info",
};

export const RELEASE_STATUS_LABELS = {
  RELEASED: "Released",
  DENIED: "Denied",
  NOTRELEASED: "Not Released",
  REQUESTED: "Release Requested",
  ERROR: "Failed",
  APPROVED: "Approved",
  PREPARINGTORELEASE: "Preparing to Release",
};

export const QUARANTINE_ACTION_WARNINGS = {
  allowSender:
    "Adding a sender to the tenant allow list may allow future messages from that sender to bypass some protections. Prefer allowing a specific sender over a whole domain where possible.",
  allowDomain:
    "Adding a sender domain to the allow list may allow future malicious messages from that domain to bypass some protections. Prefer allowing a specific sender where possible.",
  blockSender: "Blocking this sender will reject future messages from this address for all users in the tenant.",
  blockDomain:
    "Blocking this domain will reject future messages from any address at this domain for all users in the tenant.",
  release: "Releasing this message will deliver it to the original recipient(s).",
  delete: "Deleting removes the message from quarantine permanently. This cannot be undone.",
  submitToMicrosoft:
    "This submits the message to Microsoft for review as a potential false positive while releasing it.",
};

export const getReleaseStatusLabel = (status) =>
  RELEASE_STATUS_LABELS[status] || status || "Unknown";

export const getQuarantineReasonLabel = (row) => row?.QuarantineReason || row?.Type || "Unknown";

export const getSenderDisplay = (row) => row?.SenderName || row?.SenderAddress || "Unknown";

const serializeArrayFilterForGet = (value) => {
  if (!value) return undefined;
  if (Array.isArray(value)) {
    const normalized = value
      .map((item) => (typeof item === "object" ? item?.value ?? item?.label : item))
      .filter(Boolean);
    return normalized.length ? normalized.join(",") : undefined;
  }
  return value;
};

export const buildQuarantineSearchPayload = (values, tenantFilter, overrides = {}) => {
  const merged = { ...values, ...overrides };
  const data = { tenantFilter };

  if (merged.messageId) {
    data.messageId = merged.messageId;
    return data;
  }

  if (merged.sender?.length) data.sender = merged.sender;
  if (merged.recipient?.length) data.recipient = merged.recipient;
  if (merged.status?.length) data.status = merged.status[0]?.value ?? merged.status[0];
  if (merged.fromIP) data.fromIP = merged.fromIP;
  if (merged.toIP) data.toIP = merged.toIP;
  if (merged.subject) data.subject = merged.subject;
  if (merged.subjectExact) data.subjectExact = merged.subjectExact;
  if (merged.senderDomain) data.senderDomain = merged.senderDomain;
  if (merged.recipientDomain) data.recipientDomain = merged.recipientDomain;
  if (merged.policyName) data.policyName = merged.policyName;

  if (merged.quarantineType?.length) {
    data.quarantineType = merged.quarantineType.map((item) => item?.value ?? item);
  }
  if (merged.releaseStatus?.length) {
    data.releaseStatus = merged.releaseStatus.map((item) => item?.value ?? item);
  }
  if (merged.policyTypes?.length) {
    data.policyTypes = merged.policyTypes.map((item) => item?.value ?? item);
  }

  if (merged.dateFilter === "relative") {
    data.days = merged.days?.value ?? merged.days ?? 7;
  } else {
    data.startDate = merged.startDate;
    data.endDate = merged.endDate;
  }

  return data;
};

export const buildQuarantineListQuery = (filters, tenantFilter) => {
  const payload = buildQuarantineSearchPayload(filters, tenantFilter);
  const { quarantineType, releaseStatus, policyTypes, ...rest } = payload;

  return {
    tenantFilter,
    manualPagination: true,
    pageSize: 100,
    days: rest.days ?? 7,
    ...rest,
    ...(quarantineType ? { quarantineType: serializeArrayFilterForGet(quarantineType) } : {}),
    ...(releaseStatus ? { releaseStatus: serializeArrayFilterForGet(releaseStatus) } : {}),
    ...(policyTypes ? { policyTypes: serializeArrayFilterForGet(policyTypes) } : {}),
  };
};

export const buildQuarantineExportFilename = (tenantFilter, format, label = null) => {
  const tenant = (tenantFilter || "tenant").replace(/[^a-zA-Z0-9.-]+/g, "_");
  const timestamp = new Date().toISOString().replace(/[:.]/g, "-").slice(0, 19);
  const extension = format.replace(/^\./, "");
  const suffix = label ? `-${label}` : "";
  return `quarantine-${tenant}-${timestamp}${suffix}.${extension}`;
};

export const triggerQuarantineFileDownload = (content, mimeType, filename) => {
  const blob = new Blob([content], { type: mimeType });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = filename;
  link.click();
  URL.revokeObjectURL(url);
};

export const hasQuarantinePostFilters = (values = {}) =>
  Boolean(values.subject || values.senderDomain || values.recipientDomain);
