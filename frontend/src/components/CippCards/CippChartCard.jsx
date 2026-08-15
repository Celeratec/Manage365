import { useEffect, useState } from "react";
import {
  Box,
  Card,
  CardContent,
  CardHeader,
  Divider,
  Skeleton,
  Stack,
  Typography,
  useMediaQuery,
} from "@mui/material";
import { useTheme } from "@mui/material/styles";
import { ActionsMenu } from "../actions-menu";
import { Chart } from "../chart";
import { chartPink } from "../../theme/colors";

const useChartOptions = (labels, chartType, customColors = null) => {
  const theme = useTheme();

  const defaultColors = [
    theme.palette.success.main,
    theme.palette.warning.main,
    theme.palette.error.main,
    chartPink,
  ];

  return {
    chart: {
      background: "transparent",
      toolbar: {
        show: false,
        tools: {
          download: true,
          selection: false,
          zoom: false,
          zoomin: false,
          zoomout: false,
          pan: false,
          reset: true | '<img src="/static/icons/reset.png" width="20">',
        },
      },
    },
    colors: customColors || defaultColors,
    dataLabels: {
      enabled: false,
    },

    xaxis: {
      // Categories drive the bar/line axis labels and the tooltip title. Without this, a bar
      // chart's tooltip falls back to the auto series name ("series-1") instead of the label.
      categories: labels,
      labels: {
        show: true,
        rotate: 0,
        style: {
          fontSize: "12px",
        },
      },
      tickPlacement: "on",
    },
    labels,
    legend: {
      show: false,
    },
    plotOptions: {
      // distributed colors each bar (data point) from the colors array so a single-series bar
      // chart keeps the per-item colors, and the tooltip shows the category name per bar.
      bar: {
        distributed: true,
      },
      pie: {
        expandOnClick: false,
      },
    },
    states: {
      active: {
        filter: {
          type: "none",
        },
      },
      hover: {
        filter: {
          type: "none",
        },
      },
    },
    stroke: {
      width: chartType === "line" ? 2 : 1,
    },
    theme: {
      mode: theme.palette.mode,
    },
    tooltip: {
      fillSeriesColor: false,
    },
  };
};

export const CippChartCard = ({
  isFetching,
  chartSeries = [],
  labels = [],
  chartType = "donut",
  title,
  actions,
  onClick,
  totalLabel = "Total",
  customTotal,
  compact = false,
  showHeaderDivider = true,
  headerIcon = null,
  horizontalLayout = false,
  formatValue = null,
  colors = null,
}) => {
  const theme = useTheme();
  const smDown = useMediaQuery(theme.breakpoints.down("sm"));
  const [range, setRange] = useState("Last 7 days");
  const [barSeries, setBarSeries] = useState([]);
  const chartOptions = useChartOptions(labels, chartType, colors);
  chartSeries = chartSeries.filter((item) => item !== null);
  const calculatedTotal = chartSeries.reduce((acc, value) => acc + value, 0);
  const total = customTotal !== undefined ? customTotal : calculatedTotal;
  const chartHeight = compact ? 200 : 280;
  const contentPadding = compact ? 1.5 : 2;
  const rowPadding = compact ? 0.5 : 1;
  const labelVariant = compact ? "caption" : "body2";
  const totalVariant = compact ? "subtitle1" : "h5";
  const titleVariant = compact ? "subtitle1" : "h6";

  // Helper to format display values
  const displayValue = (value) => (formatValue ? formatValue(value) : value);

  // For horizontal layout, use smaller chart height to fit side by side
  const horizontalChartHeight = compact ? 180 : 240;
  const useHorizontal = horizontalLayout && !smDown;

  useEffect(() => {
    if (chartType === "bar") {
      // Single named series with the labels supplied via xaxis.categories. This keeps the tooltip
      // title tied to the category (e.g. the site name) instead of an auto "series-1" name.
      setBarSeries([{ name: totalLabel, data: chartSeries }]);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [chartType, chartSeries.join(","), labels.join(","), totalLabel]);

  const renderLegend = () => (
    <Stack spacing={compact ? 0.5 : 1}>
      {isFetching ? (
        <Skeleton height={30} />
      ) : (
        <>
          {labels.length > 0 &&
            chartSeries.map((item, index) => (
              <Stack
                alignItems="center"
                direction="row"
                justifyContent="space-between"
                key={labels[index]}
                spacing={1}
                sx={{ py: rowPadding }}
              >
                <Stack alignItems="center" direction="row" spacing={1} sx={{ flexGrow: 1 }}>
                  <Box
                    sx={{
                      // Match ApexCharts' color cycling so the dot lines up with its bar/slice.
                      backgroundColor: chartOptions.colors[index % chartOptions.colors.length],
                      borderRadius: "50%",
                      height: 8,
                      width: 8,
                    }}
                  />
                  <Typography color="text.secondary" variant={labelVariant}>
                    {labels[index]}
                  </Typography>
                </Stack>
                <Typography color="text.secondary" variant={labelVariant}>
                  {displayValue(item)}
                </Typography>
              </Stack>
            ))}
        </>
      )}
    </Stack>
  );

  const renderTotal = () => (
    <Stack
      alignItems="center"
      direction="row"
      justifyContent="space-between"
      spacing={1}
      sx={{ py: rowPadding }}
    >
      {labels.length > 0 && (
        <>
          <Typography variant={totalVariant}>{totalLabel}</Typography>
          <Typography variant={totalVariant}>{isFetching ? "0" : displayValue(total)}</Typography>
        </>
      )}
    </Stack>
  );

  return (
    <Card
      style={{ width: "100%", height: "100%" }}
      onClick={onClick}
      sx={{
        cursor: onClick ? "pointer" : "default",
        transition: "all 150ms ease-out",
        "&:hover": onClick ? {
          boxShadow: (theme) => theme.shadows[8],
          transform: "translateY(-2px)",
        } : {},
      }}
    >
      <CardHeader
        action={
          actions ? (
            <ActionsMenu
              color="inherit"
              actions={actions}
              label={range}
              size="small"
              variant="text"
            />
          ) : null
        }
        title={
          headerIcon ? (
            <Box sx={{ display: "flex", alignItems: "center", gap: 1 }}>
              {headerIcon}
              <Typography variant={titleVariant}>{title}</Typography>
            </Box>
          ) : (
            title
          )
        }
        sx={headerIcon ? { pb: compact ? 0.5 : 1 } : undefined}
      />
      {showHeaderDivider && <Divider />}
      <CardContent sx={{ pt: contentPadding, pb: contentPadding + 0.5, height: useHorizontal ? "calc(100% - 60px)" : "auto" }}>
        {useHorizontal ? (
          // Horizontal layout: chart on left, legend on right
          <Box sx={{ display: "flex", height: "100%", alignItems: "center", gap: 2 }}>
            <Box sx={{ flex: "0 0 55%", minWidth: 0 }}>
              {chartType === undefined || isFetching || chartSeries.length === 0 ? (
                <Skeleton variant="rounded" sx={{ height: horizontalChartHeight }} />
              ) : (
                <Chart
                  height={horizontalChartHeight}
                  options={chartOptions}
                  series={barSeries && chartType === "bar" ? barSeries : chartSeries}
                  type={chartType}
                />
              )}
            </Box>
            <Box sx={{ flex: 1, display: "flex", flexDirection: "column", justifyContent: "center" }}>
              {renderTotal()}
              {renderLegend()}
            </Box>
          </Box>
        ) : (
          // Vertical layout (default): chart on top, legend below
          <>
            {chartType === undefined || isFetching || chartSeries.length === 0 ? (
              <Skeleton variant="rounded" sx={{ height: chartHeight }} />
            ) : (
              <Chart
                height={chartHeight}
                options={chartOptions}
                series={barSeries && chartType === "bar" ? barSeries : chartSeries}
                type={chartType}
              />
            )}
            {renderTotal()}
            {renderLegend()}
          </>
        )}
      </CardContent>
    </Card>
  );
};
