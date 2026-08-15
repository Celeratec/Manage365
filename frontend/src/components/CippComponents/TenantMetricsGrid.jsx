import { Box, Grid, Tooltip, Avatar, Typography, Skeleton } from "@mui/material";
import { useRouter } from "next/router";
import {
  Person as UserIcon,
  PersonOutline as GuestIcon,
  Group as GroupIcon,
  Apps as AppsIcon,
  Devices as DevicesIcon,
  PhoneAndroid as ManagedIcon,
} from "@mui/icons-material";

const formatNumber = (num) => {
  if (num >= 1000000) return (num / 1000000).toFixed(1) + "M";
  if (num >= 1000) return (num / 1000).toFixed(1) + "K";
  return num?.toString() || "0";
};

export const TenantMetricsGrid = ({ data, isLoading }) => {
  const router = useRouter();

  const metrics = [
    {
      label: "Users",
      value: data?.UserCount || 0,
      icon: UserIcon,
      color: "primary",
      path: "/identity/administration/users",
    },
    {
      label: "Guests",
      value: data?.GuestCount || 0,
      icon: GuestIcon,
      color: "info",
      path: "/identity/administration/users",
    },
    {
      label: "Groups",
      value: data?.GroupCount || 0,
      icon: GroupIcon,
      color: "secondary",
      path: "/identity/administration/groups",
    },
    {
      label: "Service Principals",
      value: data?.ApplicationCount || 0,
      icon: AppsIcon,
      color: "error",
      path: "/tenant/administration/applications/enterprise-apps",
    },
    {
      label: "Devices",
      value: data?.DeviceCount || 0,
      icon: DevicesIcon,
      color: "warning",
      path: "/identity/administration/devices",
    },
    {
      label: "Managed",
      value: data?.ManagedDeviceCount || 0,
      icon: ManagedIcon,
      color: "success",
      path: "/identity/administration/devices",
    },
  ];

  const handleClick = (metric) => {
    if (metric.path) {
      router.push(metric.path);
    }
  };

  return (
    <Grid container spacing={1}>
      {metrics.map((metric) => {
        const IconComponent = metric.icon;
        return (
          <Grid key={metric.label} size={{ xs: 6 }}>
            <Tooltip
              title={`View ${metric.value.toLocaleString()} ${metric.label.toLowerCase()}`}
              arrow
            >
              <Box
                onClick={() => handleClick(metric)}
                sx={{
                  display: "flex",
                  alignItems: "center",
                  gap: 1,
                  p: 1.25,
                  border: 1,
                  borderColor: "divider",
                  borderRadius: 1,
                  cursor: "pointer",
                  transition: "all 0.2s ease-in-out",
                  "&:hover": {
                    borderColor: `${metric.color}.main`,
                    backgroundColor: "action.hover",
                    transform: "translateY(-2px)",
                    boxShadow: "0 4px 8px rgba(0,0,0,0.1)",
                  },
                }}
              >
                <Avatar
                  sx={{
                    bgcolor: `${metric.color}.main`,
                    color: `${metric.color}.contrastText`,
                    width: 28,
                    height: 28,
                  }}
                >
                  <IconComponent sx={{ fontSize: 18, color: "inherit" }} />
                </Avatar>
                <Box sx={{ minWidth: 0 }}>
                  <Typography variant="caption" color="text.secondary" fontSize="0.65rem" noWrap>
                    {metric.label}
                  </Typography>
                  <Typography variant="subtitle1" fontWeight={600} fontSize="0.95rem" lineHeight={1.2}>
                    {isLoading ? <Skeleton width={40} /> : formatNumber(metric.value)}
                  </Typography>
                </Box>
              </Box>
            </Tooltip>
          </Grid>
        );
      })}
    </Grid>
  );
};
