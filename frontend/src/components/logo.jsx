import PropTypes from "prop-types";
import { Box } from "@mui/material";
import { useTheme } from "@mui/material/styles";

const badgeMagenta = "#D10078";

const logoSrc = {
  light: "/logo-light.png",
  dark: "/logo-dark.png",
};

export const Logo = (props) => {
  const { height = 40, mode } = props;
  const theme = useTheme();
  const resolvedMode = mode === "light" || mode === "dark" ? mode : theme.palette.mode;
  const resolvedHeight = typeof height === "number" ? `${height}px` : height;
  const badgeSize =
    typeof height === "number"
      ? Math.max(9, Math.round(height * 0.2))
      : { xs: 9, md: 12 };

  return (
    <Box
      component="span"
      sx={{
        display: "inline-flex",
        alignItems: "center",
        gap: 0.75,
        height: resolvedHeight,
      }}
    >
      <Box
        component="img"
        src={logoSrc[resolvedMode]}
        alt="Manage365"
        sx={{ display: "block", height: "100%", width: "auto" }}
      />
      <Box
        component="span"
        sx={{
          px: 0.4,
          borderRadius: "3px",
          bgcolor: badgeMagenta,
          color: "#fff",
          fontSize: badgeSize,
          fontWeight: 700,
          letterSpacing: "0.04em",
          lineHeight: 1.3,
          textDecoration: "none",
          flexShrink: 0,
        }}
      >
        V2
      </Box>
    </Box>
  );
};

Logo.propTypes = {
  color: PropTypes.oneOf(["black", "primary", "white"]),
  height: PropTypes.oneOfType([PropTypes.number, PropTypes.string, PropTypes.object]),
  mode: PropTypes.oneOf(["light", "dark"]),
};
