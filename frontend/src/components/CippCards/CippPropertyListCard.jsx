import {
  Card,
  CardContent,
  CardHeader,
  Divider,
  Skeleton,
  SvgIcon,
  Stack,
  CardActions,
  Box,
  Typography,
  Collapse,
  IconButton,
  useMediaQuery,
  useTheme,
} from "@mui/material";
import KeyboardArrowUpIcon from "@mui/icons-material/KeyboardArrowUp";
import KeyboardArrowDownIcon from "@mui/icons-material/KeyboardArrowDown";
import { ActionList } from "../../components/action-list";
import { ActionListItem } from "../../components/action-list-item";
import { PropertyList } from "../../components/property-list";
import { PropertyListItem } from "../../components/property-list-item";
import { useDialog } from "../../hooks/use-dialog";
import { CippApiDialog } from "../CippComponents/CippApiDialog";
import { CippActionMenu } from "../CippComponents/CippActionMenu";
import { useState } from "react";
import { getIconByName } from "../../utils/icon-registry";

export const CippPropertyListCard = (props) => {
  const {
    align = "vertical",
    actionItems = [],
    propertyItems = [],
    isFetching,
    title,
    actionButton,
    copyItems = false,
    data,
    layout = "single",
    showDivider = true,
    cardButton,
    cardSx = { width: "100%", height: "100%" },
    useImprovedActions = true, // New prop to enable improved action menu
    actionsCollapsedByDefault = false,
    ...other
  } = props;
  const theme = useTheme();
  const smDown = useMediaQuery(theme.breakpoints.down("sm"));
  const createDialog = useDialog();
  const [actionData, setActionData] = useState({ data: {}, action: {}, ready: false });
  const [actionsOpen, setActionsOpen] = useState(!actionsCollapsedByDefault);

  const half = Math.ceil(propertyItems.length / 2);
  const firstHalf = propertyItems.slice(0, half);
  const secondHalf = propertyItems.slice(half, propertyItems.length);

  const isLabelPresent = (item) => {
    return item?.label === "" || item?.label === undefined || item?.label === null;
  };

  const setPadding = isLabelPresent ? { py: 0.5, px: 3 } : { py: 1.5, px: 3 };
  const handleActionDisabled = (row, action) => {
    if (action?.condition) {
      return !action.condition(row);
    }
    return false;
  };

  const renderActionIcon = (icon) => {
    if (!icon) return null;
    if (typeof icon === "string") return getIconByName(icon, { fontSize: "small" });
    return <SvgIcon fontSize="small">{icon}</SvgIcon>;
  };

  const hasInteraction = actionItems?.length > 0 || !!actionButton || !!cardButton;

  return (
    <>
      <Card 
        sx={{
          transition: "all 150ms ease-out",
          ...(hasInteraction && {
            "&:hover": {
              boxShadow: theme.shadows[4],
            },
          }),
          ...cardSx,
        }} 
        {...other}
      >
        <CardHeader action={actionButton} title={title} />
        <CardContent sx={{ p: 0, marginBottom: "auto" }}>
          <Divider />

          {layout === "single" ? (
            <PropertyList>
              {isFetching ? (
                <>
                  {Array.from({ length: propertyItems?.length || 3 }).map((_, index) => (
                    <PropertyListItem
                      key={`${index}-skeleton-PropertyListOffCanvas`}
                      align={align}
                      label={propertyItems?.[index]?.label || ""}
                      value={<Skeleton width={280} />}
                      sx={setPadding}
                    />
                  ))}
                </>
              ) : (
                propertyItems.map((item, index) => (
                  <PropertyListItem
                    align={align}
                    divider={showDivider}
                    copyItems={copyItems}
                    key={`${index}-index-PropertyListOffCanvas`}
                    sx={setPadding}
                    {...item}
                  />
                ))
              )}
            </PropertyList>
          ) : (
            // Two-column layout
            <Stack
              direction={{
                xs: "column",
                md: "row",
              }}
              sx={{
                "& > *": {
                  width: {
                    md: "50%",
                  },
                },
              }}
            >
              <PropertyList>
                {isFetching ? (
                  <>
                    {Array.from({ length: Math.max(1, firstHalf?.length || 1) }).map((_, index) => (
                      <PropertyListItem
                        key={`${index}-skeleton-first`}
                        align={align}
                        divider={showDivider}
                        label=""
                        value={<Skeleton width={280} />}
                      />
                    ))}
                  </>
                ) : (
                  firstHalf.map((item, index) => (
                    <PropertyListItem
                      align={align}
                      divider={showDivider}
                      copyItems={copyItems}
                      key={`${index}-index-PropertyListOffCanvas`}
                      {...item}
                    />
                  ))
                )}
              </PropertyList>
              <PropertyList>
                {isFetching ? (
                  <>
                    {Array.from({ length: Math.max(1, secondHalf?.length || 1) }).map(
                      (_, index) => (
                        <PropertyListItem
                          key={`${index}-skeleton-second`}
                          align={align}
                          divider={showDivider}
                          label=""
                          value={<Skeleton width={280} />}
                        />
                      )
                    )}
                  </>
                ) : (
                  secondHalf.map((item, index) => (
                    <PropertyListItem
                      align={align}
                      divider={showDivider}
                      copyItems={copyItems}
                      key={`${index}-index-PropertyListOffCanvas`}
                      {...item}
                    />
                  ))
                )}
              </PropertyList>
            </Stack>
          )}
        </CardContent>
        {/* Actions Section */}
        {actionItems?.length > 0 && (
          useImprovedActions ? (
            <Box sx={{ p: smDown ? 1.5 : 2 }}>
              <Box sx={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
                <Typography
                  variant="subtitle2"
                  color="text.secondary"
                  sx={{ fontWeight: 600 }}
                >
                  Actions
                </Typography>
                <IconButton
                  size="small"
                  onClick={() => setActionsOpen((open) => !open)}
                  aria-label={actionsOpen ? "Collapse actions" : "Expand actions"}
                >
                  {actionsOpen ? <KeyboardArrowUpIcon /> : <KeyboardArrowDownIcon />}
                </IconButton>
              </Box>
              <Collapse in={actionsOpen} timeout="auto" unmountOnExit>
                <Box sx={{ mt: 1.5 }}>
                  <CippActionMenu
                    actions={actionItems}
                    data={data}
                    showSearch={actionItems.length > 6}
                    showCategories={actionItems.length > 4}
                  />
                </Box>
              </Collapse>
            </Box>
          ) : (
            <>
              <ActionList>
                {actionItems.map((item, index) => (
                  <ActionListItem
                    key={`${item.label}-${index}-ActionList-OffCanvas`}
                    icon={renderActionIcon(item.icon)}
                    label={item.label}
                    onClick={() => {
                      setActionData({
                        data: data,
                        action: item,
                        ready: true,
                      });
                      if (item?.noConfirm) {
                        item.customFunction(item, data, {});
                      } else {
                        createDialog.handleOpen();
                      }
                    }}
                    disabled={handleActionDisabled(data, item)}
                  />
                ))}
              </ActionList>

              {actionData.ready && (
                <CippApiDialog
                  createDialog={createDialog}
                  title="Confirmation"
                  fields={actionData.action?.fields}
                  api={actionData.action}
                  row={actionData.data}
                />
              )}
            </>
          )
        )}
        {cardButton && (
          <>
            <Divider />
            <CardActions>{cardButton}</CardActions>
          </>
        )}
      </Card>
    </>
  );
};
