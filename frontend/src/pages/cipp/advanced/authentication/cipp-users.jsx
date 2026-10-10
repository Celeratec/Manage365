import { TabbedLayout } from "../../../../layouts/TabbedLayout";
import { Layout as DashboardLayout } from "../../../../layouts/index";
import tabOptions from "./tabOptions";
import CippPageCard from "../../../../components/CippCards/CippPageCard";
import { CippUserManagement } from "../../../../components/CippSettings/CippUserManagement";
import { CippExpandableAlert } from "../../../../components/CippComponents/CippExpandableAlert";
import { CardContent, Stack } from "@mui/material";

const Page = () => {
  return (
    // Titled to match the tab label, so the mobile picker claims the heading and the page
    // does not say "Manage365 Users" and "Manage365 User Management" back to back.
    <CippPageCard hideBackButton={true} title={"Manage365 Users"}>
      <CardContent>
        <Stack spacing={2}>
          <CippExpandableAlert severity="info">
            Manage users who can access Manage365. Users are automatically synced from your partner
            tenant every 15 minutes based on Entra group memberships configured on the Manage365 Roles
            page. You can also manually add users or assign additional roles — manual assignments
            are preserved independently and will not be overwritten by the sync. Users assigned the
            superadmin role have full access to Manage365 and all other permissions applied will be ignored.
            You must have at least one superadmin user in Manage365 at all times, and you cannot remove the
            superadmin role from a user if they are the only superadmin. If you have only one superadmin
            and need to change who it is, first assign another user the superadmin role, then you can
            remove the superadmin role from the original user. To allow users from outside your partner tenant
            to access Manage365, you can add them as guest users in your partner tenant and assign them the
            appropriate roles in Manage365 or enable the multi tenant mode in the Manage365 SSO tab and add the users
            to the list below without needing to add them as guest users in your tenant.
          </CippExpandableAlert>
          <CippUserManagement />
        </Stack>
      </CardContent>
    </CippPageCard>
  );
};

Page.getLayout = (page) => (
  <DashboardLayout>
    <TabbedLayout tabOptions={tabOptions}>{page}</TabbedLayout>
  </DashboardLayout>
);

export default Page;
