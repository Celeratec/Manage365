import React, { useState, useEffect, useCallback, useRef } from "react";
import {
  IconButton,
  Tooltip,
  Badge,
  Typography,
  LinearProgress,
  Box,
  Stack,
  Chip,
} from "@mui/material";
import { Timeline, Circle } from "@mui/icons-material";
import { CippOffCanvas } from "../CippComponents/CippOffCanvas";
import { ApiGetCall } from "../../api/ApiCall";
import { useQueryClient } from "@tanstack/react-query";
import { useDispatch } from "react-redux";
import { showToast } from "../../store/toasts";

/**
 * Polls a single queue entry and calls back on status changes.
 * Renders nothing — purely a polling side-effect hook wrapper.
 */
const QueuePoller = ({ queueId, onData, onComplete }) => {
  const [isCompleted, setIsCompleted] = useState(false);

  const polling = ApiGetCall({
    url: `/api/ListCippQueue`,
    data: { QueueId: queueId },
    queryKey: `CippQueue-${queueId}`,
    waiting: !!queueId && !isCompleted,
    refetchInterval: (data) => {
      const d = data?.[0];
      if (
        d?.Status === "Completed" ||
        d?.Status === "Failed" ||
        d?.Status === "Completed (with errors)"
      ) {
        return false;
      }
      return 3000;
    },
    refetchOnMount: true,
    refetchOnWindowFocus: false,
  });

  const queueData = polling.data?.[0];

  useEffect(() => {
    if (!queueData) return;
    onData(queueId, queueData);

    const terminal =
      queueData.Status === "Completed" ||
      queueData.Status === "Failed" ||
      queueData.Status === "Completed (with errors)";

    if (terminal && !isCompleted) {
      setIsCompleted(true);
      onComplete(queueId, queueData);
    }
  }, [queueData, queueId, onData, onComplete, isCompleted]);

  return null;
};

export const CippQueueTracker = ({
  queueIds = [],
  queueId: legacySingleId,
  queryKey,
  title,
  onQueueComplete,
  onSingleQueueComplete,
}) => {
  const queryClient = useQueryClient();
  const dispatch = useDispatch();
  const [queueCanvasVisible, setQueueCanvasVisible] = useState(false);

  // Merge legacy single-id prop with the array prop for backwards compat
  const allIds = [
    ...queueIds,
    ...(legacySingleId && !queueIds.includes(legacySingleId) ? [legacySingleId] : []),
  ];

  // Map queueId -> latest data
  const [queueDataMap, setQueueDataMap] = useState({});
  const completedToastRef = useRef(new Set());

  const handleData = useCallback((id, data) => {
    setQueueDataMap((prev) => ({ ...prev, [id]: data }));
  }, []);

  const handleComplete = useCallback(
    (id, data) => {
      // Fire toast once per queue
      if (!completedToastRef.current.has(id)) {
        completedToastRef.current.add(id);

        const queueName = data?.Name || "Background task";
        if (data?.Status === "Completed") {
          dispatch(showToast({ message: `${queueName} completed successfully.`, title: "Task Complete" }));
        } else if (data?.Status === "Failed") {
          dispatch(showToast({ message: `${queueName} failed.`, title: "Task Failed" }));
        } else if (data?.Status === "Completed (with errors)") {
          dispatch(
            showToast({
              message: `${queueName} completed with errors (${data?.FailedTasks} failed).`,
              title: "Task Complete (with errors)",
            })
          );
        }

        // Refresh the table data
        const currentQueryKey = queryKey || title;
        if (currentQueryKey) {
          queryClient.invalidateQueries({ queryKey: [currentQueryKey] });
        }

        // Notify parent so it can remove this id from its array
        if (onSingleQueueComplete) {
          onSingleQueueComplete(id);
        }
        // Legacy callback
        if (onQueueComplete) {
          onQueueComplete(id);
        }
      }
    },
    [dispatch, queryClient, queryKey, title, onSingleQueueComplete, onQueueComplete]
  );

  // Clean stale entries from the map when allIds changes (entries removed by parent)
  useEffect(() => {
    setQueueDataMap((prev) => {
      const next = {};
      for (const id of allIds) {
        if (prev[id]) next[id] = prev[id];
      }
      return next;
    });
  }, [allIds.join(",")]); // eslint-disable-line react-hooks/exhaustive-deps

  if (allIds.length === 0) return null;

  // Aggregate status across all tracked queues
  const allData = allIds.map((id) => queueDataMap[id]).filter(Boolean);
  const activeCount = allData.filter(
    (d) => d.Status !== "Completed" && d.Status !== "Failed" && d.Status !== "Completed (with errors)"
  ).length;
  const failedCount = allData.filter(
    (d) => d.Status === "Failed" || d.Status === "Completed (with errors)"
  ).length;
  const completedCount = allData.filter((d) => d.Status === "Completed").length;
  const totalCount = allIds.length;

  const overallColor =
    activeCount > 0
      ? "primary.main"
      : failedCount > 0
      ? "error.main"
      : "success.main";

  const badgeColor =
    activeCount > 0
      ? "warning.main"
      : failedCount > 0
      ? "error.main"
      : "success.main";

  const tooltipText =
    activeCount > 0
      ? `${activeCount} task${activeCount > 1 ? "s" : ""} running (${completedCount} done, ${failedCount} failed)`
      : failedCount > 0
      ? `All tasks finished — ${failedCount} failed, ${completedCount} succeeded`
      : `All ${completedCount} task${completedCount > 1 ? "s" : ""} completed`;

  return (
    <>
      {/* Render one poller per tracked queue */}
      {allIds.map((id) => (
        <QueuePoller key={id} queueId={id} onData={handleData} onComplete={handleComplete} />
      ))}

      <Tooltip title={tooltipText}>
        <Badge
          badgeContent={
            totalCount > 1 ? (
              totalCount
            ) : (
              <Circle sx={{ fontSize: 8, color: badgeColor }} />
            )
          }
          color={activeCount > 0 ? "warning" : failedCount > 0 ? "error" : "success"}
          overlap="circular"
          anchorOrigin={{ vertical: "top", horizontal: "right" }}
        >
          <IconButton
            onClick={() => setQueueCanvasVisible(true)}
            sx={{
              animation: activeCount > 0 ? "pulse 2s infinite" : "none",
              "@keyframes pulse": {
                "0%": { transform: "scale(1)", opacity: 1 },
                "50%": { transform: "scale(1.1)", opacity: 0.8 },
                "100%": { transform: "scale(1)", opacity: 1 },
              },
              color: overallColor,
            }}
          >
            <Timeline />
          </IconButton>
        </Badge>
      </Tooltip>

      {/* Queue Status OffCanvas */}
      <CippOffCanvas
        size="lg"
        title="Background Tasks"
        visible={queueCanvasVisible}
        onClose={() => setQueueCanvasVisible(false)}
      >
        <Stack spacing={3} sx={{ height: "100%", display: "flex", flexDirection: "column" }}>
          {allIds.length === 0 ? (
            <Typography>No background tasks</Typography>
          ) : (
            <Box
              sx={{
                flex: 1,
                overflowY: "auto",
                pr: 1,
                "&::-webkit-scrollbar": { width: 8 },
                "&::-webkit-scrollbar-track": {
                  backgroundColor: (theme) =>
                    theme.palette.mode === "dark" ? "rgba(255,255,255,0.1)" : "rgba(0,0,0,0.1)",
                  borderRadius: 4,
                },
                "&::-webkit-scrollbar-thumb": {
                  backgroundColor: (theme) =>
                    theme.palette.mode === "dark" ? "rgba(255,255,255,0.3)" : "rgba(0,0,0,0.3)",
                  borderRadius: 4,
                  "&:hover": {
                    backgroundColor: (theme) =>
                      theme.palette.mode === "dark"
                        ? "rgba(255,255,255,0.5)"
                        : "rgba(0,0,0,0.5)",
                  },
                },
              }}
            >
              <Stack spacing={2}>
                {allIds.map((id) => {
                  const data = queueDataMap[id];
                  if (!data) {
                    return (
                      <Box key={id} sx={{ p: 2, border: 1, borderColor: "divider", borderRadius: 1 }}>
                        <Typography variant="body2" color="text.secondary">
                          Loading...
                        </Typography>
                      </Box>
                    );
                  }
                  const isTerminal =
                    data.Status === "Completed" ||
                    data.Status === "Failed" ||
                    data.Status === "Completed (with errors)";
                  return (
                    <Box
                      key={id}
                      sx={(theme) => ({
                        p: 2,
                        border: 1,
                        borderColor:
                          theme.palette.mode === "dark" ? "rgba(255,255,255,0.12)" : "divider",
                        borderRadius: 1,
                        backgroundColor:
                          data.Status === "Completed"
                            ? theme.palette.mode === "dark"
                              ? "rgba(102, 187, 106, 0.15)"
                              : "success.light"
                            : data.Status === "Failed"
                            ? theme.palette.mode === "dark"
                              ? "rgba(244, 67, 54, 0.15)"
                              : "error.light"
                            : data.Status === "Completed (with errors)"
                            ? theme.palette.mode === "dark"
                              ? "rgba(255, 152, 0, 0.15)"
                              : "warning.light"
                            : theme.palette.mode === "dark"
                            ? "rgba(255,255,255,0.05)"
                            : "grey.100",
                        transition: "all 0.2s ease-in-out",
                      })}
                    >
                      <Stack direction="row" justifyContent="space-between" alignItems="center">
                        <Typography variant="body2" fontWeight="medium">
                          {data.Name}
                        </Typography>
                        <Chip
                          label={data.Status}
                          size="small"
                          color={
                            data.Status === "Completed"
                              ? "success"
                              : data.Status === "Failed"
                              ? "error"
                              : data.Status === "Completed (with errors)"
                              ? "warning"
                              : "info"
                          }
                          variant="outlined"
                          sx={{ fontSize: "0.7rem" }}
                        />
                      </Stack>
                      {!isTerminal && (
                        <Box sx={{ mt: 1 }}>
                          <LinearProgress
                            variant="determinate"
                            value={data.PercentComplete || 0}
                            sx={{ height: 6, borderRadius: 3 }}
                          />
                          <Typography variant="caption" color="text.secondary" sx={{ mt: 0.5 }}>
                            {data.PercentComplete?.toFixed(0)}% — {data.CompletedTasks || 0}/
                            {data.TotalTasks || 0} tasks
                          </Typography>
                        </Box>
                      )}
                      {isTerminal && data.FailedTasks > 0 && (
                        <Typography variant="caption" color="error.main" sx={{ mt: 0.5, display: "block" }}>
                          {data.FailedTasks} task{data.FailedTasks > 1 ? "s" : ""} failed
                        </Typography>
                      )}
                      {/* Task details */}
                      {data.Tasks && data.Tasks.length > 0 && (
                        <Stack spacing={0.5} sx={{ mt: 1 }}>
                          {data.Tasks.map((task, i) => (
                            <Stack key={i} direction="row" justifyContent="space-between" alignItems="center">
                              <Typography variant="caption">{task.Name}</Typography>
                              <Typography
                                variant="caption"
                                sx={{
                                  color:
                                    task.Status === "Completed"
                                      ? "success.main"
                                      : task.Status === "Failed"
                                      ? "error.main"
                                      : task.Status === "Running"
                                      ? "warning.main"
                                      : "text.secondary",
                                }}
                              >
                                {task.Status}
                              </Typography>
                            </Stack>
                          ))}
                        </Stack>
                      )}
                    </Box>
                  );
                })}
              </Stack>
            </Box>
          )}
        </Stack>
      </CippOffCanvas>
    </>
  );
};
