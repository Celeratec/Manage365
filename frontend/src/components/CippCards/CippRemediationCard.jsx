import { Button, Typography, List, ListItem, SvgIcon, Stack, Box } from "@mui/material";
import CippButtonCard from "./CippButtonCard"; // Adjust the import path as needed
import { CippApiDialog } from "../CippComponents/CippApiDialog";
import { useDialog } from "../../hooks/use-dialog";
import { Sync, Key } from "@mui/icons-material";
import { ShieldCheckIcon } from "@heroicons/react/24/outline";

export default function CippRemediationCard(props) {
  const { userPrincipalName, isFetching, userId, tenantFilter, restartProcess } = props;
  const createDialog = useDialog();
  const expirePasswordDialog = useDialog();
  return (
    <CippButtonCard
      title={
        <Typography variant="h6">
          Business Email Compromise Overview - {userPrincipalName}
        </Typography>
      }
      CardButton={
        <Box>
          {/* Desktop: Two rows of buttons */}
          <Stack 
            spacing={1} 
            sx={{ 
              display: { xs: 'none', md: 'flex' } 
            }}
          >
            {/* Row 1: Primary action */}
            <Button
              variant="contained"
              color="primary"
              fullWidth
              onClick={() => createDialog.handleOpen()}
              startIcon={
                <SvgIcon fontSize="small">
                  <ShieldCheckIcon />
                </SvgIcon>
              }
            >
              Remediate User
            </Button>
            {/* Row 2: Secondary actions */}
            <Stack direction="row" spacing={1}>
              <Button
                variant="outlined"
                color="warning"
                fullWidth
                size="small"
                onClick={() => expirePasswordDialog.handleOpen()}
                startIcon={
                  <SvgIcon fontSize="small">
                    <Key />
                  </SvgIcon>
                }
              >
                Expire Password
              </Button>
              <Button
                variant="outlined"
                fullWidth
                size="small"
                onClick={() => restartProcess()}
                disabled={isFetching}
                startIcon={
                  <SvgIcon fontSize="small">
                    <Sync />
                  </SvgIcon>
                }
              >
                Refresh Data
              </Button>
            </Stack>
          </Stack>

          {/* Mobile: Stack all buttons vertically */}
          <Stack 
            direction="row" 
            spacing={1} 
            flexWrap="wrap" 
            useFlexGap
            sx={{ 
              display: { xs: 'flex', md: 'none' } 
            }}
          >
            <Button
              variant="contained"
              color="primary"
              onClick={() => createDialog.handleOpen()}
              startIcon={
                <SvgIcon fontSize="small">
                  <ShieldCheckIcon />
                </SvgIcon>
              }
            >
              Remediate User
            </Button>
            <Button
              variant="outlined"
              color="warning"
              onClick={() => expirePasswordDialog.handleOpen()}
              startIcon={
                <SvgIcon fontSize="small">
                  <Key />
                </SvgIcon>
              }
            >
              Expire Password
            </Button>
            <Button
              variant="outlined"
              size="small"
              onClick={() => restartProcess()}
              disabled={isFetching}
              startIcon={
                <SvgIcon fontSize="small">
                  <Sync />
                </SvgIcon>
              }
            >
              Refresh
            </Button>
          </Stack>
        </Box>
      }
      isFetching={isFetching}
    >
      <Typography>
        Use this information as a guide to check if a tenant or e-mail address might have been
        compromised. All data is retrieved from the last 7 days of logs.
      </Typography>

      <Typography color="text.secondary">
        Hit the button below to execute the following tasks:
      </Typography>
      <List>
        <ListItem>Block user sign-in</ListItem>
        <ListItem>Reset user password</ListItem>
        <ListItem>Disconnect all current sessions</ListItem>
        <ListItem>Remove all MFA methods for the user</ListItem>
        <ListItem>Disable all inbox rules for the user</ListItem>
      </List>
      <CippApiDialog
        title="Remediate User"
        createDialog={createDialog}
        api={{
          url: "/api/execBecRemediate",
          confirmText:
            "This will remediate this user, blocking their signin, resetting their password, disconnecting their sessions, and disabling all their inbox rules. Are you sure you want to continue?",
          type: "POST",
          data: { tenantFilter: tenantFilter, userId: "userId", username: "userPrincipalName" },
          replacementBehaviour: "removeNulls",
        }}
        row={props}
      />
      <CippApiDialog
        title="Expire Password"
        createDialog={expirePasswordDialog}
        api={{
          url: "/api/ExecExpirePassword",
          confirmText:
            "This will mark the user's password as expired. The user will be required to change their password on their next sign-in. Their current password remains valid until they log in. Use 'Revoke all user sessions' to force immediate re-authentication.",
          type: "POST",
          data: { 
            tenantFilter: tenantFilter, 
            ID: "userPrincipalName",
            displayName: "userPrincipalName",
          },
          replacementBehaviour: "removeNulls",
        }}
        row={props}
      />
    </CippButtonCard>
  );
}
