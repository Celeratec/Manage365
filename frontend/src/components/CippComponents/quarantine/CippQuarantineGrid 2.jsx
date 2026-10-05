import { Chip } from "@mui/material";
import { getCippFormatting } from "../../../utils/get-cipp-formatting";
import {
  getQuarantineReasonLabel,
  getReleaseStatusLabel,
  getSenderDisplay,
  RELEASE_STATUS_COLOR_MAP,
} from "./quarantineConstants";

export const buildQuarantineColumns = ({ showTenant = false } = {}) => {
  const columns = [
    {
      header: "Time Received",
      accessorKey: "ReceivedTime",
      Cell: ({ row }) => getCippFormatting(row.original.ReceivedTime, "ReceivedTime"),
      enableSorting: true,
    },
    {
      header: "Subject",
      accessorKey: "Subject",
      enableSorting: true,
    },
    {
      header: "Sender",
      accessorFn: (row) => getSenderDisplay(row),
      enableSorting: true,
    },
    {
      header: "Quarantine Reason",
      accessorFn: (row) => getQuarantineReasonLabel(row),
      enableSorting: true,
    },
    {
      header: "Recipient",
      accessorKey: "RecipientAddress",
      enableSorting: true,
    },
    {
      header: "Sender Address",
      accessorKey: "SenderAddress",
      enableSorting: true,
    },
    {
      header: "Release Status",
      accessorKey: "ReleaseStatus",
      enableSorting: true,
      Cell: ({ row }) => {
        const status = row.original.ReleaseStatus;
        return (
          <Chip
            label={getReleaseStatusLabel(status)}
            color={RELEASE_STATUS_COLOR_MAP[status] || "default"}
            size="small"
            variant="outlined"
          />
        );
      },
    },
    {
      header: "Policy Type",
      accessorKey: "PolicyType",
      enableSorting: true,
    },
    {
      header: "Expiration",
      accessorKey: "Expires",
      Cell: ({ row }) => getCippFormatting(row.original.Expires, "Expires"),
      enableSorting: true,
    },
    {
      header: "Policy Name",
      accessorKey: "PolicyName",
      enableSorting: true,
    },
  ];

  if (showTenant) {
    columns.push({
      header: "Tenant",
      accessorKey: "Tenant",
      enableSorting: true,
    });
  }

  return columns;
};

export const QUARANTINE_SIMPLE_COLUMNS = [
  "ReceivedTime",
  "Subject",
  "SenderAddress",
  "Type",
  "RecipientAddress",
  "ReleaseStatus",
  "PolicyType",
  "Expires",
  "PolicyName",
  "Tenant",
];

export default buildQuarantineColumns;
