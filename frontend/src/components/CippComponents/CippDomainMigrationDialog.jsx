import { useState, useMemo, useCallback, useEffect } from "react";
import {
  Alert,
  Box,
  Button,
  Checkbox,
  Chip,
  CircularProgress,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Divider,
  FormControlLabel,
  Stack,
  Switch,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Typography,
  useMediaQuery,
} from "@mui/material";
import { SwapHoriz } from "@mui/icons-material";
import { ApiGetCall, ApiPostCall } from "../../api/ApiCall";
import { CippApiResults } from "./CippApiResults";
import { useSettings } from "../../hooks/use-settings";
import CippFormComponent from "./CippFormComponent";
import { useForm, useWatch } from "react-hook-form";

export const CippDomainMigrationDialog = ({ open, onClose, targetDomain }) => {
  const [sourceDomain, setSourceDomain] = useState(null);
  const [selectedUserIds, setSelectedUserIds] = useState(new Set());
  const [selectedGroupIds, setSelectedGroupIds] = useState(new Set());
  const [includeGroups, setIncludeGroups] = useState(false);
  const fullScreen = useMediaQuery((theme) => theme.breakpoints.down("md"));
  const userSettings = useSettings();
  const tenantFilter = userSettings.currentTenant;
  const formControl = useForm({ mode: "onChange" });

  const watchedSourceDomain = useWatch({
    control: formControl.control,
    name: "sourceDomain",
  });

  useEffect(() => {
    const newValue = watchedSourceDomain?.value || null;
    if (newValue !== sourceDomain) {
      setSourceDomain(newValue);
      setSelectedUserIds(new Set());
      setSelectedGroupIds(new Set());
    }
  }, [watchedSourceDomain]);

  const domainListQuery = ApiGetCall({
    url: "/api/ListGraphRequest",
    data: {
      Endpoint: "domains",
      tenantFilter: tenantFilter,
    },
    queryKey: `DomainMigration-Domains-${tenantFilter}`,
    waiting: open,
  });

  const userListQuery = ApiGetCall({
    url: "/api/ListGraphRequest",
    data: {
      Endpoint: "users",
      tenantFilter: tenantFilter,
      $count: true,
      $select: "id,displayName,userPrincipalName,mail,accountEnabled,proxyAddresses",
      $filter: `endsWith(userPrincipalName,'@${sourceDomain}') or endsWith(mail,'@${sourceDomain}')`,
    },
    queryKey: `DomainMigration-Users-${tenantFilter}-${sourceDomain}`,
    waiting: !!sourceDomain,
  });

  const groupListQuery = ApiGetCall({
    url: "/api/ListGraphRequest",
    data: {
      Endpoint: "groups",
      tenantFilter: tenantFilter,
      $count: true,
      $select: "id,displayName,mail,groupTypes,mailEnabled,securityEnabled",
      $filter: `endsWith(mail,'@${sourceDomain}')`,
    },
    queryKey: `DomainMigration-Groups-${tenantFilter}-${sourceDomain}`,
    waiting: !!sourceDomain && includeGroups,
  });

  const migrationRequest = ApiPostCall({
    urlFromData: true,
    relatedQueryKeys: ["ListUsers*"],
  });

  const availableDomains = useMemo(() => {
    if (!domainListQuery.data?.Results) return [];
    return domainListQuery.data.Results.filter(
      (d) => d.isVerified && d.id !== targetDomain
    ).map((d) => ({ label: d.id, value: d.id }));
  }, [domainListQuery.data, targetDomain]);

  const users = useMemo(() => {
    if (!userListQuery.data?.Results) return [];
    return userListQuery.data.Results.filter(
      (u) =>
        u.userPrincipalName &&
        !u.userPrincipalName.includes("#EXT#") &&
        (u.userPrincipalName.endsWith(`@${sourceDomain}`) ||
          u.mail?.endsWith(`@${sourceDomain}`))
    );
  }, [userListQuery.data, sourceDomain]);

  const groups = useMemo(() => {
    if (!groupListQuery.data?.Results) return [];
    return groupListQuery.data.Results.filter((g) => g.mail);
  }, [groupListQuery.data]);

  const getGroupType = useCallback((group) => {
    if (group.groupTypes?.includes("Unified")) return "Microsoft 365 Group";
    if (group.mailEnabled && group.securityEnabled) return "Mail-Enabled Security";
    if (group.mailEnabled) return "Distribution List";
    return "Security Group";
  }, []);

  const handleClose = () => {
    setSourceDomain(null);
    setSelectedUserIds(new Set());
    setSelectedGroupIds(new Set());
    setIncludeGroups(false);
    formControl.reset();
    migrationRequest.reset();
    onClose();
  };

  const toggleUser = (id) => {
    setSelectedUserIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  const toggleAllUsers = () => {
    if (selectedUserIds.size === users.length) {
      setSelectedUserIds(new Set());
    } else {
      setSelectedUserIds(new Set(users.map((u) => u.id)));
    }
  };

  const toggleGroup = (id) => {
    setSelectedGroupIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  const toggleAllGroups = () => {
    if (selectedGroupIds.size === groups.length) {
      setSelectedGroupIds(new Set());
    } else {
      setSelectedGroupIds(new Set(groups.map((g) => g.id)));
    }
  };

  const handleSubmit = () => {
    const selectedUsers = users
      .filter((u) => selectedUserIds.has(u.id))
      .map((u) => ({
        id: u.id,
        userPrincipalName: u.userPrincipalName,
        mail: u.mail,
        displayName: u.displayName,
      }));

    const selectedGroups = includeGroups
      ? groups
          .filter((g) => selectedGroupIds.has(g.id))
          .map((g) => ({
            id: g.id,
            mail: g.mail,
            displayName: g.displayName,
            groupType: getGroupType(g),
          }))
      : [];

    migrationRequest.mutate({
      url: "/api/ExecDomainMigration",
      data: {
        tenantFilter,
        sourceDomain,
        targetDomain,
        users: selectedUsers,
        groups: selectedGroups,
      },
    });
  };

  const totalSelected =
    selectedUserIds.size + (includeGroups ? selectedGroupIds.size : 0);

  return (
    <Dialog
      open={open}
      onClose={handleClose}
      fullScreen={fullScreen}
      maxWidth="lg"
      fullWidth
    >
      <DialogTitle>
        <Stack direction="row" alignItems="center" spacing={1}>
          <SwapHoriz />
          <Typography variant="h6">Migrate to {targetDomain}</Typography>
        </Stack>
      </DialogTitle>
      <DialogContent>
        <Stack spacing={3} sx={{ mt: 1 }}>
          <Alert severity="info">
            This will change the primary email and sign-in for selected users/groups to @
            {targetDomain}. Existing email addresses will be kept as aliases to preserve mail
            delivery.
          </Alert>

          <CippFormComponent
            type="autoComplete"
            name="sourceDomain"
            label="Source Domain (migrate FROM)"
            formControl={formControl}
            multiple={false}
            creatable={false}
            options={availableDomains}
            isFetching={domainListQuery.isFetching}
          />

          {sourceDomain && (
            <>
              <Divider />
              <Stack direction="row" alignItems="center" spacing={1}>
                <Typography variant="subtitle1" fontWeight={600}>
                  Users on @{sourceDomain}
                </Typography>
                {userListQuery.isFetching && <CircularProgress size={18} />}
              </Stack>

              {users.length > 0 ? (
                <TableContainer sx={{ maxHeight: 350 }}>
                  <Table size="small" stickyHeader>
                    <TableHead>
                      <TableRow>
                        <TableCell padding="checkbox">
                          <Checkbox
                            indeterminate={
                              selectedUserIds.size > 0 &&
                              selectedUserIds.size < users.length
                            }
                            checked={selectedUserIds.size === users.length}
                            onChange={toggleAllUsers}
                          />
                        </TableCell>
                        <TableCell>Display Name</TableCell>
                        <TableCell>Current UPN</TableCell>
                        <TableCell>Primary Email</TableCell>
                        <TableCell>Status</TableCell>
                      </TableRow>
                    </TableHead>
                    <TableBody>
                      {users.map((user) => (
                        <TableRow
                          key={user.id}
                          hover
                          onClick={() => toggleUser(user.id)}
                          sx={{ cursor: "pointer" }}
                        >
                          <TableCell padding="checkbox">
                            <Checkbox checked={selectedUserIds.has(user.id)} />
                          </TableCell>
                          <TableCell>{user.displayName}</TableCell>
                          <TableCell>{user.userPrincipalName}</TableCell>
                          <TableCell>{user.mail}</TableCell>
                          <TableCell>
                            <Chip
                              label={user.accountEnabled ? "Active" : "Disabled"}
                              color={user.accountEnabled ? "success" : "default"}
                              size="small"
                            />
                          </TableCell>
                        </TableRow>
                      ))}
                    </TableBody>
                  </Table>
                </TableContainer>
              ) : (
                !userListQuery.isFetching && (
                  <Alert severity="warning">No users found on @{sourceDomain}</Alert>
                )
              )}

              <Divider />
              <FormControlLabel
                control={
                  <Switch
                    checked={includeGroups}
                    onChange={(e) => {
                      setIncludeGroups(e.target.checked);
                      setSelectedGroupIds(new Set());
                    }}
                  />
                }
                label="Include groups (M365 Groups, Distribution Lists)"
              />

              {includeGroups && (
                <>
                  <Stack direction="row" alignItems="center" spacing={1}>
                    <Typography variant="subtitle1" fontWeight={600}>
                      Groups on @{sourceDomain}
                    </Typography>
                    {groupListQuery.isFetching && <CircularProgress size={18} />}
                  </Stack>

                  {groups.length > 0 ? (
                    <TableContainer sx={{ maxHeight: 300 }}>
                      <Table size="small" stickyHeader>
                        <TableHead>
                          <TableRow>
                            <TableCell padding="checkbox">
                              <Checkbox
                                indeterminate={
                                  selectedGroupIds.size > 0 &&
                                  selectedGroupIds.size < groups.length
                                }
                                checked={selectedGroupIds.size === groups.length}
                                onChange={toggleAllGroups}
                              />
                            </TableCell>
                            <TableCell>Group Name</TableCell>
                            <TableCell>Current Email</TableCell>
                            <TableCell>Type</TableCell>
                          </TableRow>
                        </TableHead>
                        <TableBody>
                          {groups.map((group) => (
                            <TableRow
                              key={group.id}
                              hover
                              onClick={() => toggleGroup(group.id)}
                              sx={{ cursor: "pointer" }}
                            >
                              <TableCell padding="checkbox">
                                <Checkbox checked={selectedGroupIds.has(group.id)} />
                              </TableCell>
                              <TableCell>{group.displayName}</TableCell>
                              <TableCell>{group.mail}</TableCell>
                              <TableCell>
                                <Chip label={getGroupType(group)} size="small" variant="outlined" />
                              </TableCell>
                            </TableRow>
                          ))}
                        </TableBody>
                      </Table>
                    </TableContainer>
                  ) : (
                    !groupListQuery.isFetching && (
                      <Alert severity="warning">
                        No mail-enabled groups found on @{sourceDomain}
                      </Alert>
                    )
                  )}
                </>
              )}

              {totalSelected > 0 && (
                <Alert severity="success">
                  {selectedUserIds.size} user{selectedUserIds.size !== 1 ? "s" : ""}
                  {includeGroups && selectedGroupIds.size > 0
                    ? ` and ${selectedGroupIds.size} group${selectedGroupIds.size !== 1 ? "s" : ""}`
                    : ""}{" "}
                  will be migrated from @{sourceDomain} to @{targetDomain}
                </Alert>
              )}

              <CippApiResults apiObject={migrationRequest} />
            </>
          )}
        </Stack>
      </DialogContent>
      <DialogActions>
        {migrationRequest.isSuccess ? (
          <Button variant="contained" onClick={handleClose}>
            OK
          </Button>
        ) : (
          <>
            <Button onClick={handleClose}>Cancel</Button>
            <Button
              variant="contained"
              onClick={handleSubmit}
              disabled={totalSelected === 0 || migrationRequest.isPending}
            >
              {migrationRequest.isPending
                ? "Migrating..."
                : `Migrate ${totalSelected} item${totalSelected !== 1 ? "s" : ""}`}
            </Button>
          </>
        )}
      </DialogActions>
    </Dialog>
  );
};
