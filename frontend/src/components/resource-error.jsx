import PropTypes from "prop-types";
import ArrowPathIcon from "@heroicons/react/24/outline/ArrowPathIcon";
import ExclamationTriangleIcon from "@heroicons/react/24/outline/ExclamationTriangleIcon";
import { Button, SvgIcon, Typography, Box } from "@mui/material";
import { styled, alpha } from "@mui/material/styles";

const ResourceErrorRoot = styled("div")(({ theme }) => ({
  alignItems: "center",
  backgroundColor:
    theme.palette.mode === "dark" 
      ? alpha(theme.palette.error.main, 0.05)
      : alpha(theme.palette.error.main, 0.02),
  border: `1px solid ${alpha(theme.palette.error.main, 0.1)}`,
  borderRadius: theme.shape.borderRadius,
  display: "flex",
  flexDirection: "column",
  justifyContent: "center",
  padding: theme.spacing(3),
  maxWidth: "100%",
  overflow: "hidden",
}));

export const ResourceError = (props) => {
  const { message = "Something went wrong, please try again.", onReload, sx } = props;

  return (
    <ResourceErrorRoot sx={sx}>
      <Box
        sx={{
          width: 48,
          height: 48,
          borderRadius: "50%",
          bgcolor: (theme) => alpha(theme.palette.error.main, 0.1),
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
        }}
      >
        <SvgIcon fontSize="medium" color="error">
          <ExclamationTriangleIcon />
        </SvgIcon>
      </Box>
      <Typography 
        color="text.secondary" 
        sx={{ 
          mt: 2,
          textAlign: "center",
          wordBreak: "break-word",
          overflowWrap: "break-word",
          maxWidth: "100%",
          px: 1,
        }} 
        variant="body2"
      >
        {message}
      </Typography>
      {onReload && (
        <Button
          onClick={onReload}
          startIcon={
            <SvgIcon fontSize="small">
              <ArrowPathIcon />
            </SvgIcon>
          }
          sx={{ mt: 2 }}
          variant="outlined"
          size="small"
        >
          Reload Data
        </Button>
      )}
    </ResourceErrorRoot>
  );
};

ResourceError.propTypes = {
  message: PropTypes.string,
  onReload: PropTypes.func,
  sx: PropTypes.object,
};
