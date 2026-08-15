import {
  Alert,
  AlertTitle,
  Box,
  Button,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Stack,
  Typography,
  useTheme,
} from "@mui/material";
import { alpha } from "@mui/material/styles";
import { WarningAmber } from "@mui/icons-material";

/**
 * Confirmation dialog that displays all active risk warnings before saving.
 * Groups risks by severity (error first, then warning, then info).
 * If no risks are provided, this component does not render.
 *
 * @param {boolean} open
 * @param {function} onClose - Called when user cancels
 * @param {function} onConfirm - Called when user confirms save despite risks
 * @param {Array<{severity: string, title: string, description: string}>} risks
 */
const CippRiskSummaryDialog = ({ open, onClose, onConfirm, risks = [] }) => {
  const theme = useTheme();
  const hasHighRisk = risks.some((r) => r.severity === "error");

  const severityOrder = { error: 0, warning: 1, info: 2 };
  const sortedRisks = [...risks].sort(
    (a, b) => (severityOrder[a.severity] ?? 3) - (severityOrder[b.severity] ?? 3)
  );

  const highCount = risks.filter((r) => r.severity === "error").length;
  const mediumCount = risks.filter((r) => r.severity === "warning").length;

  return (
    <Dialog
      open={open}
      onClose={onClose}
      maxWidth="sm"
      fullWidth
      PaperProps={{
        sx: hasHighRisk
          ? {
              border: `2px solid ${theme.palette.error.main}`,
              boxShadow: `0 0 24px ${alpha(theme.palette.error.main, 0.25)}`,
            }
          : {
              border: `2px solid ${theme.palette.warning.main}`,
              boxShadow: `0 0 24px ${alpha(theme.palette.warning.main, 0.25)}`,
            },
      }}
    >
      <DialogTitle
        sx={{
          display: "flex",
          alignItems: "center",
          gap: 1,
          bgcolor: hasHighRisk
            ? alpha(theme.palette.error.main, 0.08)
            : alpha(theme.palette.warning.main, 0.08),
          color: hasHighRisk ? "error.main" : "warning.main",
        }}
      >
        <WarningAmber />
        Review Risk Warnings Before Saving
      </DialogTitle>
      <DialogContent sx={{ pt: 2, pb: 1 }}>
        <Typography variant="body2" sx={{ mb: 2, mt: 1 }}>
          The current configuration includes{" "}
          {highCount > 0 && (
            <strong>
              {highCount} high-risk {highCount === 1 ? "setting" : "settings"}
            </strong>
          )}
          {highCount > 0 && mediumCount > 0 && " and "}
          {mediumCount > 0 && (
            <strong>
              {mediumCount} moderate-risk {mediumCount === 1 ? "setting" : "settings"}
            </strong>
          )}
          {highCount === 0 && mediumCount === 0 && <strong>settings that may need review</strong>}.
          Please review the following before proceeding:
        </Typography>
        <Stack spacing={1.5}>
          {sortedRisks.map((risk, idx) => (
            <Alert key={idx} severity={risk.severity} variant="outlined">
              <AlertTitle sx={{ fontSize: "0.85rem" }}>{risk.title}</AlertTitle>
              <Typography variant="body2">{risk.description}</Typography>
            </Alert>
          ))}
        </Stack>
      </DialogContent>
      <DialogActions sx={{ px: 3, pb: 2, pt: 1 }}>
        <Button onClick={onClose} variant="outlined">
          Go Back
        </Button>
        <Button
          onClick={onConfirm}
          variant="contained"
          color={hasHighRisk ? "error" : "warning"}
        >
          Save Anyway
        </Button>
      </DialogActions>
    </Dialog>
  );
};

export default CippRiskSummaryDialog;
