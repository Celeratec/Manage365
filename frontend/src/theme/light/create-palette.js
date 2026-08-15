import { common } from '@mui/material/colors';
import { alpha } from '@mui/material/styles';
import { error, info, neutral, success, warning } from '../colors';
import { getPrimary } from '../utils';

export const createPalette = (config) => {
  const { colorPreset, contrast } = config;

  // Material Design light theme guidelines
  // https://m2.material.io/design/color/dark-theme.html#properties
  return {
    action: {
      active: alpha(common.black, 0.54),
      disabled: alpha(common.black, 0.26),
      disabledBackground: alpha(common.black, 0.12),
      focus: alpha(common.black, 0.12),
      hover: alpha(common.black, 0.04),
      selected: alpha(common.black, 0.08)
    },
    background: {
      // Material Design light theme surfaces
      default: contrast === 'high' ? '#F5F5F5' : '#FAFAFA',
      paper: '#FFFFFF'
    },
    divider: alpha(common.black, 0.12),
    error,
    info,
    mode: 'light',
    neutral,
    primary: getPrimary(colorPreset),
    success,
    text: {
      // Material Design: High emphasis 87%, Medium 60%, Disabled 38%
      primary: alpha(common.black, 0.87),
      secondary: alpha(common.black, 0.60),
      disabled: alpha(common.black, 0.38)
    },
    warning
  };
};
