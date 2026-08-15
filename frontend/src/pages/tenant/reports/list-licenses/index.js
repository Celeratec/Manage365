import { Layout as DashboardLayout } from "../../../../layouts/index.js";
import { CippTablePage } from "../../../../components/CippComponents/CippTablePage.jsx";
import { useRouter } from "next/router";
import { useMemo } from "react";

const Page = () => {
  const pageTitle = "Licences Report";
  const apiUrl = "/api/ListLicenses";
  const router = useRouter();

  // Allow deep links (e.g. from the dashboard License Overview card) to pre-filter the table
  const urlFilters = useMemo(() => {
    if (router.query.filters) {
      try {
        return JSON.parse(router.query.filters);
      } catch (e) {
        console.error("Failed to parse filters from URL:", e);
        return null;
      }
    }
    return null;
  }, [router.query.filters]);

  const simpleColumns = [
    "Tenant",
    "License",
    "CountUsed",
    "CountAvailable",
    "TotalLicenses",
    "AssignedUsers",
    "AssignedGroups",
    "TermInfo", // TODO TermInfo is not showing as a clickable json object in the table, like CApolicies does in the mfa report. IDK how to fix it. -Bobby
  ];

  return (
    <CippTablePage
      title={pageTitle}
      apiUrl={apiUrl}
      apiDataKey="Results"
      simpleColumns={simpleColumns}
      initialFilters={urlFilters}
    />
  );
};

Page.getLayout = (page) => <DashboardLayout>{page}</DashboardLayout>;

export default Page;
