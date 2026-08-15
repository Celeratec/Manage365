import PropTypes from "prop-types";
import PlusIcon from "@heroicons/react/24/outline/PlusIcon";
import { Box, Button, Stack, SvgIcon, Typography } from "@mui/material";
import { styled, alpha } from "@mui/material/styles";
import { useTheme } from "@emotion/react";

const ResourceUnavailableRoot = styled("div")(({ theme }) => ({
  alignItems: "center",
  backgroundColor:
    theme.palette.mode === "dark" 
      ? alpha(theme.palette.neutral[900], 0.5) 
      : alpha(theme.palette.neutral[100], 0.5),
  borderRadius: theme.shape.borderRadius,
  display: "flex",
  flexDirection: "column",
  justifyContent: "center",
  padding: theme.spacing(6, 3),
  minHeight: 200,
}));

export const ResourceUnavailable = (props) => {
  const { 
    title,
    message = "No data to display", 
    onCreate, 
    createButtonText, 
    sx, 
    type, 
    target,
    icon,
  } = props;
  const theme = useTheme();

  return (
    <ResourceUnavailableRoot sx={sx}>
      <Stack alignItems="center" spacing={2}>
        {icon ? (
          <Box
            sx={{
              color: "text.disabled",
              "& svg": { width: 48, height: 48 },
            }}
          >
            {icon}
          </Box>
        ) : (
          <Box
            sx={{
              "& img": {
                maxWidth: 120,
                opacity: 0.7,
              },
            }}
          >
            <img
              src="/assets/illustration-not-found.svg"
              style={{ filter: theme.palette.mode === "dark" ? "invert(1)" : "none" }}
              alt=""
            />
          </Box>
        )}
        <Stack alignItems="center" spacing={0.5}>
          {title && (
            <Typography variant="subtitle1" color="text.primary">
              {title}
            </Typography>
          )}
          <Typography 
            color="text.secondary" 
            variant="body2"
            sx={{ textAlign: "center", maxWidth: 320 }}
          >
            {message}
          </Typography>
        </Stack>
        {onCreate && (
          <Button
            href={type === "link" ? target : null}
            onClick={onCreate}
            startIcon={
              <SvgIcon fontSize="small">
                <PlusIcon />
              </SvgIcon>
            }
            variant="contained"
            size="small"
          >
            {createButtonText || "Create"}
          </Button>
        )}
      </Stack>
    </ResourceUnavailableRoot>
  );
};

ResourceUnavailable.propTypes = {
  title: PropTypes.string,
  message: PropTypes.string,
  onCreate: PropTypes.func,
  createButtonText: PropTypes.string,
  sx: PropTypes.object,
  type: PropTypes.string,
  target: PropTypes.string,
  icon: PropTypes.node,
};
