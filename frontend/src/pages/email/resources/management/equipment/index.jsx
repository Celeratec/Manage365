import { Layout as DashboardLayout } from "../../../../../layouts/index";
import { CippIcons } from "../../../../../utils/icon-registry"
import { CippTablePage } from "../../../../../components/CippComponents/CippTablePage.jsx";
import { CippAddEquipmentDrawer } from "../../../../../components/CippComponents/CippAddEquipmentDrawer";

const Page = () => {
  const pageTitle = "Equipment";
  const cardButtonPermissions = ["Exchange.Equipment.ReadWrite"];

  const actions = [
    {
      label: "Edit Equipment",
      link: `/email/resources/management/equipment/edit?equipmentId=[ExternalDirectoryObjectId]`,
      pinned: true,
      icon: <CippIcons.Edit />,
      color: "info",
      condition: (row) => !row.isDirSynced,
      category: "edit",
    },
    {
      label: "Edit permissions",
      link: "/identity/administration/users/user/exchange?userId=[ExternalDirectoryObjectId]",
      color: "info",
      icon: <CippIcons.Key />,
      category: "edit",
    },
    {
      label: "Block Sign In",
      type: "POST",
      icon: <CippIcons.Block />,
      url: "/api/ExecDisableUser",
      data: { ID: "ExternalDirectoryObjectId" },
      confirmText: "Are you sure you want to block the sign-in for this equipment mailbox?",
      multiPost: false,
      condition: (row) => !row.isDirSynced,
      category: "security",
    },
    {
      label: "Unblock Sign In",
      type: "POST",
      icon: <CippIcons.LockOpen />,
      url: "/api/ExecDisableUser",
      data: { ID: "ExternalDirectoryObjectId", Enable: true },
      confirmText: "Are you sure you want to unblock sign-in for this equipment mailbox?",
      multiPost: false,
      condition: (row) => !row.isDirSynced,
      category: "security",
    },
    {
      label: "Delete Equipment",
      type: "POST",
      icon: <CippIcons.Delete />,
      url: "/api/RemoveUser",
      data: { ID: "ExternalDirectoryObjectId" },
      confirmText: "Are you sure you want to delete this equipment mailbox?",
      multiPost: false,
      condition: (row) => !row.isDirSynced,
      category: "danger",
    },
  ];

  const simpleColumns = [
    "DisplayName",
    "UserPrincipalName",
    "HiddenFromAddressListsEnabled",
    "PrimarySmtpAddress",
  ];

  return (
    <CippTablePage
      title={pageTitle}
      apiUrl="/api/ListEquipment"
      actions={actions}
      simpleColumns={simpleColumns}
      cardButton={<CippAddEquipmentDrawer requiredPermissions={cardButtonPermissions} />}
    />
  );
};

Page.getLayout = (page) => <DashboardLayout allTenantsSupport={false}>{page}</DashboardLayout>;

export default Page;
