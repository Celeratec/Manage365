import { Box, Card, CardHeader, CardContent, Typography, Skeleton } from "@mui/material";
import { People as UsersIcon } from "@mui/icons-material";
import { CippSankey } from "./CippSankey";
import { useRouter } from "next/router";

export const AuthMethodCard = ({ data, isLoading, compact = false }) => {
  const router = useRouter();
  const chartHeight = compact ? 220 : 300;
  const titleVariant = compact ? "subtitle1" : "h6";
  const descriptionVariant = compact ? "caption" : "body2";

  const processData = () => {
    if (!data || !Array.isArray(data) || data.length === 0) {
      return null;
    }

    const enabledUsers = data.filter((user) => user.AccountEnabled === true);
    if (enabledUsers.length === 0) {
      return null;
    }

    const phishableMethods = [
      "mobilePhone",
      "alternateMobilePhone",
      "officePhone",
      "email",
      "microsoftAuthenticatorPush",
      "softwareOneTimePasscode",
      "hardwareOneTimePasscode",
    ];
    const passkeyMethods = [
      "fido2SecurityKey",
      "passKeyDeviceBound",
      "passKeyDeviceBoundAuthenticator",
      "passKeyDeviceBoundWindowsHello",
      "x509Certificate",
    ];
    const phishResistantMethods = [...passkeyMethods, "windowsHelloForBusiness"];

    let singleFactor = 0;
    let phishableCount = 0;
    let phishResistantCount = 0;
    let perUserMFA = 0;
    let phoneCount = 0;
    let authenticatorCount = 0;
    let passkeyCount = 0;
    let whfbCount = 0;

    enabledUsers.forEach((user) => {
      const methods = Array.isArray(user.MFAMethods) ? user.MFAMethods : [];
      const perUser = user.PerUser === "enforced" || user.PerUser === "enabled";
      const hasRegistered = user.MFARegistration === true;

      if (perUser && !hasRegistered && methods.length === 0) {
        perUserMFA++;
        return;
      }

      if (!hasRegistered || methods.length === 0) {
        singleFactor++;
        return;
      }

      const hasPhishResistant = methods.some((m) => phishResistantMethods.includes(m));
      const hasPhishable = methods.some((m) => phishableMethods.includes(m));

      if (hasPhishResistant) {
        phishResistantCount++;
        if (methods.some((m) => passkeyMethods.includes(m))) {
          passkeyCount++;
        }
        if (methods.includes("windowsHelloForBusiness")) {
          whfbCount++;
        }
      } else if (hasPhishable) {
        phishableCount++;
        if (
          methods.includes("mobilePhone") ||
          methods.includes("alternateMobilePhone") ||
          methods.includes("officePhone") ||
          methods.includes("email")
        ) {
          phoneCount++;
        }
        if (
          methods.includes("microsoftAuthenticatorPush") ||
          methods.includes("softwareOneTimePasscode") ||
          methods.includes("hardwareOneTimePasscode")
        ) {
          authenticatorCount++;
        }
      } else {
        phishableCount++;
        authenticatorCount++;
      }
    });

    const mfaPercentage = (
      ((phishableCount + phishResistantCount + perUserMFA) / enabledUsers.length) *
      100
    ).toFixed(1);
    const phishResistantPercentage = ((phishResistantCount / enabledUsers.length) * 100).toFixed(1);

    const links = [
      { source: "Users", target: "Single factor", value: singleFactor },
      { source: "Users", target: "Multi factor", value: perUserMFA },
      { source: "Users", target: "Phishable", value: phishableCount },
      { source: "Users", target: "Phish resistant", value: phishResistantCount },
    ];

    if (phoneCount > 0) links.push({ source: "Phishable", target: "Phone", value: phoneCount });
    if (authenticatorCount > 0)
      links.push({ source: "Phishable", target: "Authenticator", value: authenticatorCount });

    if (passkeyCount > 0)
      links.push({ source: "Phish resistant", target: "Passkey", value: passkeyCount });
    if (whfbCount > 0) links.push({ source: "Phish resistant", target: "Windows Hello", value: whfbCount });

    const description = `${mfaPercentage}% of enabled users have MFA configured. ${phishResistantPercentage}% use phish-resistant authentication methods.`;

    return {
      nodes: [
        { id: "Users", nodeColor: "hsl(220, 60%, 75%)" },
        { id: "Single factor", nodeColor: "hsl(0, 55%, 72%)" },
        { id: "Multi factor", nodeColor: "hsl(200, 55%, 72%)" },
        { id: "Phishable", nodeColor: "hsl(35, 65%, 75%)" },
        { id: "Phone", nodeColor: "hsl(35, 55%, 70%)" },
        { id: "Authenticator", nodeColor: "hsl(35, 60%, 78%)" },
        { id: "Phish resistant", nodeColor: "hsl(140, 50%, 72%)" },
        { id: "Passkey", nodeColor: "hsl(160, 50%, 72%)" },
        { id: "Windows Hello", nodeColor: "hsl(180, 50%, 72%)" },
      ],
      links,
      description,
    };
  };

  const processedData = processData();

  const handleNodeClick = (node) => {
    let filters = [];

    switch (node.id) {
      case "Users":
        filters = [{ id: "AccountEnabled", value: "Yes" }];
        break;
      case "Single factor":
        filters = [
          { id: "AccountEnabled", value: "Yes" },
          { id: "MFARegistration", value: "No" },
        ];
        break;
      case "Multi factor":
        // Per-user MFA enabled/enforced
        filters = [{ id: "AccountEnabled", value: "Yes" }];
        break;
      case "Phishable":
        filters = [
          { id: "AccountEnabled", value: "Yes" },
          { id: "MFARegistration", value: "Yes" },
        ];
        break;
      case "Phish resistant":
        filters = [
          { id: "AccountEnabled", value: "Yes" },
          { id: "MFARegistration", value: "Yes" },
        ];
        break;
      default:
        return;
    }

    router.push({
      pathname: "/identity/reports/mfa-report",
      query: { filters: JSON.stringify(filters) },
    });
  };

  const handleLinkClick = (link) => {
    let filters = [];

    if (link.source.id === "Users" && link.target.id === "Single factor") {
      filters = [
        { id: "AccountEnabled", value: "Yes" },
        { id: "MFARegistration", value: "No" },
      ];
    } else if (link.source.id === "Users" && link.target.id === "Multi factor") {
      filters = [{ id: "AccountEnabled", value: "Yes" }];
    } else if (link.source.id === "Users" && link.target.id === "Phishable") {
      filters = [
        { id: "AccountEnabled", value: "Yes" },
        { id: "MFARegistration", value: "Yes" },
      ];
    } else if (link.source.id === "Users" && link.target.id === "Phish resistant") {
      filters = [
        { id: "AccountEnabled", value: "Yes" },
        { id: "MFARegistration", value: "Yes" },
      ];
    } else if (link.source.id === "Phishable") {
      filters = [
        { id: "AccountEnabled", value: "Yes" },
        { id: "MFARegistration", value: "Yes" },
      ];
    } else if (link.source.id === "Phish resistant") {
      filters = [
        { id: "AccountEnabled", value: "Yes" },
        { id: "MFARegistration", value: "Yes" },
      ];
    }

    if (filters.length > 0) {
      router.push({
        pathname: "/identity/reports/mfa-report",
        query: { filters: JSON.stringify(filters) },
      });
    }
  };

  return (
    <Card sx={{ flex: 1, height: "100%", display: "flex", flexDirection: "column" }}>
      <CardHeader
        title={
          <Box
            onClick={() => router.push("/identity/reports/mfa-report")}
            sx={{
              display: "flex",
              alignItems: "center",
              gap: 1,
              cursor: "pointer",
              width: "fit-content",
              "&:hover": { textDecoration: "underline" },
            }}
          >
            <UsersIcon sx={{ fontSize: compact ? 20 : 24 }} />
            <Typography variant={titleVariant}>All users auth methods</Typography>
          </Box>
        }
        sx={{ pb: compact ? 0.5 : 1, flexShrink: 0 }}
      />
      <CardContent sx={{ pb: compact ? 1.5 : 2, pt: compact ? 1.5 : 2, flex: 1, display: "flex", flexDirection: "column" }}>
        <Box sx={{ flex: 1, minHeight: chartHeight }}>
          {isLoading ? (
            <Skeleton variant="rectangular" width="100%" height={chartHeight} />
          ) : processedData ? (
            <CippSankey
              data={{ nodes: processedData.nodes, links: processedData.links }}
              onNodeClick={handleNodeClick}
              onLinkClick={handleLinkClick}
            />
          ) : (
            <Box
              sx={{
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                height: "100%",
                width: "100%",
              }}
            >
              <Typography variant={descriptionVariant} color="text.secondary">
                No authentication method data available
              </Typography>
            </Box>
          )}
        </Box>
      </CardContent>
      {!isLoading && processedData?.description && (
        <CardContent sx={{ pt: compact ? 1 : 2, pb: compact ? 1.5 : 2, flexShrink: 0 }}>
          <Typography variant={descriptionVariant} color="text.secondary">
            {processedData.description}
          </Typography>
        </CardContent>
      )}
    </Card>
  );
};
