import { Layout as DashboardLayout } from "../../../../layouts/index.js";
import { CippTablePage } from "../../../../components/CippComponents/CippTablePage.jsx";
import { Alert } from "@mui/material";
import { useSettings } from "../../../../hooks/use-settings";
import { useCippReportDB } from "../../../../components/CippComponents/CippReportDBControls";

const Page = () => {
  const currentTenant = useSettings().currentTenant;

  const reportDB = useCippReportDB({
    apiUrl: "/api/ListMailboxForwarding",
    queryKey: "mailbox-forwarding",
    cacheName: "Mailboxes",
    syncTitle: "Sync Mailbox Cache",
    allowToggle: false,
    defaultCached: true,
  });

  const columns = [
    ...reportDB.cacheColumns.filter((c) => c === "Tenant"),
    "UPN",
    "DisplayName",
    "RecipientTypeDetails",
    "ForwardingType",
    "ForwardTo",
    "DeliverToMailboxAndForward",
    ...reportDB.cacheColumns.filter((c) => c !== "Tenant"),
  ];

  const filters = [
    {
      filterName: "External Forwarding",
      value: [{ id: "ForwardingType", value: "External" }],
      type: "column",
    },
    {
      filterName: "Internal Forwarding",
      value: [{ id: "ForwardingType", value: "Internal" }],
      type: "column",
    },
  ];

  return (
    <>
      {currentTenant && currentTenant !== "" ? (
        <CippTablePage
          title="Mailbox Forwarding Report"
          apiUrl={reportDB.resolvedApiUrl}
          queryKey={reportDB.resolvedQueryKey}
          apiData={reportDB.resolvedApiData}
          simpleColumns={columns}
          filters={filters}
          dataSourceControls={reportDB.controls}
          offCanvas={null}
        />
      ) : (
        <Alert severity="warning">Please select a tenant to view mailbox forwarding settings.</Alert>
      )}
      {reportDB.syncDialog}
    </>
  );
};

Page.getLayout = (page) => <DashboardLayout>{page}</DashboardLayout>;

export default Page;
