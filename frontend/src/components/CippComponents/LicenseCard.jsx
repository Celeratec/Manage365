import { Box, Card, CardHeader, CardContent, Typography, Skeleton, LinearProgress, Tooltip, Divider } from "@mui/material";
import { CardMembership as CardMembershipIcon, CheckCircle, Cancel } from "@mui/icons-material";
import { useRouter } from "next/router";

export const LicenseCard = ({ data, isLoading, compact = false }) => {
  const router = useRouter();
  const titleVariant = compact ? "subtitle1" : "h6";
  const statValueVariant = compact ? "h4" : "h3";

  const getLicenseName = (license) =>
    license?.License || license?.skuPartNumber || license?.SkuPartNumber || "Unknown License";

  const getTotalLicenses = (license) => {
    const total = license?.TotalLicenses;
    // Handle various formats: number, string, null, undefined
    if (total === null || total === undefined || total === "" || total === "0") return 0;
    const parsed = parseInt(total, 10);
    return isNaN(parsed) ? 0 : parsed;
  };

  // Tenant-level licenses that shouldn't be counted in user assignment metrics
  const isTenantLevelLicense = (name) => {
    const nameLower = name.toLowerCase();
    return (
      nameLower.includes("entra id p2") ||
      nameLower.includes("azure ad premium p2") ||
      nameLower.includes("aad_premium_p2")
    );
  };

  // Filter out trial, free, and developer licenses - we only want paid licenses
  const isPaidLicense = (license) => {
    const termInfoArray = Array.isArray(license?.TermInfo) ? license.TermInfo : [];
    const name = getLicenseName(license);
    const nameLower = name.toLowerCase();
    
    // Check for trial licenses
    const isTrial = termInfoArray.some((term) => term?.IsTrial === true) || nameLower.includes("trial");
    
    // Check for free/developer licenses
    const isFreeOrDev = 
      nameLower.includes("free") ||
      nameLower.includes("developer") ||
      nameLower.includes("for developer") ||
      nameLower.includes("_dev") ||
      nameLower.includes("dev_") ||
      nameLower.includes("sandbox") ||
      nameLower.includes("viral") ||
      nameLower.includes("self-service");
    
    return !isTrial && !isFreeOrDev;
  };

  // Check if tenant has Entra ID P2 license
  const hasEntraP2 = (data || []).some((license) => {
    const name = getLicenseName(license);
    return isTenantLevelLicense(name) && getTotalLicenses(license) > 0;
  });

  // Get all paid licenses sorted by total count (excluding tenant-level licenses)
  const paidLicenses = (data || [])
    .filter((license) => {
      if (!license) return false;
      const total = getTotalLicenses(license);
      // Only include licenses with at least 1 total license
      if (total < 1) return false;
      if (!isPaidLicense(license)) return false;
      if (isTenantLevelLicense(getLicenseName(license))) return false;
      return true;
    })
    .sort((a, b) => getTotalLicenses(b) - getTotalLicenses(a))
    .map((license) => {
      const name = getLicenseName(license);
      const total = getTotalLicenses(license);
      const assigned = parseInt(license?.CountUsed || 0) || 0;
      const available = parseInt(license?.CountAvailable || 0) || 0;
      const percentage = total > 0 ? Math.round((assigned / total) * 100) : 0;
      return { name, total, assigned, available, percentage };
    });

  const filteredStats = paidLicenses.reduce(
    (acc, lic) => ({
      total: acc.total + lic.total,
      assigned: acc.assigned + lic.assigned,
      available: acc.available + lic.available,
    }),
    { total: 0, assigned: 0, available: 0 }
  );

  const overallPercentage = filteredStats.total > 0 
    ? Math.round((filteredStats.assigned / filteredStats.total) * 100) 
    : 0;

  // Color for utilization percentage based on efficiency
  const getUtilizationColor = (percentage) => {
    if (percentage >= 90) return "hsl(140, 50%, 45%)"; // Green - excellent utilization
    if (percentage >= 75) return "hsl(45, 80%, 45%)"; // Yellow - moderate utilization
    return "hsl(0, 55%, 50%)"; // Red - poor utilization (over-provisioned)
  };

  // Pastel blue for assigned licenses, more visible red for available (over-provisioned)
  const barColor = "hsl(210, 55%, 72%)";
  const barBackgroundColor = "hsl(0, 55%, 72%)";

  return (
    <Card sx={{ flex: 1, height: "100%", display: "flex", flexDirection: "column" }}>
      <CardHeader
        title={
          <Box
            onClick={() => router.push("/tenant/reports/list-licenses")}
            sx={{
              display: "flex",
              alignItems: "center",
              gap: 1,
              cursor: "pointer",
              width: "fit-content",
              "&:hover": { textDecoration: "underline" },
            }}
          >
            <CardMembershipIcon sx={{ fontSize: compact ? 20 : 24 }} />
            <Typography variant={titleVariant}>License Overview</Typography>
          </Box>
        }
        sx={{ pb: compact ? 0.5 : 1, flexShrink: 0 }}
      />
      <CardContent sx={{ pb: compact ? 1.5 : 2, pt: compact ? 1 : 2, flex: 1, display: "flex", flexDirection: "column", overflow: "hidden" }}>
        {isLoading ? (
          <Box sx={{ display: "flex", gap: 3, flex: 1 }}>
            <Box sx={{ width: "30%" }}>
              <Skeleton variant="rectangular" height={100} />
            </Box>
            <Box sx={{ flex: 1 }}>
              <Skeleton height={20} sx={{ mb: 1 }} />
              <Skeleton height={20} sx={{ mb: 1 }} />
              <Skeleton height={20} sx={{ mb: 1 }} />
              <Skeleton height={20} sx={{ mb: 1 }} />
              <Skeleton height={20} />
            </Box>
          </Box>
        ) : data && Array.isArray(data) && data.length > 0 && paidLicenses.length > 0 ? (
          <Box sx={{ display: "flex", gap: compact ? 2 : 3, flex: 1, minHeight: 0 }}>
            {/* Left side - Stats summary */}
            <Box sx={{ 
              width: compact ? "30%" : "32%", 
              display: "flex", 
              flexDirection: "column", 
              justifyContent: "center",
              pr: 2,
              borderRight: 1,
              borderColor: "divider",
              flexShrink: 0
            }}>
              {/* Overall Usage Gauge */}
              <Box sx={{ textAlign: "center", mb: 1.5 }}>
                <Typography variant={statValueVariant} fontWeight="bold" sx={{ lineHeight: 1, color: getUtilizationColor(overallPercentage) }}>
                  {overallPercentage}%
                </Typography>
                <Typography variant="caption" color="text.secondary">
                  Utilization
                </Typography>
              </Box>

              <Divider sx={{ my: 1 }} />
              
              {/* License Stats */}
              <Box sx={{ mb: 1.5 }}>
                <Box sx={{ display: "flex", justifyContent: "space-between", alignItems: "center", mb: 0.75 }}>
                  <Typography variant="caption" color="text.secondary">Total</Typography>
                  <Typography variant="body2" fontWeight="bold">
                    {filteredStats.total.toLocaleString()}
                  </Typography>
                </Box>
                <Box sx={{ display: "flex", justifyContent: "space-between", alignItems: "center", mb: 0.75 }}>
                  <Typography variant="caption" color="text.secondary">Assigned</Typography>
                  <Typography variant="body2" fontWeight="bold" sx={{ color: "hsl(210, 55%, 50%)" }}>
                    {filteredStats.assigned.toLocaleString()}
                  </Typography>
                </Box>
                <Box sx={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                  <Typography variant="caption" color="text.secondary">Unassigned</Typography>
                  <Typography variant="body2" fontWeight="bold" sx={{ color: "hsl(0, 50%, 60%)" }}>
                    {filteredStats.available.toLocaleString()}
                  </Typography>
                </Box>
                {filteredStats.available > 0 && (
                  <Tooltip title="Consider reducing licenses in tenant to reduce cost for client" arrow>
                    <Typography 
                      variant="caption" 
                      sx={{ 
                        mt: 0.5, 
                        display: "block",
                        color: "hsl(30, 80%, 45%)",
                        fontStyle: "italic",
                        fontSize: "0.65rem",
                        lineHeight: 1.2,
                        cursor: "help"
                      }}
                    >
                      Consider reducing licenses
                    </Typography>
                  </Tooltip>
                )}
              </Box>

              <Divider sx={{ my: 1 }} />

              {/* Entra ID P2 Status */}
              <Tooltip 
                title={hasEntraP2 
                  ? "Microsoft Entra ID P2 is enabled for this tenant" 
                  : "Microsoft Entra ID P2 is not detected in this tenant"
                }
                arrow
              >
                <Box sx={{ 
                  display: "flex", 
                  alignItems: "center", 
                  justifyContent: "center",
                  gap: 0.75,
                  py: 0.5,
                  px: 1,
                  borderRadius: 1,
                  backgroundColor: hasEntraP2 ? "hsl(140, 40%, 95%)" : "hsl(0, 40%, 95%)",
                }}>
                  {hasEntraP2 ? (
                    <CheckCircle sx={{ fontSize: 16, color: "hsl(140, 50%, 45%)" }} />
                  ) : (
                    <Cancel sx={{ fontSize: 16, color: "hsl(0, 50%, 55%)" }} />
                  )}
                  <Typography variant="caption" sx={{ 
                    fontWeight: 500,
                    color: hasEntraP2 ? "hsl(140, 50%, 35%)" : "hsl(0, 50%, 45%)",
                  }}>
                    Entra P2
                  </Typography>
                </Box>
              </Tooltip>

              {/* License Count */}
              <Typography variant="caption" color="text.secondary" sx={{ mt: 1.5, textAlign: "center" }}>
                {paidLicenses.length} license type{paidLicenses.length !== 1 ? "s" : ""}
              </Typography>
            </Box>

            {/* Right side - Scrollable license bars */}
            <Box sx={{ 
              flex: 1, 
              display: "flex", 
              flexDirection: "column", 
              gap: compact ? 0.75 : 1,
              overflowY: "auto",
              pr: 1,
              minHeight: 0,
              "&::-webkit-scrollbar": {
                width: "6px",
              },
              "&::-webkit-scrollbar-track": {
                backgroundColor: "transparent",
              },
              "&::-webkit-scrollbar-thumb": {
                backgroundColor: "hsl(0, 0%, 80%)",
                borderRadius: "3px",
              },
              "&::-webkit-scrollbar-thumb:hover": {
                backgroundColor: "hsl(0, 0%, 70%)",
              },
            }}>
              {paidLicenses.map((license) => (
                <Tooltip 
                  key={license.name}
                  title={`${license.name}: ${license.assigned.toLocaleString()} / ${license.total.toLocaleString()} (${license.percentage}% used, ${license.available.toLocaleString()} unassigned)`}
                  arrow
                  placement="top"
                >
                  <Box
                    onClick={() =>
                      router.push({
                        pathname: "/tenant/reports/list-licenses",
                        query: { filters: JSON.stringify([{ id: "License", value: license.name }]) },
                      })
                    }
                    sx={{ flexShrink: 0, cursor: "pointer", "&:hover": { opacity: 0.8 } }}
                  >
                    <Box sx={{ display: "flex", justifyContent: "space-between", mb: 0.25 }}>
                      <Typography variant="caption" noWrap sx={{ flex: 1, mr: 1, fontSize: compact ? "0.7rem" : "0.75rem" }}>
                        {license.name}
                      </Typography>
                      <Typography variant="caption" color="text.secondary" sx={{ fontSize: compact ? "0.7rem" : "0.75rem", flexShrink: 0 }}>
                        {license.assigned}/{license.total}
                      </Typography>
                    </Box>
                    <LinearProgress
                      variant="determinate"
                      value={license.percentage}
                      sx={{
                        height: compact ? 5 : 6,
                        borderRadius: 1,
                        backgroundColor: barBackgroundColor,
                        "& .MuiLinearProgress-bar": {
                          backgroundColor: barColor,
                          borderRadius: 1,
                        },
                      }}
                    />
                  </Box>
                </Tooltip>
              ))}
            </Box>
          </Box>
        ) : (
          <Box
            sx={{
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              flex: 1,
            }}
          >
            <Typography variant="body2" color="text.secondary">
              No paid license data available
            </Typography>
          </Box>
        )}
      </CardContent>
    </Card>
  );
};
