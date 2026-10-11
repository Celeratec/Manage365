import PropTypes from "prop-types";
import { Box } from "@mui/material";
import { useTheme } from "@mui/material/styles";
import { orange } from "../theme/colors";

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
      ? Math.max(10, Math.round(height * 0.28))
      : { xs: 11, md: 16 };

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
          px: 0.625,
          borderRadius: "4px",
          bgcolor: orange.main,
          color: orange.contrastText,
          fontSize: badgeSize,
          fontWeight: 800,
          letterSpacing: "0.06em",
          lineHeight: 1.6,
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
