import { Container } from "@mui/material";
import { Grid } from "@mui/system";
import { TabbedLayout } from "../../../layouts/TabbedLayout";
import { Layout as DashboardLayout } from "../../../layouts/index.js";
import tabOptions from "./tabOptions";
import CippPermissionCheck from "../../../components/CippSettings/CippPermissionCheck";
import { CippPermissionReport } from "../../../components/CippSettings/CippPermissionReport";
import { useState } from "react";

const Page = () => {
  const [importReport, setImportReport] = useState(false);

  return (
    <Container sx={{ pt: { xs: 0, md: 3 }, px: { xs: 1.5, md: 3 } }} maxWidth="xl">
      <Grid container spacing={2}>
        {/* Below lg the report renders as a fixed FAB (plus a portaled dialog), so this item
            is empty in flow — display: contents dissolves it, or grid spacing leaves a blank
            16px row between the picker and the first card. */}
        <Grid size={{ xs: 12 }} sx={{ display: { xs: "contents", lg: "block" } }}>
          <CippPermissionReport importReport={importReport} setImportReport={setImportReport} />
        </Grid>
        <Grid size={{ lg: 6, md: 12, sm: 12, xs: 12 }}>
          <CippPermissionCheck type="Permissions" importReport={importReport} />
        </Grid>
        <Grid size={{ lg: 6, md: 12, sm: 12, xs: 12 }}>
          <CippPermissionCheck type="GDAP" importReport={importReport} />
        </Grid>
        <Grid size={{ lg: 12, md: 12, sm: 12, xs: 12 }}>
          <CippPermissionCheck type="Tenants" importReport={importReport} />
        </Grid>
      </Grid>
    </Container>
  );
};

Page.getLayout = (page) => (
  <DashboardLayout>
    <TabbedLayout tabOptions={tabOptions}>{page}</TabbedLayout>
  </DashboardLayout>
);

export default Page;
