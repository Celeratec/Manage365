import { useState } from "react";
import { Layout as DashboardLayout } from "../../../../layouts/index.js";
import { CippTablePage } from "../../../../components/CippComponents/CippTablePage.jsx";
import { Alert, AlertTitle, Collapse, IconButton, Link } from "@mui/material";
import {
  Add,
  OpenInNew,
  Lock,
  LockOpen,
  Delete,
  Close,
} from "@mui/icons-material";

const Page = () => {
  const pageTitle = "eDiscovery Cases";
  const [setupBannerOpen, setSetupBannerOpen] = useState(true);

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
      confirmText: "Are you sure you want to reopen this case?",
      condition: (row) => row.status === "closed",
      category: "edit",
    },
    {
      label: "Delete Case",
      type: "POST",
      icon: <Delete />,
      url: "/api/ExecEdiscoveryCase",
      data: {
        caseId: "id",
        action: "!delete",
      },
      confirmText:
        "Are you sure you want to delete this case? This action cannot be undone. The case must be closed first.",
      condition: (row) => row.status === "closed",
      category: "danger",
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
        Before using eDiscovery, each client tenant needs a one-time setup: the Manage365 service
        principal must be assigned the <strong>eDiscovery Administrator</strong> role in the
        tenant&apos;s Purview portal. Go to{" "}
        <Link
          href="https://compliance.microsoft.com/compliancecentersettings/securityandcompliancecenterrolesv2"
          target="_blank"
          rel="noopener noreferrer"
        >
          Purview &gt; Settings &gt; Roles &amp; Scopes &gt; Permissions
        </Link>
        , find the <strong>eDiscovery Manager</strong> role group, and add the Manage365 app as an{" "}
        <strong>eDiscovery Administrator</strong>. You also need to run a{" "}
        <strong>CPV Refresh</strong> from Manage365 Settings to push the eDiscovery permissions to the
        tenant.
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
