import { Alert } from "@mui/material";
import { Box, Container, Stack } from "@mui/system";
import { CippDataTable } from "../CippTable/CippDataTable";
import { useSettings } from "../../hooks/use-settings";
import { CippHead } from "./CippHead";

export const CippTablePage = (props) => {
  const {
    title,
    cardButton,
    noDataButton,
    actions,
    apiUrl,
    apiData,
    apiDataKey,
    columns,
    columnsFromApi,
    name,
    options,
    onChange,
    offCanvas,
    queryKey,
    tableFilter,
    tenantInTitle = true,
    filters,
    initialFilters,
    sx = {},
    spacing = 2,
    dataFreshnessField,
    apiDataFilter,
    ...other
  } = props;
  const tenant = useSettings().currentTenant;

  // Use initialFilters if provided, otherwise use regular filters
  const activeFilters = initialFilters || filters;
  return (
    <>
      <CippHead title={title} />
      <Box sx={sx}>
        <Container maxWidth={false} sx={{ height: "100%" }}>
          <Stack spacing={spacing} sx={{ height: "100%" }}>
            {tableFilter}
            {tenantInTitle && (!tenant || tenant === null) && (
              <Alert severity="warning">
                No tenant selected. Please select a tenant from the dropdown above.
              </Alert>
            )}
            <CippDataTable
              queryKey={queryKey}
              cardButton={cardButton}
              title={tenantInTitle && tenant !== null ? `${title} - ${tenant}` : title}
              noDataButton={noDataButton}
              actions={actions}
              simple={false}
              api={{
                url: apiUrl,
                data: { tenantFilter: tenant, ...apiData },
                dataKey: apiDataKey,
                ...(apiDataFilter && { dataFilter: apiDataFilter }),
              }}
              columns={columns}
              columnsFromApi={columnsFromApi}
              offCanvas={offCanvas}
              filters={activeFilters}
              dataFreshnessField={dataFreshnessField}
              {...other}
            />
          </Stack>
        </Container>
      </Box>
    </>
  );
};

export default CippTablePage;
