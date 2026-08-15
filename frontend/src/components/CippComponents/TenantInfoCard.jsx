import { Box, Card, CardHeader, CardContent, Typography, Skeleton } from "@mui/material";
import { Business as BuildingIcon } from "@mui/icons-material";
import { CippCopyToClipBoard } from "./CippCopyToClipboard";

export const TenantInfoCard = ({ data, isLoading }) => {
  return (
    <Card sx={{ height: "100%" }}>
      <CardHeader
        title={
          <Box sx={{ display: "flex", alignItems: "center", gap: 0.75 }}>
            <BuildingIcon sx={{ fontSize: 18 }} />
            <Typography variant="subtitle2" fontWeight={600}>Tenant</Typography>
          </Box>
        }
        sx={{ py: 1, px: 1.5 }}
      />
      <CardContent sx={{ pt: 0, px: 1.5, pb: 1.5, "&:last-child": { pb: 1.5 } }}>
        <Box sx={{ display: "flex", flexDirection: "column", gap: 1 }}>
          <Box>
            <Typography variant="caption" color="text.secondary" fontSize="0.65rem">
              Name
            </Typography>
            {isLoading ? (
              <Skeleton width={120} height={20} />
            ) : (
              <Typography variant="body2" fontWeight={500} fontSize="0.85rem">
                {data?.displayName || "Not Available"}
              </Typography>
            )}
          </Box>
          <Box>
            <Typography variant="caption" color="text.secondary" fontSize="0.65rem">
              Tenant ID
            </Typography>
            <Box sx={{ mt: 0.25 }}>
              {isLoading ? (
                <Skeleton width={160} height={20} />
              ) : data?.id ? (
                <CippCopyToClipBoard text={data.id} type="chip" />
              ) : (
                <Typography variant="body2" fontSize="0.75rem">
                  Not Available
                </Typography>
              )}
            </Box>
          </Box>
          <Box>
            <Typography variant="caption" color="text.secondary" fontSize="0.65rem">
              Primary Domain
            </Typography>
            <Box sx={{ mt: 0.25 }}>
              {isLoading ? (
                <Skeleton width={140} height={20} />
              ) : data?.verifiedDomains?.find((d) => d.isDefault)?.name ? (
                <CippCopyToClipBoard
                  text={data.verifiedDomains.find((d) => d.isDefault).name}
                  type="chip"
                />
              ) : (
                <Typography variant="body2" fontSize="0.75rem">
                  Not Available
                </Typography>
              )}
            </Box>
          </Box>
        </Box>
      </CardContent>
    </Card>
  );
};
