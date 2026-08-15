import { Block, CheckCircle, ContentCopy, Done, DoneAll } from "@mui/icons-material";
import { EyeIcon, DocumentTextIcon } from "@heroicons/react/24/outline";
import { QUARANTINE_ACTION_WARNINGS } from "./quarantineConstants";

const summarizeSenderAddresses = (senders, limit = 5) => {
  const preview = senders.slice(0, limit).join(", ");
  if (senders.length > limit) {
    return `${preview}, and ${senders.length - limit} more`;
  }
  return preview;
};

export const handleBulkBlockSenders = ({
  rows,
  tenantFilter,
  mutate,
  dispatch,
  showToast,
  sourceLabel = "Quarantine Management",
  onComplete,
}) => {
  const uniqueSenders = [
    ...new Set(rows.map((row) => row.SenderAddress?.trim()).filter(Boolean)),
  ];
  const missingCount = rows.filter((row) => !row.SenderAddress?.trim()).length;

  if (!uniqueSenders.length) {
    dispatch(
      showToast({
        message: "No sender addresses were found in the selected rows.",
        title: "Block Senders",
      })
    );
    return;
  }

  const confirmLines = [
    `Block ${uniqueSenders.length} unique sender address(es)?`,
    "",
    summarizeSenderAddresses(uniqueSenders),
  ];
  if (missingCount > 0) {
    confirmLines.push(
      "",
      `${missingCount} selected row(s) have no sender address and will be skipped.`
    );
  }
  confirmLines.push("", QUARANTINE_ACTION_WARNINGS.blockSender, "Continue?");
  if (!window.confirm(confirmLines.join("\n"))) {
    return;
  }

  mutate(
    {
      url: "/api/AddTenantAllowBlockList",
      data: {
        tenantID: tenantFilter,
        entries: uniqueSenders,
        listType: "Sender",
        listMethod: "Block",
        notes: `Blocked via ${sourceLabel} bulk action`,
        NoExpiration: true,
      },
    },
    {
      onSuccess: (response) => {
        const resultMessages = Array.isArray(response?.data?.Results)
          ? response.data.Results
          : [response?.data?.Results].filter(Boolean);
        const failures = resultMessages.filter((message) =>
          String(message).toLowerCase().includes("failed")
        );

        if (failures.length) {
          dispatch(
            showToast({
              message:
                failures.length === resultMessages.length
                  ? failures.join(" ")
                  : `Blocked ${uniqueSenders.length - failures.length} of ${uniqueSenders.length} sender(s). ${failures.join(" ")}`,
              title: failures.length === resultMessages.length ? "Block Senders Failed" : "Partial Success",
              ...(failures.length === resultMessages.length ? { toastError: { message: failures.join(" ") } } : {}),
            })
          );
        } else {
          dispatch(
            showToast({
              message: `Blocked ${uniqueSenders.length} sender address(es).`,
              title: "Block Senders",
            })
          );
        }
        onComplete?.();
      },
      onError: (error) => {
        dispatch(
          showToast({
            message: error?.response?.data?.Results || error?.message || "Failed to block senders.",
            title: "Block Senders Failed",
            toastError: error,
          })
        );
      },
    }
  );
};

export const buildQuarantineActions = ({
  tenantFilter,
  onPreview,
  onViewTrace,
  onViewTimeline,
  includeExplorerLink = false,
}) => {
  const actions = [
    {
      label: "View Message",
      noConfirm: true,
      customFunction: onPreview,
      icon: <EyeIcon />,
      category: "view",
    },
  ];

  if (onViewTimeline) {
    actions.push({
      label: "View Delivery Timeline",
      noConfirm: true,
      customFunction: onViewTimeline,
      icon: <DocumentTextIcon />,
      category: "view",
    });
  }

  if (onViewTrace) {
    actions.push({
      label: "View Message Trace",
      noConfirm: true,
      customFunction: onViewTrace,
      icon: <DocumentTextIcon />,
      category: "view",
    });
  }

  if (includeExplorerLink) {
    actions.push({
      label: "View in Explorer",
      noConfirm: true,
      link: `https://security.microsoft.com/realtimereportsv3?tid=${tenantFilter}&dltarget=Explorer&dlstorage=Url&viewid=allemail&query-NetworkMessageId=[MessageId]`,
      icon: <DocumentTextIcon />,
      category: "view",
    });
  }

  actions.push(
    {
      label: "Release",
      type: "POST",
      url: "/api/ExecQuarantineManagement",
      multiPost: true,
      data: { Identity: "Identity", Type: "!Release" },
      confirmText: `${QUARANTINE_ACTION_WARNINGS.release} Continue?`,
      icon: <Done />,
      condition: (row) => row.ReleaseStatus !== "RELEASED",
      category: "manage",
    },
    {
      label: "Deny",
      type: "POST",
      url: "/api/ExecQuarantineManagement",
      data: { Identity: "Identity", Type: "!Deny", RecipientAddress: "RecipientAddress" },
      confirmText: "Are you sure you want to deny this message?",
      icon: <Block />,
      condition: (row) => row.ReleaseStatus !== "DENIED",
      category: "security",
    },
    {
      label: "Release & Allow Sender",
      type: "POST",
      url: "/api/ExecQuarantineManagement",
      data: { Identity: "Identity", Type: "!Release", AllowSender: true },
      confirmText: `${QUARANTINE_ACTION_WARNINGS.allowSender} Continue?`,
      icon: <DoneAll />,
      condition: (row) => row.ReleaseStatus !== "RELEASED",
      category: "security",
    },
    {
      label: "Release & Add Allow Entry",
      type: "POST",
      url: "/api/ExecQuarantineManagement",
      data: { Identity: "Identity", Type: "!Release", AddAllowEntry: true },
      confirmText: `${QUARANTINE_ACTION_WARNINGS.allowSender} Continue?`,
      icon: <DoneAll />,
      condition: (row) => row.ReleaseStatus !== "RELEASED",
      category: "security",
    },
    {
      label: "Submit to Microsoft",
      type: "POST",
      url: "/api/ExecQuarantineManagement",
      data: { Identity: "Identity", Type: "!Release", ReportFalsePositive: true },
      confirmText: `${QUARANTINE_ACTION_WARNINGS.submitToMicrosoft} Continue?`,
      icon: <Done />,
      condition: (row) => row.ReleaseStatus !== "RELEASED",
      category: "security",
    },
    {
      label: "Delete",
      type: "POST",
      url: "/api/ExecQuarantineManagement",
      data: { Identity: "Identity", Type: "!Delete" },
      confirmText: `${QUARANTINE_ACTION_WARNINGS.delete} Continue?`,
      icon: <Block />,
      category: "security",
    },
    {
      label: "Allow Sender",
      type: "POST",
      url: "/api/AddTenantAllowBlockList",
      data: {
        tenantID: tenantFilter,
        entries: "SenderAddress",
        listType: "!Sender",
        listMethod: "!Allow",
        notes: "!Allowed via Quarantine Management",
        RemoveAfter: true,
      },
      confirmText: `${QUARANTINE_ACTION_WARNINGS.allowSender} Continue?`,
      icon: <CheckCircle />,
      category: "security",
    },
    {
      label: "Allow Sender Domain",
      type: "POST",
      url: "/api/ExecQuarantineManagement",
      data: { Identity: "Identity", Type: "!AllowDomain" },
      confirmText: `${QUARANTINE_ACTION_WARNINGS.allowDomain} Continue?`,
      icon: <CheckCircle />,
      category: "security",
    },
    {
      label: "Block Sender",
      type: "POST",
      url: "/api/AddTenantAllowBlockList",
      data: {
        tenantID: tenantFilter,
        entries: "SenderAddress",
        listType: "!Sender",
        listMethod: "!Block",
        notes: "!Blocked via Quarantine Management",
        NoExpiration: true,
      },
      confirmText: `${QUARANTINE_ACTION_WARNINGS.blockSender} Continue?`,
      icon: <Block />,
      category: "security",
    },
    {
      label: "Block Sender Domain",
      type: "POST",
      url: "/api/ExecQuarantineManagement",
      data: { Identity: "Identity", Type: "!BlockDomain" },
      confirmText: `${QUARANTINE_ACTION_WARNINGS.blockDomain} Continue?`,
      icon: <Block />,
      category: "security",
    },
    {
      label: "Copy Message ID",
      noConfirm: true,
      customFunction: (row) => navigator.clipboard.writeText(row.MessageId || row.Identity || ""),
      icon: <ContentCopy />,
      category: "view",
    }
  );

  return actions;
};

export default buildQuarantineActions;
