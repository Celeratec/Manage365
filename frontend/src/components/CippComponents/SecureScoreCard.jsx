import { Box, Card, CardHeader, CardContent, Typography, Divider, Skeleton } from "@mui/material";
import { Security as SecurityIcon, TrendingUp, TrendingDown, TrendingFlat } from "@mui/icons-material";
import { useRouter } from "next/router";
import {
  RadialBarChart,
  RadialBar,
  AreaChart,
  Area,
  ResponsiveContainer,
  Tooltip as RechartsTooltip,
} from "recharts";
import { useState, useEffect, useRef, useCallback } from "react";

// Custom tooltip component with dark background
const CustomTooltip = ({ active, payload, label }) => {
  if (active && payload && payload.length) {
    const data = payload[0].payload;
    return (
      <Box
        sx={{
          backgroundColor: "rgba(30, 30, 30, 0.95)",
          color: "#fff",
          borderRadius: "6px",
          padding: "8px 12px",
          boxShadow: "0 4px 12px rgba(0,0,0,0.3)",
          fontSize: "12px",
        }}
      >
        <Typography variant="caption" sx={{ color: "rgba(255,255,255,0.7)", display: "block", mb: 0.5 }}>
          {data.date}
        </Typography>
        <Typography variant="body2" sx={{ fontWeight: "bold", color: "#fff" }}>
          {data.score.toFixed(1)} / {data.maxScore.toFixed(1)} pts
        </Typography>
        <Typography variant="caption" sx={{ color: "hsl(140, 50%, 70%)" }}>
          {data.percentage}%
        </Typography>
      </Box>
    );
  }
  return null;
};

export const SecureScoreCard = ({ data, isLoading, compact = false }) => {
  const router = useRouter();
  const chartContainerRef = useRef(null);
  const [containerReady, setContainerReady] = useState(false);
  const titleVariant = compact ? "subtitle1" : "h6";
  const descriptionVariant = compact ? "caption" : "body2";

  const hasValidDimensions = useCallback(() => {
    if (!chartContainerRef.current) return false;
    const { width, height } = chartContainerRef.current.getBoundingClientRect();
    return width > 0 && height > 0;
  }, []);

  useEffect(() => {
    const checkContainer = () => {
      if (hasValidDimensions()) {
        setContainerReady(true);
      } else {
        setContainerReady(false);
      }
    };

    checkContainer();
    const timer = setTimeout(checkContainer, 100);

    const resizeObserver = new ResizeObserver(checkContainer);
    if (chartContainerRef.current) {
      resizeObserver.observe(chartContainerRef.current);
    }

    return () => {
      clearTimeout(timer);
      resizeObserver.disconnect();
    };
  }, [isLoading, hasValidDimensions]);

  const canRenderChart = containerReady && hasValidDimensions();

  // Process data for charts
  const processedData = data && Array.isArray(data) && data.length > 0 ? (() => {
    const sortedData = [...data].sort(
      (a, b) => new Date(a.createdDateTime) - new Date(b.createdDateTime)
    );
    const latest = sortedData[sortedData.length - 1];
    const previous = sortedData.length > 1 ? sortedData[sortedData.length - 2] : null;
    
    const currentPercentage = Math.round((latest.currentScore / latest.maxScore) * 100);
    const previousPercentage = previous 
      ? Math.round((previous.currentScore / previous.maxScore) * 100)
      : currentPercentage;
    
    const trend = currentPercentage - previousPercentage;
    
    const sparklineData = sortedData.map((score) => ({
      date: new Date(score.createdDateTime).toLocaleDateString("en-US", {
        month: "short",
        day: "numeric",
      }),
      score: score.currentScore,
      maxScore: score.maxScore,
      percentage: Math.round((score.currentScore / score.maxScore) * 100),
    }));

    return {
      currentPercentage,
      currentScore: latest.currentScore,
      maxScore: latest.maxScore,
      trend,
      sparklineData,
      gaugeData: [{ name: "Score", value: currentPercentage, fill: "hsl(140, 50%, 65%)" }],
    };
  })() : null;

  const getTrendIcon = (trend) => {
    if (trend > 0) return <TrendingUp sx={{ fontSize: 14, color: "hsl(140, 50%, 55%)" }} />;
    if (trend < 0) return <TrendingDown sx={{ fontSize: 14, color: "hsl(0, 55%, 65%)" }} />;
    return <TrendingFlat sx={{ fontSize: 14, color: "text.secondary" }} />;
  };

  const getTrendColor = (trend) => {
    if (trend > 0) return "hsl(140, 50%, 55%)";
    if (trend < 0) return "hsl(0, 55%, 65%)";
    return "text.secondary";
  };

  const gaugeSize = compact ? 140 : 160;
  const sparklineHeight = compact ? 100 : 120;

  return (
    <Card sx={{ flex: 1, height: "100%", display: "flex", flexDirection: "column" }}>
      <CardHeader
        title={
          <Box
            onClick={() => router.push("/tenant/administration/securescore")}
            sx={{
              display: "flex",
              alignItems: "center",
              gap: 1,
              cursor: "pointer",
              width: "fit-content",
              "&:hover": { textDecoration: "underline" },
            }}
          >
            <SecurityIcon sx={{ fontSize: compact ? 20 : 24 }} />
            <Typography variant={titleVariant}>Secure Score</Typography>
          </Box>
        }
        sx={{ pb: compact ? 0.5 : 1, flexShrink: 0 }}
      />
      <CardContent
        sx={{
          pt: compact ? 1 : 1.5,
          pb: compact ? 1 : 1.5,
          flex: 1,
          display: "flex",
          flexDirection: "column",
          justifyContent: "center",
        }}
      >
        {isLoading ? (
          <Box sx={{ display: "flex", gap: 2, alignItems: "center" }}>
            <Skeleton variant="circular" width={gaugeSize} height={gaugeSize} />
            <Skeleton variant="rectangular" sx={{ flex: 1 }} height={sparklineHeight} />
          </Box>
        ) : !processedData ? (
          <Box
            sx={{
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              height: "100%",
            }}
          >
            <Typography variant={descriptionVariant} color="text.secondary">
              No secure score data available
            </Typography>
          </Box>
        ) : (
          <Box ref={chartContainerRef} sx={{ minWidth: 0 }}>
            {canRenderChart && (
              <Box sx={{ display: "flex", gap: 2, alignItems: "center" }}>
                {/* Left side - Gauge Chart with percentage in center */}
                <Box sx={{ position: "relative", width: gaugeSize, height: gaugeSize, flexShrink: 0 }}>
                  <ResponsiveContainer width="100%" height="100%">
                    <RadialBarChart
                      cx="50%"
                      cy="50%"
                      innerRadius="70%"
                      outerRadius="90%"
                      startAngle={90}
                      endAngle={-270}
                      data={processedData.gaugeData}
                      barSize={compact ? 10 : 12}
                    >
                      <RadialBar
                        background={{ fill: "hsl(0, 0%, 90%)" }}
                        dataKey="value"
                        cornerRadius={10}
                      />
                    </RadialBarChart>
                  </ResponsiveContainer>
                  {/* Center text overlay */}
                  <Box
                    sx={{
                      position: "absolute",
                      top: "50%",
                      left: "50%",
                      transform: "translate(-50%, -50%)",
                      textAlign: "center",
                    }}
                  >
                    <Typography
                      variant={compact ? "h5" : "h4"}
                      fontWeight="bold"
                      sx={{ lineHeight: 1 }}
                    >
                      {processedData.currentPercentage}%
                    </Typography>
                    <Box sx={{ display: "flex", alignItems: "center", justifyContent: "center", gap: 0.25, mt: 0.25 }}>
                      {getTrendIcon(processedData.trend)}
                      <Typography
                        variant="caption"
                        sx={{ color: getTrendColor(processedData.trend), fontSize: "0.7rem" }}
                      >
                        {processedData.trend > 0 ? "+" : ""}
                        {processedData.trend}%
                      </Typography>
                    </Box>
                  </Box>
                </Box>

                {/* Right side - Area chart for trend */}
                <Box sx={{ flex: 1, height: sparklineHeight, minWidth: 0 }}>
                  <ResponsiveContainer width="100%" height="100%">
                    <AreaChart
                      data={processedData.sparklineData}
                      margin={{ top: 10, right: 10, left: 0, bottom: 10 }}
                    >
                      <defs>
                        <linearGradient id="secureScoreGradient" x1="0" y1="0" x2="0" y2="1">
                          <stop offset="5%" stopColor="hsl(140, 50%, 65%)" stopOpacity={0.4} />
                          <stop offset="95%" stopColor="hsl(140, 50%, 65%)" stopOpacity={0.05} />
                        </linearGradient>
                      </defs>
                      <RechartsTooltip content={<CustomTooltip />} />
                      <Area
                        type="monotone"
                        dataKey="percentage"
                        stroke="hsl(140, 50%, 65%)"
                        strokeWidth={2}
                        fill="url(#secureScoreGradient)"
                        dot={{ fill: "hsl(140, 50%, 65%)", r: 3, strokeWidth: 0 }}
                        activeDot={{ fill: "hsl(140, 50%, 55%)", r: 5, strokeWidth: 0 }}
                      />
                    </AreaChart>
                  </ResponsiveContainer>
                </Box>
              </Box>
            )}
            {!canRenderChart && (
              <Skeleton variant="rectangular" width="100%" height={gaugeSize} />
            )}
          </Box>
        )}
      </CardContent>
      <Divider sx={{ flexShrink: 0 }} />
      <CardContent sx={{ pt: compact ? 1 : 1.5, pb: compact ? 1.5 : 2, flexShrink: 0 }}>
        {isLoading ? (
          <Typography variant={descriptionVariant} color="text.secondary" sx={{ textAlign: "center" }}>
            Loading secure score data...
          </Typography>
        ) : !processedData ? (
          <Typography variant={descriptionVariant} color="text.secondary" sx={{ textAlign: "center" }}>
            Enable secure score monitoring in your tenant
          </Typography>
        ) : (
          <Box sx={{ display: "flex", justifyContent: "center", alignItems: "center", gap: 1 }}>
            <Typography variant={descriptionVariant} color="text.secondary">
              Current:
            </Typography>
            <Typography variant={descriptionVariant} fontWeight="bold">
              {processedData.currentScore.toFixed(1)} / {processedData.maxScore.toFixed(1)} pts
            </Typography>
          </Box>
        )}
      </CardContent>
    </Card>
  );
};
