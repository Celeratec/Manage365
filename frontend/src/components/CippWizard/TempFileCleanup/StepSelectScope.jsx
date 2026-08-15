import {
  Stack,
  Typography,
  RadioGroup,
  FormControlLabel,
  Radio,
  Button,
  Box,
  Alert,
} from "@mui/material";
import { CippAutoComplete } from "../../CippComponents/CippAutocomplete";

export const StepSelectScope = ({ data, onUpdate, onNext }) => {
  const handleScopeChange = (event) => {
    onUpdate({ scope: event.target.value, siteId: null, userId: null });
  };

  const canProceed =
    data.tenant &&
    ((data.scope === "site" && data.siteId) ||
      (data.scope === "user" && data.userId) ||
      data.scope === "allSites" ||
      data.scope === "allOneDrives");

  return (
    <Stack spacing={3}>
      <Typography variant="h6">
        Let&apos;s find those temp files! First, choose where to look.
      </Typography>

      <CippAutoComplete
        api={{
          url: "/api/ListTenants",
          excludeTenantFilter: true,
          queryKey: "ListTenants-TempFileCleanup",
          labelField: (tenant) =>
            `${tenant.displayName} (${tenant.defaultDomainName})`,
          valueField: "defaultDomainName",
          addedField: {
            displayName: "displayName",
            customerId: "customerId",
          },
        }}
        label="Select Tenant"
        value={data.tenant}
        onChange={(value) => onUpdate({ tenant: value, siteId: null, userId: null })}
        multiple={false}
        disableClearable
        required
      />

      {data.tenant && (
        <>
          <Typography variant="subtitle1">Scope</Typography>
          <RadioGroup value={data.scope || "site"} onChange={handleScopeChange}>
            <FormControlLabel
              value="site"
              control={<Radio />}
              label="Specific SharePoint site"
            />
            <FormControlLabel
              value="user"
              control={<Radio />}
              label="Specific user's OneDrive"
            />
            <FormControlLabel
              value="allSites"
              control={<Radio />}
              label="All SharePoint sites"
            />
            <FormControlLabel
              value="allOneDrives"
              control={<Radio />}
              label="All OneDrives"
            />
          </RadioGroup>

          {data.scope === "site" && (
            <CippAutoComplete
              key={`site-${data.tenant?.value}`}
              api={{
                url: "/api/ListSites",
                tenantFilter: data.tenant?.value,
                data: { Type: "SharePointSiteUsage" },
                queryKey: `ListSites-${data.tenant?.value}`,
                labelField: (site) =>
                  site.displayName || site.webUrl || site.siteId,
                valueField: "siteId",
                addedField: {
                  webUrl: "webUrl",
                  displayName: "displayName",
                },
              }}
              label="Select SharePoint Site"
              value={data.siteId}
              onChange={(value) => onUpdate({ siteId: value })}
              multiple={false}
              creatable={false}
            />
          )}

          {data.scope === "user" && (
            <CippAutoComplete
              key={`user-${data.tenant?.value}`}
              api={{
                url: "/api/ListGraphRequest",
                tenantFilter: data.tenant?.value,
                data: {
                  Endpoint: "users",
                  $filter: "accountEnabled eq true",
                  $top: 999,
                  $count: true,
                  $orderby: "displayName",
                  $select: "id,displayName,userPrincipalName",
                },
                dataKey: "Results",
                queryKey: `ListUsers-${data.tenant?.value}`,
                labelField: (user) =>
                  `${user.displayName} (${user.userPrincipalName})`,
                valueField: "id",
                addedField: {
                  displayName: "displayName",
                  userPrincipalName: "userPrincipalName",
                },
              }}
              label="Select User"
              value={data.userId}
              onChange={(value) => onUpdate({ userId: value })}
              multiple={false}
              creatable={false}
            />
          )}

          {(data.scope === "allSites" || data.scope === "allOneDrives") && (
            <Alert severity="warning">
              Scanning all {data.scope === "allSites" ? "sites" : "OneDrives"}{" "}
              may take several minutes for large tenants.
            </Alert>
          )}
        </>
      )}

      <Box sx={{ display: "flex", justifyContent: "flex-end", mt: 2 }}>
        <Button variant="contained" onClick={onNext} disabled={!canProceed}>
          Next
        </Button>
      </Box>
    </Stack>
  );
};

export default StepSelectScope;
