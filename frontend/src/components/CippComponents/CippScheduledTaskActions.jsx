
import { CippIcons } from "../../utils/icon-registry"
import { usePermissions } from "../../hooks/use-permissions";

const schedulerJobUrl = (rowKey, clone = false) => {
  const id = String(rowKey ?? "");
  if (!/^[\w-]+$/.test(id)) return null;
  const url = new URL("/cipp/scheduler/job", window.location.origin);
  url.searchParams.set("id", id);
  if (clone) url.searchParams.set("Clone", "True");
  return `${url.pathname}${url.search}`;
};

export const CippScheduledTaskActions = (drawerHandlers = {}, { hideActions = [] } = {}) => {
  const { checkPermissions } = usePermissions();
  const canWriteScheduler = checkPermissions(["CIPP.Scheduler.ReadWrite"]);
  const canReadScheduler = checkPermissions(["CIPP.Scheduler.Read", "CIPP.Scheduler.ReadWrite"]);

  return [
{
      label: "View Task Details",
      category: "view",
      link: "/cipp/scheduler/task?id=[RowKey]",
      pinned: true,
      icon: <CippIcons.EyeIcon />,
      condition: () => canReadScheduler,
    },
{
      label: "Run Now",
      category: "manage",
      type: "POST",
      url: "/api/AddScheduledItem",
      data: { RowKey: "RowKey", RunNow: true },
      icon: <CippIcons.PlayArrow />,
      confirmText: "Are you sure you want to run [Name]?",
      allowResubmit: true,
      condition: () => canWriteScheduler,
    },
{
      label: "Edit Job",
      pinned: true,
      customFunction:
        drawerHandlers.openEditDrawer ||
        ((row) => {
          const next = schedulerJobUrl(row.RowKey);
          if (next) window.location.assign(next);
        }),
      multiPost: false,
      icon: <CippIcons.Edit />,
      color: "success",
      showInActionsMenu: true,
      noConfirm: true,
      condition: () => canWriteScheduler,
    },
{
      label: "Clone Job",
      customFunction:
        drawerHandlers.openCloneDrawer ||
        ((row) => {
          const next = schedulerJobUrl(row.RowKey, true);
          if (next) window.location.assign(next);
        }),
      multiPost: false,
      icon: <CippIcons.CopyAll />,
      color: "success",
      showInActionsMenu: true,
      noConfirm: true,
      condition: () => canWriteScheduler,
    },
{
      label: "Delete Job",
      category: "danger",
      icon: <CippIcons.Delete />,
      type: "POST",
      url: "/api/RemoveScheduledItem",
      data: { id: "RowKey" },
      confirmText: "Are you sure you want to delete this job?",
      multiPost: false,
      condition: () => canWriteScheduler,
    },
].filter((action) => !hideActions.includes(action.label));
};

export default CippScheduledTaskActions;
