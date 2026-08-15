import { Layout as DashboardLayout } from "../../../../layouts/index.js";
import { CippTablePage } from "../../../../components/CippComponents/CippTablePage.jsx";
import {
  Box,
  Chip,
  Typography,
  Tooltip,
  Avatar,
  AvatarGroup,
  Stack,
  Card,
  CardContent,
  CardHeader,
  Divider,
  IconButton,
  List,
  ListItem,
  ListItemAvatar,
  ListItemText,
  ListItemSecondaryAction,
  Alert,
  Button,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogContentText,
  DialogActions,
  CircularProgress,
} from "@mui/material";
import { alpha, useTheme } from "@mui/material/styles";
import {
  AdminPanelSettings,
  Person,
  Group,
  Security,
  RemoveCircle,
  CheckCircle,
  Info,
  VerifiedUser,
  Shield,
  PersonAdd,
} from "@mui/icons-material";
import {
  ShieldCheckIcon,
  UserGroupIcon,
  UserIcon,
  TrashIcon,
  ExclamationTriangleIcon,
} from "@heroicons/react/24/outline";
import { useState, useMemo, useCallback } from "react";
import { ApiPostCall } from "../../../../api/ApiCall";
import { useQueryClient } from "@tanstack/react-query";
import { useSettings } from "../../../../hooks/use-settings";
import { useForm, useWatch } from "react-hook-form";
import CippFormComponent from "../../../../components/CippComponents/CippFormComponent";
import { CippApiResults } from "../../../../components/CippComponents/CippApiResults";

const AddMemberForm = ({ role, tenant, onClose, onSuccess, mutation }) => {
  const formControl = useForm({ mode: "onChange" });
  const assignmentType = useWatch({
    control: formControl.control,
    name: "assignmentType",
  });
  const assignmentTypeValue = assignmentType?.value || assignmentType;
  const isTemporary = assignmentTypeValue === "Temporary";

  const handleSubmit = formControl.handleSubmit((formData) => {
    const actionType = isTemporary ? "AddTemporary" : "Add";
    const user = formData.user;
    mutation.mutate(
      {
        url: "/api/ExecRoleAssignment",
        data: {
          tenantFilter: tenant,
          userId: user.value,
          userPrincipalName: user.addedFields?.userPrincipalName || user.value,
          displayName: user.label,
          roles: [{ label: role.DisplayName, value: role.roleTemplateId }],
          action: actionType,
          expiration: formData.expiration
            ? Math.floor(new Date(formData.expiration).getTime() / 1000)
            : undefined,
          reason: formData.reason || undefined,
        },
      },
      {
        onSuccess: () => {
          onSuccess();
        },
      }
    );
  });

  return (
    <form onSubmit={handleSubmit}>
      <Stack spacing={2} sx={{ mt: 1 }}>
        <CippFormComponent
          type="autoComplete"
          name="user"
          label="Select User"
          multiple={false}
          creatable={false}
          formControl={formControl}
          validators={{ required: "Please select a user" }}
          api={{
            url: "/api/ListGraphRequest",
            data: {
              Endpoint: "users",
              $select: "id,displayName,userPrincipalName",
              $top: 999,
              $count: true,
            },
            queryKey: `ListUsersAutoComplete-${tenant}`,
            dataKey: "Results",
            labelField: (user) => `${user.displayName} (${user.userPrincipalName})`,
            valueField: "id",
            addedField: {
              userPrincipalName: "userPrincipalName",
              displayName: "displayName",
            },
          }}
        />
        <CippFormComponent
          type="radio"
          name="assignmentType"
          label="Assignment Type"
          formControl={formControl}
          options={[
            { label: "Permanent", value: "Permanent" },
            { label: "Temporary", value: "Temporary" },
          ]}
          validators={{ required: "Please select an assignment type" }}
        />
        {isTemporary && (
          <CippFormComponent
            type="datePicker"
            name="expiration"
            label="Expiration Date/Time"
            dateTimeType="datetime"
            formControl={formControl}
            validators={{ required: "Please select an expiration date" }}
          />
        )}
        <CippFormComponent
          type="textField"
          name="reason"
          label="Reason (optional)"
          formControl={formControl}
        />
        <CippApiResults apiObject={mutation} />
        <DialogActions sx={{ px: 0, pb: 0 }}>
          <Button onClick={onClose} disabled={mutation.isPending}>
            Cancel
          </Button>
          <Button
            type="submit"
            variant="contained"
            disabled={mutation.isPending}
            startIcon={
              mutation.isPending ? (
                <CircularProgress size={16} color="inherit" />
              ) : (
                <PersonAdd />
              )
            }
          >
            {mutation.isPending ? "Adding..." : "Add Member"}
          </Button>
        </DialogActions>
      </Stack>
    </form>
  );
};

const Page = () => {
  const pageTitle = "Roles";
  const theme = useTheme();
  const queryClient = useQueryClient();
  const tenant = useSettings().currentTenant;

  // State for member removal dialog
  const [removeDialog, setRemoveDialog] = useState({
    open: false,
    member: null,
    role: null,
  });
  const [addMemberDialog, setAddMemberDialog] = useState({
    open: false,
    role: null,
  });
  const [isRemoving, setIsRemoving] = useState(false);
  const [removeError, setRemoveError] = useState(null);

  // API mutation for removing members
  const removeMemberMutation = ApiPostCall({
    urlFromData: true,
    relatedQueryKeys: ["ListRoles"],
  });

  const addMemberMutation = ApiPostCall({
    urlFromData: true,
    relatedQueryKeys: ["ListRoles"],
  });

  // Handle member removal
  const handleRemoveMember = async () => {
    const { member, role } = removeDialog;
    setIsRemoving(true);
    setRemoveError(null);

    try {
      await removeMemberMutation.mutateAsync({
        url: "/api/ExecRemoveRoleMember",
        data: {
          TenantFilter: tenant,
          RoleId: role.Id,
          MemberId: member.id,
          RoleName: role.DisplayName,
          MemberName: member.displayName,
        },
      });

      queryClient.invalidateQueries({ queryKey: ["ListRoles"] });
      setRemoveDialog({ open: false, member: null, role: null });
    } catch (err) {
      console.error("Failed to remove member:", err);
      setRemoveError(err.message || "Failed to remove member from role");
    } finally {
      setIsRemoving(false);
    }
  };

  // Get initials from name
  const getInitials = (name) => {
    if (!name) return "?";
    const parts = name.trim().split(/\s+/);
    if (parts.length === 1) return parts[0].charAt(0).toUpperCase();
    return (parts[0].charAt(0) + parts[parts.length - 1].charAt(0)).toUpperCase();
  };

  // Custom columns with better formatting
  const columns = useMemo(
    () => [
      {
        header: "Role",
        id: "DisplayName",
        accessorKey: "DisplayName",
        size: 280,
        sortingFn: (a, b) => {
          // Sort roles with members to the top
          const aMemberCount = a.original.Members?.length || 0;
          const bMemberCount = b.original.Members?.length || 0;

          if (aMemberCount > 0 && bMemberCount === 0) return -1;
          if (aMemberCount === 0 && bMemberCount > 0) return 1;

          // Then sort alphabetically
          return (a.original.DisplayName || "").localeCompare(b.original.DisplayName || "");
        },
        Cell: ({ row }) => {
          const hasMembers = row.original.Members?.length > 0;
          return (
            <Stack direction="row" spacing={1.5} alignItems="center">
              <Avatar
                sx={{
                  width: 32,
                  height: 32,
                  bgcolor: hasMembers ? "primary.main" : "action.disabledBackground",
                  color: hasMembers ? "primary.contrastText" : "text.disabled",
                }}
              >
                <ShieldCheckIcon style={{ width: 18, height: 18 }} />
              </Avatar>
              <Box sx={{ minWidth: 0 }}>
                <Typography
                  variant="body2"
                  fontWeight={hasMembers ? 600 : 400}
                  color={hasMembers ? "text.primary" : "text.secondary"}
                  noWrap
                >
                  {row.original.DisplayName}
                </Typography>
                {hasMembers && (
                  <Chip
                    label="In Use"
                    size="small"
                    color="success"
                    variant="outlined"
                    sx={{ height: 18, fontSize: "0.65rem", mt: 0.25 }}
                  />
                )}
              </Box>
            </Stack>
          );
        },
      },
      {
        header: "Members",
        id: "memberCount",
        // Use accessorFn to return member count for proper sorting
        accessorFn: (row) => row.Members?.length || 0,
        size: 200,
        enableSorting: true,
        sortingFn: "basic",
        Cell: ({ row }) => {
          const members = row.original.Members || [];
          const memberCount = members.length;

          if (memberCount === 0) {
            return (
              <Typography variant="body2" color="text.disabled" fontStyle="italic">
                No members
              </Typography>
            );
          }

          return (
            <Stack direction="row" spacing={1} alignItems="center">
              <AvatarGroup
                max={3}
                sx={{
                  "& .MuiAvatar-root": {
                    width: 28,
                    height: 28,
                    fontSize: "0.75rem",
                    border: `2px solid ${theme.palette.background.paper}`,
                  },
                }}
              >
                {members.slice(0, 3).map((member, idx) => (
                  <Tooltip key={idx} title={member.displayName || member.userPrincipalName} arrow>
                    <Avatar sx={{ bgcolor: "primary.main" }}>{getInitials(member.displayName)}</Avatar>
                  </Tooltip>
                ))}
              </AvatarGroup>
              <Chip
                label={`${memberCount} member${memberCount !== 1 ? "s" : ""}`}
                size="small"
                color={memberCount > 0 ? "primary" : "default"}
                variant={memberCount > 0 ? "filled" : "outlined"}
                icon={<UserGroupIcon style={{ width: 14, height: 14 }} />}
                sx={{ height: 24 }}
              />
            </Stack>
          );
        },
      },
      {
        header: "Description",
        id: "Description",
        accessorKey: "Description",
        size: 200,
        maxSize: 300,
        enableGlobalFilter: true,
        Cell: ({ row }) => {
          const description = row.original.Description || "";

          return (
            <Tooltip title={description} arrow enterDelay={300}>
              <Typography
                variant="body2"
                color="text.secondary"
                noWrap
                sx={{
                  maxWidth: 280,
                  overflow: "hidden",
                  textOverflow: "ellipsis",
                }}
              >
                {description || "No description"}
              </Typography>
            </Tooltip>
          );
        },
      },
    ],
    [theme]
  );

  // Off-canvas children renderer for detailed member list
  const offCanvasChildren = useCallback(
    (row) => {
      const members = row.Members || [];
      const hasMembers = members.length > 0;

      return (
        <Stack spacing={2}>
          {/* Role Header */}
          <Card
            variant="outlined"
            sx={{
              bgcolor: hasMembers
                ? alpha(theme.palette.primary.main, 0.05)
                : alpha(theme.palette.grey[500], 0.05),
              borderColor: hasMembers ? "primary.main" : "divider",
              borderWidth: hasMembers ? 2 : 1,
            }}
          >
            <CardContent sx={{ py: 2 }}>
              <Stack direction="row" spacing={2} alignItems="center">
                <Avatar
                  sx={{
                    width: 48,
                    height: 48,
                    bgcolor: hasMembers ? "primary.main" : "grey.400",
                  }}
                >
                  <Shield sx={{ fontSize: 28 }} />
                </Avatar>
                <Box sx={{ flex: 1 }}>
                  <Typography variant="h6" fontWeight={600}>
                    {row.DisplayName}
                  </Typography>
                  <Stack direction="row" spacing={1} alignItems="center" sx={{ mt: 0.5 }}>
                    <Chip
                      label={hasMembers ? `${members.length} Members` : "No Members"}
                      size="small"
                      color={hasMembers ? "success" : "default"}
                      variant={hasMembers ? "filled" : "outlined"}
                      icon={<UserGroupIcon style={{ width: 14, height: 14 }} />}
                    />
                    {hasMembers && (
                      <Chip
                        label="Active"
                        size="small"
                        color="primary"
                        variant="outlined"
                        icon={<CheckCircle sx={{ fontSize: 14 }} />}
                      />
                    )}
                  </Stack>
                </Box>
              </Stack>
            </CardContent>
          </Card>

          {/* Description */}
          <Card variant="outlined">
            <CardHeader
              title={
                <Stack direction="row" spacing={1} alignItems="center">
                  <Info sx={{ fontSize: 18, color: "text.secondary" }} />
                  <Typography variant="subtitle2">Description</Typography>
                </Stack>
              }
              sx={{ py: 1.5, px: 2 }}
            />
            <Divider />
            <CardContent sx={{ py: 1.5 }}>
              <Typography variant="body2" color="text.secondary">
                {row.Description || "No description available for this role."}
              </Typography>
            </CardContent>
          </Card>

          {/* Members List */}
          <Card variant="outlined">
            <CardHeader
              title={
                <Stack direction="row" spacing={1} alignItems="center">
                  <UserGroupIcon style={{ width: 18, height: 18 }} />
                  <Typography variant="subtitle2">
                    Members ({members.length})
                  </Typography>
                </Stack>
              }
              action={
                <Button
                  size="small"
                  variant="contained"
                  startIcon={<PersonAdd />}
                  onClick={() => setAddMemberDialog({ open: true, role: row })}
                >
                  Add Member
                </Button>
              }
              sx={{ py: 1.5, px: 2 }}
            />
            <Divider />
            {members.length === 0 ? (
              <CardContent>
                <Alert severity="info" icon={<UserGroupIcon style={{ width: 20, height: 20 }} />}>
                  <Typography variant="body2">
                    This role has no members assigned. Users can be added to this role through Entra ID
                    or by assigning the role to a user.
                  </Typography>
                </Alert>
              </CardContent>
            ) : (
              <List dense sx={{ py: 0 }}>
                {members.map((member, index) => (
                  <ListItem
                    key={member.id || index}
                    divider={index < members.length - 1}
                    sx={{
                      py: 1.5,
                      "&:hover": {
                        bgcolor: alpha(theme.palette.error.main, 0.04),
                      },
                    }}
                  >
                    <ListItemAvatar>
                      <Avatar
                        sx={{
                          width: 36,
                          height: 36,
                          bgcolor: "primary.main",
                          fontSize: "0.875rem",
                        }}
                      >
                        {getInitials(member.displayName)}
                      </Avatar>
                    </ListItemAvatar>
                    <ListItemText
                      primary={
                        <Typography variant="body2" fontWeight={500}>
                          {member.displayName || "Unknown User"}
                        </Typography>
                      }
                      secondary={
                        <Typography variant="caption" color="text.secondary">
                          {member.userPrincipalName || "No UPN available"}
                        </Typography>
                      }
                    />
                    <ListItemSecondaryAction>
                      <Tooltip title="Remove from role" arrow>
                        <IconButton
                          edge="end"
                          size="small"
                          color="error"
                          onClick={() =>
                            setRemoveDialog({
                              open: true,
                              member: member,
                              role: row,
                            })
                          }
                          sx={{
                            opacity: 0.6,
                            "&:hover": {
                              opacity: 1,
                              bgcolor: alpha(theme.palette.error.main, 0.1),
                            },
                          }}
                        >
                          <TrashIcon style={{ width: 18, height: 18 }} />
                        </IconButton>
                      </Tooltip>
                    </ListItemSecondaryAction>
                  </ListItem>
                ))}
              </List>
            )}
          </Card>

          {/* Role Info */}
          <Card variant="outlined">
            <CardHeader
              title={
                <Stack direction="row" spacing={1} alignItems="center">
                  <Security sx={{ fontSize: 18, color: "text.secondary" }} />
                  <Typography variant="subtitle2">Role Information</Typography>
                </Stack>
              }
              sx={{ py: 1.5, px: 2 }}
            />
            <Divider />
            <CardContent sx={{ py: 1.5 }}>
              <Stack spacing={1}>
                <Stack direction="row" justifyContent="space-between">
                  <Typography variant="body2" color="text.secondary">
                    Role ID
                  </Typography>
                  <Typography
                    variant="caption"
                    sx={{
                      fontFamily: "monospace",
                      bgcolor: alpha(theme.palette.text.primary, 0.05),
                      px: 1,
                      py: 0.25,
                      borderRadius: 0.5,
                    }}
                  >
                    {row.Id}
                  </Typography>
                </Stack>
                {row.roleTemplateId && (
                  <Stack direction="row" justifyContent="space-between">
                    <Typography variant="body2" color="text.secondary">
                      Template ID
                    </Typography>
                    <Typography
                      variant="caption"
                      sx={{
                        fontFamily: "monospace",
                        bgcolor: alpha(theme.palette.text.primary, 0.05),
                        px: 1,
                        py: 0.25,
                        borderRadius: 0.5,
                      }}
                    >
                      {row.roleTemplateId}
                    </Typography>
                  </Stack>
                )}
              </Stack>
            </CardContent>
          </Card>
        </Stack>
      );
    },
    [theme]
  );

  // Off-canvas configuration - extendedInfoFields required to enable flyout trigger
  const offCanvas = useMemo(
    () => ({
      extendedInfoFields: [], // Empty array - we use children for custom content
      title: "Role Details",
      size: "md",
      children: offCanvasChildren,
    }),
    [offCanvasChildren]
  );

  // Default sorting - roles with members first (by member count descending)
  const defaultSorting = useMemo(
    () => [
      {
        id: "memberCount",
        desc: true,
      },
    ],
    []
  );

  return (
    <>
      <CippTablePage
        title={pageTitle}
        apiUrl="/api/ListRoles"
        columns={columns}
        columnsFromApi={false}
        offCanvas={offCanvas}
        queryKey="ListRoles"
        defaultSorting={defaultSorting}
      />

      {/* Remove Member Dialog */}
      <Dialog
        open={removeDialog.open}
        onClose={() => !isRemoving && setRemoveDialog({ open: false, member: null, role: null })}
        maxWidth="sm"
        fullWidth
      >
        <DialogTitle sx={{ display: "flex", alignItems: "center", gap: 1 }}>
          <ExclamationTriangleIcon style={{ width: 24, height: 24, color: theme.palette.warning.main }} />
          Remove Member from Role
        </DialogTitle>
        <DialogContent>
          <DialogContentText component="div">
            <Typography variant="body1" gutterBottom>
              Are you sure you want to remove{" "}
              <strong>{removeDialog.member?.displayName}</strong> from the{" "}
              <strong>{removeDialog.role?.DisplayName}</strong> role?
            </Typography>
            <Alert severity="warning" sx={{ mt: 2 }}>
              This action will remove the user's permissions associated with this role. The user will
              lose access to any resources or capabilities granted by this role assignment.
            </Alert>
            {removeError && (
              <Alert severity="error" sx={{ mt: 2 }}>
                {removeError}
              </Alert>
            )}
          </DialogContentText>
        </DialogContent>
        <DialogActions sx={{ px: 3, pb: 2 }}>
          <Button
            onClick={() => setRemoveDialog({ open: false, member: null, role: null })}
            disabled={isRemoving}
          >
            Cancel
          </Button>
          <Button
            onClick={handleRemoveMember}
            color="error"
            variant="contained"
            disabled={isRemoving}
            startIcon={isRemoving ? <CircularProgress size={16} color="inherit" /> : <RemoveCircle />}
          >
            {isRemoving ? "Removing..." : "Remove Member"}
          </Button>
        </DialogActions>
      </Dialog>

      {/* Add Member Dialog */}
      <Dialog
        open={addMemberDialog.open}
        onClose={() => !addMemberMutation.isPending && setAddMemberDialog({ open: false, role: null })}
        maxWidth="sm"
        fullWidth
      >
        <DialogTitle sx={{ display: "flex", alignItems: "center", gap: 1 }}>
          <PersonAdd sx={{ color: theme.palette.primary.main }} />
          Add Member to {addMemberDialog.role?.DisplayName}
        </DialogTitle>
        <DialogContent>
          {addMemberDialog.open && (
            <AddMemberForm
              role={addMemberDialog.role}
              tenant={tenant}
              onClose={() => setAddMemberDialog({ open: false, role: null })}
              onSuccess={() => {
                queryClient.invalidateQueries({ queryKey: ["ListRoles"] });
                setAddMemberDialog({ open: false, role: null });
              }}
              mutation={addMemberMutation}
            />
          )}
        </DialogContent>
      </Dialog>
    </>
  );
};

Page.getLayout = (page) => <DashboardLayout allTenantsSupport={false}>{page}</DashboardLayout>;

export default Page;
