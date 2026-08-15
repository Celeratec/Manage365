import { Box, Container, Stack, Typography, Paper, Button, Alert, Collapse, IconButton } from "@mui/material";
import { Grid } from "@mui/system";
import Head from "next/head";
import { Layout as DashboardLayout } from "../layouts/index.js";
import { useEffect, useState } from "react";
import { useRouter } from "next/router.js";
import { alpha, useTheme } from "@mui/material/styles";
import { Error as ErrorIcon, Refresh, ExpandMore, ExpandLess, ContentCopy, Check } from "@mui/icons-material";

const Error500 = (props) => {
  const theme = useTheme();
  const router = useRouter();
  const [showDetails, setShowDetails] = useState(false);
  const [copied, setCopied] = useState(false);

  // When we browse away from the page we want to reset the error boundary
  // This will prevent the error from showing on other pages
  useEffect(() => {
    return () => {
      props.resetErrorBoundary();
    };
  }, [router]);

  const errorMessage = props.error?.message || "An unexpected error occurred";
  const errorStack = props.error?.stack || "";

  const handleCopyError = () => {
    const errorText = `Error: ${errorMessage}\n\nStack Trace:\n${errorStack}`;
    navigator.clipboard.writeText(errorText).then(() => {
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    });
  };

  return (
    <>
      <DashboardLayout>
        <Head>
          <title>500 - Error</title>
        </Head>
        <Box
          sx={{
            flexGrow: 1,
            py: 4,
            minHeight: "80vh",
            display: "flex",
            alignItems: "center",
          }}
        >
          <Container maxWidth="md">
            <Paper
              elevation={0}
              sx={{
                p: 4,
                borderRadius: 2,
                border: `1px solid ${alpha(theme.palette.error.main, 0.2)}`,
                bgcolor: alpha(theme.palette.error.main, 0.02),
              }}
            >
              <Stack spacing={3} alignItems="center" textAlign="center">
                {/* Error Icon */}
                <Box
                  sx={{
                    width: 80,
                    height: 80,
                    borderRadius: "50%",
                    bgcolor: alpha(theme.palette.error.main, 0.1),
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "center",
                  }}
                >
                  <ErrorIcon sx={{ fontSize: 40, color: "error.main" }} />
                </Box>

                {/* Title */}
                <Typography variant="h4" fontWeight={600} color="error.main">
                  Error 500
                </Typography>

                {/* Subtitle */}
                <Typography variant="h6" color="text.primary">
                  Something went wrong
                </Typography>

                {/* Error Message Box */}
                <Alert 
                  severity="error" 
                  sx={{ 
                    width: "100%",
                    "& .MuiAlert-message": {
                      width: "100%",
                    },
                  }}
                >
                  <Typography
                    variant="body2"
                    sx={{
                      wordBreak: "break-word",
                      overflowWrap: "break-word",
                      whiteSpace: "pre-wrap",
                      fontFamily: "monospace",
                      fontSize: "0.85rem",
                    }}
                  >
                    {errorMessage}
                  </Typography>
                </Alert>

                {/* Help Text */}
                <Typography variant="body2" color="text.secondary">
                  An error occurred while processing your request. You can try again or go back to the previous page.
                </Typography>

                {/* Action Buttons */}
                <Stack direction="row" spacing={2}>
                  <Button
                    variant="contained"
                    color="primary"
                    startIcon={<Refresh />}
                    onClick={() => props.resetErrorBoundary()}
                  >
                    Try Again
                  </Button>
                  <Button
                    variant="outlined"
                    onClick={() => router.back()}
                  >
                    Go Back
                  </Button>
                </Stack>

                {/* Technical Details Toggle */}
                {errorStack && (
                  <Box sx={{ width: "100%", mt: 2 }}>
                    <Button
                      size="small"
                      onClick={() => setShowDetails(!showDetails)}
                      endIcon={showDetails ? <ExpandLess /> : <ExpandMore />}
                      sx={{ color: "text.secondary" }}
                    >
                      {showDetails ? "Hide" : "Show"} Technical Details
                    </Button>

                    <Collapse in={showDetails}>
                      <Paper
                        variant="outlined"
                        sx={{
                          mt: 2,
                          p: 2,
                          bgcolor: alpha(theme.palette.background.default, 0.5),
                          maxHeight: 300,
                          overflow: "auto",
                          position: "relative",
                        }}
                      >
                        <IconButton
                          size="small"
                          onClick={handleCopyError}
                          sx={{
                            position: "absolute",
                            top: 8,
                            right: 8,
                            bgcolor: "background.paper",
                            "&:hover": {
                              bgcolor: "action.hover",
                            },
                          }}
                        >
                          {copied ? (
                            <Check sx={{ fontSize: 16, color: "success.main" }} />
                          ) : (
                            <ContentCopy sx={{ fontSize: 16 }} />
                          )}
                        </IconButton>
                        <Typography
                          component="pre"
                          variant="body2"
                          sx={{
                            fontFamily: "monospace",
                            fontSize: "0.75rem",
                            whiteSpace: "pre-wrap",
                            wordBreak: "break-word",
                            overflowWrap: "break-word",
                            m: 0,
                            pr: 4,
                            color: "text.secondary",
                          }}
                        >
                          {errorStack}
                        </Typography>
                      </Paper>
                    </Collapse>
                  </Box>
                )}
              </Stack>
            </Paper>
          </Container>
        </Box>
      </DashboardLayout>
    </>
  );
};

export default Error500;
