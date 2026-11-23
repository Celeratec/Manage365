import { Layout as DashboardLayout } from "../../../../../layouts/index.jsx";
import { useRouter } from "next/router";
import { ApiGetCall } from "../../../../../api/ApiCall";
import CippFormSkeleton from "../../../../../components/CippFormPages/CippFormSkeleton";
import { HeaderedTabbedLayout } from "../../../../../layouts/HeaderedTabbedLayout";
import tabOptions from "./tabOptions.json";
import { Box, Stack } from "@mui/system";
import { Alert } from "@mui/material";
import { CippDataTable } from "../../../../../components/CippTable/CippDataTable";

const Page = () => {
  const router = useRouter();
  const { caseId } = router.query;

  const holdsRequest = ApiGetCall({
    url: `/api/ListEdiscoveryCaseHolds`,
    queryKey: `ListEdiscoveryCaseHolds-${caseId}`,
    data: { caseId },
    waiting: !!caseId,
  });

  const columns = [
    "displayName",
    "status",
    "contentSourcesCount",
    "contentQueryPresent",
    "createdBy",
    "createdDate",
  ];

  const title = "Legal Holds";

  return (
    <HeaderedTabbedLayout
      tabOptions={tabOptions}
      title={title}
      isFetching={holdsRequest.isLoading}
      backUrl="/security/ediscovery/cases"
    >
      <Box sx={{ flexGrow: 1, pt: 2 }}>
        <Stack spacing={2}>
          <Alert severity="info">
            Creating or updating legal holds is disabled for the first eDiscovery release.
            Existing holds can be reviewed here without exposing content queries or source details.
          </Alert>

          {holdsRequest.isLoading && <CippFormSkeleton layout={[1, 1]} />}
          {holdsRequest.isSuccess && (
            <CippDataTable
              title="Legal Holds"
              data={holdsRequest.data?.Results ?? []}
              simpleColumns={columns}
            />
          )}
          {holdsRequest.isError && (
            <Alert severity="error">
              Failed to load legal holds. Check that eDiscovery permissions are configured.
            </Alert>
          )}
        </Stack>
      </Box>
    </HeaderedTabbedLayout>
  );
};

Page.getLayout = (page) => <DashboardLayout>{page}</DashboardLayout>;

export default Page;
