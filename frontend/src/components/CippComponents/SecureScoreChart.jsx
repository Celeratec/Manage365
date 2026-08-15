import { Box, Typography, Divider, Skeleton } from "@mui/material";
import {
  LineChart,
  Line,
  CartesianGrid,
  XAxis,
  YAxis,
  ResponsiveContainer,
  Tooltip as RechartsTooltip,
} from "recharts";
import { useState, useEffect, useRef, useCallback } from "react";

export const SecureScoreChart = ({ data, isLoading }) => {
  const chartContainerRef = useRef(null);
  const [containerReady, setContainerReady] = useState(false);

  // Check if container has valid dimensions - used both in effect and during render
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

  // Synchronous check during render - if state says ready but dimensions are invalid, don't render chart
  const canRenderChart = containerReady && hasValidDimensions();
  if (isLoading) {
    return (
      <>
        <Box sx={{ height: 250 }}>
          <Box sx={{ display: "flex", flexDirection: "column", gap: 2, p: 2 }}>
            <Skeleton variant="rectangular" width="100%" height={200} />
          </Box>
        </Box>
        <Typography variant="body2" color="text.secondary" sx={{ mt: 2 }}>
          The Secure Score measures your security posture across your tenant.
        </Typography>
        <Divider sx={{ mt: 2 }} />
        <Box sx={{ display: "flex", gap: 2, pt: 2 }}>
          <Box sx={{ flex: 1 }}>
            <Skeleton width={80} height={60} />
          </Box>
          <Divider orientation="vertical" flexItem />
          <Box sx={{ flex: 1 }}>
            <Skeleton width={80} height={60} />
          </Box>
          <Divider orientation="vertical" flexItem />
          <Box sx={{ flex: 1 }}>
            <Skeleton width={80} height={60} />
          </Box>
        </Box>
      </>
    );
  }

  if (!data || !Array.isArray(data) || data.length === 0) {
    return (
      <>
        <Box sx={{ height: 250 }}>
          <Box
            sx={{
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              height: "100%",
            }}
          >
            <Typography variant="body2" color="text.secondary">
              No secure score data available
            </Typography>
          </Box>
        </Box>
        <Typography variant="body2" color="text.secondary" sx={{ mt: 2 }}>
          The Secure Score measures your security posture across your tenant.
        </Typography>
        <Divider sx={{ mt: 2 }} />
        <Box sx={{ pt: 2 }}>
          <Typography variant="body2" color="text.secondary">
            Enable secure score monitoring in your tenant
          </Typography>
        </Box>
      </>
    );
  }

  const sortedData = [...data].sort(
    (a, b) => new Date(a.createdDateTime) - new Date(b.createdDateTime)
  );

  const chartData = sortedData.map((score) => ({
    date: new Date(score.createdDateTime).toLocaleDateString("en-US", {
      month: "short",
      day: "numeric",
    }),
    score: score.currentScore,
    percentage: Math.round((score.currentScore / score.maxScore) * 100),
  }));

  const latestScore = sortedData[sortedData.length - 1];
  const latestPercentage = Math.round((latestScore.currentScore / latestScore.maxScore) * 100);

  return (
    <>
      <Box ref={chartContainerRef} sx={{ height: 250, minHeight: 250, minWidth: 0 }}>
        {canRenderChart ? (
          <ResponsiveContainer width="100%" height="100%" minWidth={0} minHeight={0} debounce={50}>
            <LineChart data={chartData} margin={{ left: 12, right: 12, top: 10, bottom: 10 }}>
              <CartesianGrid strokeDasharray="3 3" stroke="#e0e0e0" />
              <XAxis dataKey="date" tick={{ fontSize: 12 }} tickMargin={8} />
              <YAxis tick={{ fontSize: 12 }} tickMargin={8} domain={[0, "dataMax + 20"]} />
              <RechartsTooltip
                contentStyle={{
                  backgroundColor: "rgba(255, 255, 255, 0.95)",
                  border: "1px solid #ccc",
                  borderRadius: "4px",
                }}
                formatter={(value, name) => {
                  if (name === "score") return [value.toFixed(2), "Score"];
                  if (name === "percentage") return [value + "%", "Percentage"];
                  return value;
                }}
              />
              <Line
                type="monotone"
                dataKey="score"
                stroke="#22c55e"
                strokeWidth={2}
                dot={{ fill: "#22c55e", r: 4 }}
                activeDot={{ r: 6 }}
              />
            </LineChart>
          </ResponsiveContainer>
        ) : (
          <Skeleton variant="rectangular" width="100%" height={250} />
        )}
      </Box>
      <Typography variant="body2" color="text.secondary" sx={{ mt: 2 }}>
        The Secure Score measures your security posture across your tenant.
      </Typography>
      <Divider sx={{ mt: 2 }} />
      <Box sx={{ display: "flex", gap: 2, pt: 2 }}>
        <Box sx={{ flex: 1 }}>
          <Typography variant="caption" color="text.secondary">
            Latest %
          </Typography>
          <Typography variant="h6" fontWeight="bold">
            {latestPercentage}%
          </Typography>
        </Box>
        <Divider orientation="vertical" flexItem />
        <Box sx={{ flex: 1 }}>
          <Typography variant="caption" color="text.secondary">
            Current Score
          </Typography>
          <Typography variant="h6" fontWeight="bold">
            {latestScore.currentScore.toFixed(2)}
          </Typography>
        </Box>
        <Divider orientation="vertical" flexItem />
        <Box sx={{ flex: 1 }}>
          <Typography variant="caption" color="text.secondary">
            Max Score
          </Typography>
          <Typography variant="h6" fontWeight="bold">
            {latestScore.maxScore.toFixed(2)}
          </Typography>
        </Box>
      </Box>
    </>
  );
};
