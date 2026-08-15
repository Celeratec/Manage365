import { common } from '@mui/material/colors';
import { alpha } from '@mui/material/styles';
import { error, info, neutral, success, warning } from '../colors';
import { getPrimary } from '../utils';

export const createPalette = (config) => {
  const { colorPreset, contrast } = config;

  // Material Design dark theme guidelines
  // https://m2.material.io/design/color/dark-theme.html#properties
  return {
    action: {
      active: alpha(common.white, 0.56),
      disabled: alpha(common.white, 0.38),
      disabledBackground: alpha(common.white, 0.12),
      focus: alpha(common.white, 0.12),
      hover: alpha(common.white, 0.08),
      selected: alpha(common.white, 0.16)
    },
    background: {
      // Material Design recommends #121212 as base dark surface
      default: contrast === 'high' ? '#121212' : '#181818',
      // Elevated surfaces get lighter (overlay white at ~5-8%)
      paper: '#1E1E1E'
    },
    divider: alpha(common.white, 0.12),
    error,
    info,
    mode: 'dark',
    neutral,
    primary: getPrimary(colorPreset),
    success,
    text: {
      // Material Design: High emphasis 87%, Medium 60%, Disabled 38%
      primary: alpha(common.white, 0.87),
      secondary: alpha(common.white, 0.60),
      disabled: alpha(common.white, 0.38)
    },
    warning
  };
};
