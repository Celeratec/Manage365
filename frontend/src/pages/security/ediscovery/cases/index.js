import { useState } from "react";
import { Layout as DashboardLayout } from "../../../../layouts/index.jsx";
import { CippTablePage } from "../../../../components/CippComponents/CippTablePage.jsx";
import { Alert, AlertTitle, Collapse, IconButton, Link } from "@mui/material";
import {
  Add,
  OpenInNew,
  Lock,
  LockOpen,
  Close,
} from "@mui/icons-material";

const Page = () => {
  const pageTitle = "eDiscovery Cases";
  const [setupBannerOpen, setSetupBannerOpen] = useState(true);

  const guardedWriteFields = [
    {
      name: "ticketNumber",
      label: "Ticket Number",
      type: "textField",
      required: true,
      validators: { required: "Ticket number is required" },
    },
    {
      name: "reason",
      label: "Reason",
      type: "textField",
      required: true,
      validators: { required: "Reason is required" },
    },
    {
      name: "dryRun",
      label: "Preview only (dry run)",
      type: "switch",
      defaultValue: true,
    },
  ];

  const actions = [
    {
      label: "Open Case",
      link: "/security/ediscovery/cases/case?caseId=[id]",
      icon: <OpenInNew />,
      color: "primary",
      category: "view",
    },
    {
      label: "Close Case",
      type: "POST",
      icon: <Lock />,
      url: "/api/ExecEdiscoveryCase",
      data: {
        caseId: "id",
        action: "!close",
      },
      fields: guardedWriteFields,
      confirmText: "Are you sure you want to close this case? Holds will remain active.",
      condition: (row) => row.status === "active",
      category: "edit",
    },
    {
      label: "Reopen Case",
      type: "POST",
      icon: <LockOpen />,
      url: "/api/ExecEdiscoveryCase",
      data: {
        caseId: "id",
        action: "!reopen",
      },
      fields: guardedWriteFields,
      confirmText: "Are you sure you want to reopen this case?",
      condition: (row) => row.status === "closed",
      category: "edit",
    },
  ];

  const offCanvas = {
    actions: actions,
    children: (row) => null,
  };

  const simpleColumns = [
    "displayName",
    "status",
    "createdBy",
    "createdDate",
    "description",
  ];

  const setupBanner = (
    <Collapse in={setupBannerOpen}>
      <Alert
        severity="info"
        action={
          <IconButton size="small" onClick={() => setSetupBannerOpen(false)}>
            <Close fontSize="inherit" />
          </IconButton>
        }
      >
        <AlertTitle>Tenant Setup Required</AlertTitle>
        Before using eDiscovery, each client tenant needs a dedicated eDiscovery app registration
        and certificate configured in Manage365. Do not use the CIPP SAM app for eDiscovery. Check{" "}
        <strong>ListEdiscoveryReadiness</strong> for the tenant, then add the dedicated app&apos;s
        service principal to the <strong>eDiscovery Manager</strong> role group in Purview:{" "}
        <Link
          href="https://compliance.microsoft.com/compliancecentersettings/securityandcompliancecenterrolesv2"
          target="_blank"
          rel="noopener noreferrer"
        >
          Purview &gt; Settings &gt; Roles &amp; Scopes &gt; Permissions
        </Link>
        . Case delete, hold removal, purge, exports, and content downloads are refused in Manage365 v1.
      </Alert>
    </Collapse>
  );

  return (
    <CippTablePage
      title={pageTitle}
      apiUrl="/api/ListEdiscoveryCases"
      apiDataKey="Results"
      actions={actions}
      offCanvas={offCanvas}
      simpleColumns={simpleColumns}
      queryKey="ListEdiscoveryCases"
      tableFilter={setupBanner}
      cardButton={
        <>
          <Add /> Create Case
        </>
      }
      titleButton={{
        label: "Create Case",
        icon: <Add />,
        dialog: {
          title: "Create eDiscovery Case",
          fields: [
            {
              name: "displayName",
              label: "Case Name",
              type: "textField",
              required: true,
            },
            {
              name: "description",
              label: "Description",
              type: "textField",
              multiline: true,
              rows: 3,
            },
            {
              name: "externalId",
              label: "External ID (optional)",
              type: "textField",
            },
            ...guardedWriteFields,
          ],
          api: {
            url: "/api/ExecEdiscoveryCase",
            type: "POST",
            data: { action: "create" },
            relatedQueryKeys: ["ListEdiscoveryCases"],
          },
        },
      }}
    />
  );
};

Page.getLayout = (page) => <DashboardLayout>{page}</DashboardLayout>;

export default Page;
