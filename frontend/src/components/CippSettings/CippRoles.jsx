import React from "react";
import { Box, Button, SvgIcon, Chip, Typography } from "@mui/material";
import { Stack } from "@mui/system";
import { CippDataTable } from "../CippTable/CippDataTable";
import {
  PencilIcon,
  TrashIcon,
  DocumentDuplicateIcon,
  ShieldCheckIcon,
  KeyIcon,
  UserGroupIcon,
  BuildingOfficeIcon,
  NoSymbolIcon,
} from "@heroicons/react/24/outline";
import { PlusIcon } from "@heroicons/react/24/solid";
import NextLink from "next/link";
import { CippPropertyListCard } from "../../components/CippCards/CippPropertyListCard";
import { getCippTranslation } from "../../utils/get-cipp-translation";
import { getCippFormatting } from "../../utils/get-cipp-formatting";
import { CippCopyToClipBoard } from "../CippComponents/CippCopyToClipboard";

const CippRoles = () => {
  const actions = [
    {
      label: "Edit",
      icon: (
        <SvgIcon>
          <PencilIcon />
        </SvgIcon>
      ),
      link: "/cipp/advanced/super-admin/cipp-roles/edit?role=[RoleName]",
      color: "info",
      category: "edit",
    },
    {
      label: "Clone",
      icon: (
        <SvgIcon>
          <DocumentDuplicateIcon />
        </SvgIcon>
      ),
      type: "POST",
      url: "/api/ExecCustomRole",
      data: {
        Action: "Clone",
        RoleName: "RoleName",
      },
      fields: [
        {
          label: "New Role Name",
          name: "NewRoleName",
          type: "textField",
          required: true,
          helperText:
            "Enter a name for the new cloned role. This cannot be the same as an existing role.",
          disableVariables: true,
        },
      ],
      relatedQueryKeys: ["customRoleList", "customRoleTable"],
      confirmText: "Are you sure you want to clone this custom role?",
      condition: (row) => row?.Type === "Custom",
      color: "success",
      category: "manage",
    },
    {
      label: "Delete",
      icon: (
        <SvgIcon>
          <TrashIcon />
        </SvgIcon>
      ),
      confirmText: "Are you sure you want to delete this custom role?",
      url: "/api/ExecCustomRole",
      type: "POST",
      data: {
        Action: "Delete",
        RoleName: "RoleName",
      },
      condition: (row) => row?.Type === "Custom",
      relatedQueryKeys: ["customRoleList", "customRoleTable"],
      color: "error",
      category: "danger",
    },
  ];

  // Custom columns with better formatting
  const columns = [
    {
      header: "Role Name",
      id: "RoleName",
      accessorKey: "RoleName",
      Cell: ({ row }) => (
        <Stack direction="row" spacing={1} alignItems="center">
          <Box
            sx={{
              p: 0.5,
              borderRadius: 0.5,
              bgcolor: row.original.Type === "Custom" ? "success.main" : "primary.main",
              color: "white",
              display: "flex",
            }}
          >
            {row.original.Type === "Custom" ? (
              <KeyIcon style={{ width: 14, height: 14 }} />
            ) : (
              <ShieldCheckIcon style={{ width: 14, height: 14 }} />
            )}
          </Box>
          <Typography variant="body2" fontWeight={500}>
            {row.original.RoleName}
          </Typography>
        </Stack>
      ),
    },
    {
      header: "Type",
      id: "Type",
      accessorKey: "Type",
      Cell: ({ row }) => (
        <Chip
          label={row.original.Type}
          size="small"
          color={row.original.Type === "Custom" ? "success" : "primary"}
          variant="outlined"
        />
      ),
    },
    {
      header: "Entra Group",
      id: "EntraGroup",
      accessorKey: "EntraGroup",
      Cell: ({ row }) => {
        const group = row.original.EntraGroup;
        if (!group || group.length === 0) {
          return (
            <Typography variant="body2" color="text.secondary" fontStyle="italic">
              Not assigned
            </Typography>
          );
        }
        return (
          <Stack direction="row" spacing={0.5} alignItems="center">
            <UserGroupIcon style={{ width: 14, height: 14, opacity: 0.6 }} />
            <Typography variant="body2">{group}</Typography>
          </Stack>
        );
      },
    },
    {
      header: "Allowed Tenants",
      id: "AllowedTenants",
      accessorKey: "AllowedTenants",
      Cell: ({ row }) => {
        const tenants = row.original.AllowedTenants;
        if (!tenants || tenants.length === 0) {
          return (
            <Chip
              label="All Tenants"
              size="small"
              color="info"
              variant="outlined"
              icon={<BuildingOfficeIcon style={{ width: 12, height: 12 }} />}
            />
          );
        }
        if (Array.isArray(tenants)) {
          return (
            <Stack direction="row" spacing={0.5} flexWrap="wrap" useFlexGap>
              {tenants.slice(0, 2).map((tenant, idx) => (
                <Chip
                  key={idx}
                  label={tenant.label || tenant}
                  size="small"
                  variant="outlined"
                />
              ))}
              {tenants.length > 2 && (
                <Chip label={`+${tenants.length - 2}`} size="small" color="default" />
              )}
            </Stack>
          );
        }
        return <Typography variant="body2">{tenants}</Typography>;
      },
    },
    {
      header: "Blocked Tenants",
      id: "BlockedTenants",
      accessorKey: "BlockedTenants",
      Cell: ({ row }) => {
        const tenants = row.original.BlockedTenants;
        if (!tenants || tenants.length === 0) {
          return (
            <Typography variant="body2" color="text.secondary" fontStyle="italic">
              None
            </Typography>
          );
        }
        if (Array.isArray(tenants)) {
          return (
            <Stack direction="row" spacing={0.5} flexWrap="wrap" useFlexGap>
              {tenants.slice(0, 2).map((tenant, idx) => (
                <Chip
                  key={idx}
                  label={tenant.label || tenant}
                  size="small"
                  color="error"
                  variant="outlined"
                  icon={<NoSymbolIcon style={{ width: 12, height: 12 }} />}
                />
              ))}
              {tenants.length > 2 && (
                <Chip label={`+${tenants.length - 2}`} size="small" color="error" />
              )}
            </Stack>
          );
        }
        return <Typography variant="body2">{tenants}</Typography>;
      },
    },
  ];

  const offCanvas = {
    children: (data) => {
      const includeProps = ["RoleName", "Type", "EntraGroup", "AllowedTenants", "BlockedTenants"];
      const keys = includeProps.filter((key) => Object.keys(data).includes(key));
      const properties = [];
      keys.forEach((key) => {
        if (data[key] && data[key].length > 0) {
          properties.push({
            label: getCippTranslation(key),
            value: getCippFormatting(data[key], key),
          });
        }
      });

      if (data["Permissions"] && Object.keys(data["Permissions"]).length > 0) {
        properties.push({
          label: "Permissions",
          value: (
            <Stack spacing={0.5}>
              {Object.keys(data["Permissions"])
                .sort()
                .map((permission, idx) => (
                  <Box key={idx}>
                    <CippCopyToClipBoard type="chip" text={data["Permissions"]?.[permission]} />
                  </Box>
                ))}
            </Stack>
          ),
        });
      }

      return (
        <CippPropertyListCard
          cardSx={{ p: 0, m: -2 }}
          title="Role Details"
          propertyItems={properties}
          actionItems={actions}
          data={data}
        />
      );
    },
  };

  return (
    <CippDataTable
      actions={actions}
      title="Roles"
      cardButton={
        <Button
          variant="contained"
          size="small"
          startIcon={
            <SvgIcon fontSize="small">
              <PlusIcon />
            </SvgIcon>
          }
          component={NextLink}
          href="/cipp/advanced/super-admin/cipp-roles/add"
        >
          Add Role
        </Button>
      }
      api={{
        url: "/api/ListCustomRole",
      }}
      queryKey="customRoleTable"
      columns={columns}
      offCanvas={offCanvas}
    />
  );
};

export default CippRoles;
