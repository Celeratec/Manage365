import { alpha } from "@mui/material/styles";

const withAlphas = (color) => {
  return {
    ...color,
    alpha4: alpha(color.main, 0.04),
    alpha8: alpha(color.main, 0.08),
    alpha12: alpha(color.main, 0.12),
    alpha30: alpha(color.main, 0.3),
    alpha50: alpha(color.main, 0.5),
  };
};

export const neutral = {
  50: "#FAFAFA",
  100: "#F5F5F5",
  200: "#EEEEEE",
  300: "#E0E0E0",
  400: "#BDBDBD",
  500: "#9E9E9E",
  600: "#757575",
  700: "#616161",
  800: "#424242",
  900: "#212121",
};

export const chartPink = "#F472B6";

export const blue = withAlphas({
  light: "#003049",
  main: "#003049",
  dark: "#003049",
  contrastText: "#FFFFFF",
});

export const orange = withAlphas({
  light: "#F77F00",
  main: "#F77F00",
  dark: "#F77F00",
  contrastText: "#FFFFFF",
});

export const cerulean = withAlphas({
  light: "#7FC4E8",
  main: "#53A5DB",
  dark: "#2D4A5E",
  contrastText: "#FFFFFF",
});

export const indigo = withAlphas({
  light: "#EBEEFE",
  main: "#635dff",
  dark: "#4338CA",
  contrastText: "#FFFFFF",
});

export const purple = withAlphas({
  light: "#F4EBFF",
  main: "#9E77ED",
  dark: "#6941C6",
  contrastText: "#FFFFFF",
});

export const success = withAlphas({
  light: "#B8E5E8",
  main: "#6BBDC4",
  dark: "#4A9198",
  contrastText: "#1A1A1A",
});

export const info = withAlphas({
  light: "#B8E0F0",
  main: "#5BBEDB",
  dark: "#3A8FAB",
  contrastText: "#1A1A1A",
});

export const warning = withAlphas({
  light: "#D4EDDA",
  main: "#8FD19E",
  dark: "#5BA66F",
  contrastText: "#1A1A1A",
});

export const error = withAlphas({
  light: "#F5D0D0",
  main: "#E09090",
  dark: "#B86868",
  contrastText: "#1A1A1A",
});
