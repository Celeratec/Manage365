import { useCallback } from "react";
import { usePathname } from "next/navigation";
import { useRouter } from "next/router";
import PropTypes from "prop-types";
import ArrowLeftIcon from "@heroicons/react/24/outline/ArrowLeftIcon";
import {
  Box,
  Button,
  Container,
  Divider,
  Skeleton,
  Stack,
  SvgIcon,
  Tab,
  Tabs,
  Typography,
} from "@mui/material";
import { ActionsMenu } from "../components/actions-menu";
import { useMediaQuery } from "@mui/material";
import { CippCopyToClipBoard } from "../components/CippComponents/CippCopyToClipboard";
import { getIconByName } from "../utils/icon-registry";

export const HeaderedTabbedLayout = (props) => {
  const {
    children,
    tabOptions,
    title,
    subtitle,
    actions,
    actionsData,
    isFetching = false,
    backUrl,
    copyItems,
  } = props;

  const mdDown = useMediaQuery((theme) => theme.breakpoints.down("md"));
  const smDown = useMediaQuery((theme) => theme.breakpoints.down("sm"));
  const router = useRouter();
  const pathname = usePathname();
  const queryParams = router.query;
  const handleTabsChange = useCallback(
    (event, value) => {
      //if we have query params, we need to append them to the new path
      router.push(
        {
          pathname: value,
          query: queryParams,
        },
        undefined,
        { shallow: true }
      );
    },
    [router]
  );

  const currentTab = tabOptions.find((option) => option.path === pathname);

  return (
    <Box
      sx={{
        flexGrow: 1,
        pb: 4,
      }}
    >
      <Container maxWidth="xl" sx={{ height: "100%", px: smDown ? 2 : 3 }}>
        <Stack spacing={1} sx={{ height: "100%" }}>
          <Stack spacing={smDown ? 1 : 2}>
            <Stack
              alignItems={smDown ? "stretch" : "flex-start"}
              direction={smDown ? "column" : "row"}
              justifyContent="space-between"
              spacing={1}
            >
              <Stack spacing={1} sx={{ minWidth: 0, flex: 1 }}>
                <Stack
                  alignItems="center"
                  direction="row"
                  spacing={1}
                  justifyContent="space-between"
                >
                  <Typography 
                    variant={mdDown ? "h6" : "h4"}
                    sx={{
                      wordBreak: "break-word",
                      overflowWrap: "break-word",
                    }}
                  >
                    {title}
                  </Typography>
                  {title && !isFetching && (
                    <CippCopyToClipBoard text={title} type="button" />
                  )}
                  {!isFetching && copyItems?.map((item, index) => (
                    item.text && (
                      <CippCopyToClipBoard key={index} text={item.text} type="chip" />
                    )
                  ))}
                </Stack>
                {isFetching ? (
                  <Skeleton variant="text" width={200} />
                ) : (
                  subtitle && (
                    <Stack 
                      alignItems={smDown ? "flex-start" : "center"} 
                      flexWrap="wrap" 
                      direction={smDown ? "column" : "row"} 
                      spacing={smDown ? 1 : 2}
                      sx={{ gap: smDown ? 1 : 2 }}
                    >
                      {subtitle.map((item, index) =>
                        item.component ? (
                          <Box key={index} sx={{ maxWidth: "100%", overflow: "hidden" }}>
                            {item.component}
                          </Box>
                        ) : (
                          <Stack 
                            key={index} 
                            alignItems="center" 
                            direction="row" 
                            spacing={1}
                            sx={{ 
                              minWidth: 0,
                              maxWidth: "100%",
                              "& .MuiTypography-root": {
                                overflow: "hidden",
                                textOverflow: "ellipsis",
                              }
                            }}
                          >
                            <SvgIcon fontSize="small" sx={{ flexShrink: 0 }}>{item.icon}</SvgIcon>
                            <Typography color="text.secondary" variant="body2" noWrap={smDown}>
                              {item.text}
                            </Typography>
                          </Stack>
                        )
                      )}
                    </Stack>
                  )
                )}
              </Stack>
              {actions && actions.length > 0 && (
                <Box sx={{ flexShrink: 0, alignSelf: smDown ? "flex-end" : "flex-start", mt: smDown ? 1 : 0 }}>
                  <ActionsMenu actions={actions} data={actionsData} disabled={isFetching} />
                </Box>
              )}
            </Stack>
            <div>
              <Tabs 
                onChange={handleTabsChange} 
                value={currentTab?.path} 
                variant="scrollable"
                scrollButtons="auto"
                allowScrollButtonsMobile
                sx={{
                  minHeight: smDown ? 40 : 48,
                  "& .MuiTab-root": {
                    minHeight: smDown ? 40 : 48,
                    py: smDown ? 1 : 1.5,
                    px: smDown ? 1.5 : 2,
                    fontSize: smDown ? "0.8rem" : "0.875rem",
                  },
                }}
              >
                {tabOptions.map((option) => {
                  const icon = getIconByName(option.icon, { fontSize: "small" });
                  const iconPosition = option.iconPosition ?? "start";
                  const compactIcon = icon && ["end", "start"].includes(iconPosition);

                  return (
                    <Tab
                      key={option.path}
                      label={option.label}
                      value={option.path}
                      icon={icon ?? undefined}
                      iconPosition={icon ? iconPosition : undefined}
                      sx={compactIcon ? { minHeight: smDown ? 40 : 48, py: smDown ? 1 : 1.5 } : undefined}
                    />
                  );
                })}
              </Tabs>
              <Divider />
            </div>
          </Stack>
          <Box
            sx={
              !mdDown && {
                flexGrow: 1,
                overflow: "auto",
                height: "calc(100vh - 350px)",
              }
            }
          >
            {children}
          </Box>
        </Stack>
      </Container>
    </Box>
  );
};

HeaderedTabbedLayout.propTypes = {
  children: PropTypes.node,
  tabOptions: PropTypes.arrayOf(
    PropTypes.shape({
      label: PropTypes.string.isRequired,
      path: PropTypes.string.isRequired,
    })
  ).isRequired,
  title: PropTypes.string.isRequired,
  subtitle: PropTypes.arrayOf(
    PropTypes.shape({
      icon: PropTypes.node.isRequired,
      text: PropTypes.string.isRequired,
    })
  ),
  actions: PropTypes.arrayOf(
    PropTypes.shape({
      label: PropTypes.string.isRequired,
      handler: PropTypes.func.isRequired,
    })
  ),
  isFetching: PropTypes.bool,
};
