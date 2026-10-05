import { Alert, AlertTitle, Collapse, Typography } from "@mui/material";

/**
 * Inline risk coaching alert that appears next to a setting control when a risky value is selected.
 * Uses MUI Collapse for smooth animated show/hide.
 *
 * @param {boolean} visible - Whether the alert is shown (controls Collapse)
 * @param {"error"|"warning"|"info"} severity - Risk level
 * @param {string} title - Short label like "High Risk" or "Not Recommended"
 * @param {string} description - What could go wrong
 * @param {string} [recommendation] - Safer alternative (rendered bold)
 */
const CippRiskAlert = ({ visible, severity = "warning", title, description, recommendation }) => {
  return (
    <Collapse in={visible} unmountOnExit>
      <Alert severity={severity} variant="outlined" sx={{ mt: 1, mb: 1 }}>
        {title && <AlertTitle>{title}</AlertTitle>}
        <Typography variant="body2">{description}</Typography>
        {recommendation && (
          <Typography variant="body2" sx={{ mt: 0.5, fontWeight: 600 }}>
            Recommendation: {recommendation}
          </Typography>
        )}
      </Alert>
    </Collapse>
  );
};

export default CippRiskAlert;
