import { Alert, AlertTitle, Box, Button, Stack, Typography } from "@mui/material";
import { OpenInNew } from "@mui/icons-material";
import Link from "next/link";

/**
 * Renders a contextual info/warning banner with cross-links to related settings pages.
 *
 * @param {string} severity - MUI Alert severity: "info" | "warning" | "error" | "success"
 * @param {string} title - Bold title for the banner
 * @param {string} description - Explanatory text
 * @param {Array<{label: string, href: string}>} links - Navigation links to related pages
 */
const CippRelatedSettings = ({ severity = "info", title, description, links = [] }) => {
  return (
    <Alert severity={severity} variant="outlined" sx={{ mb: 0 }}>
      {title && <AlertTitle>{title}</AlertTitle>}
      <Typography variant="body2" sx={{ mb: links.length > 0 ? 1.5 : 0 }}>
        {description}
      </Typography>
      {links.length > 0 && (
        <Stack direction="row" flexWrap="wrap" gap={1}>
          {links.map((link) => (
            <Link key={link.href} href={link.href} passHref legacyBehavior>
              <Button
                component="a"
                size="small"
                variant="outlined"
                endIcon={<OpenInNew fontSize="small" />}
                sx={{ textTransform: "none" }}
              >
                {link.label}
              </Button>
            </Link>
          ))}
        </Stack>
      )}
    </Alert>
  );
};

export default CippRelatedSettings;
