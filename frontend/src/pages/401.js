import { Box, Container, Stack, Typography, Paper, Button } from "@mui/material";
import Head from "next/head";
import { Layout as DashboardLayout } from "../layouts/index.js";
import { alpha, useTheme } from "@mui/material/styles";
import { Lock, Home, ArrowBack } from "@mui/icons-material";
import { useRouter } from "next/router";

const Page = () => {
  const theme = useTheme();
  const router = useRouter();

  return (
    <>
      <DashboardLayout>
        <Head>
          <title>401 - Unauthorized</title>
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
          <Container maxWidth="sm">
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
                {/* Icon */}
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
                  <Lock sx={{ fontSize: 40, color: "error.main" }} />
                </Box>

                {/* Title */}
                <Typography variant="h4" fontWeight={600} color="error.main">
                  Error 401
                </Typography>

                {/* Subtitle */}
                <Typography variant="h6" color="text.primary">
                  Unauthorized Access
                </Typography>

                {/* Description */}
                <Typography variant="body2" color="text.secondary" sx={{ maxWidth: 400 }}>
                  You don't have permission to access this page. Please check your credentials 
                  or contact your administrator if you believe this is an error.
                </Typography>

                {/* Action Buttons */}
                <Stack direction="row" spacing={2}>
                  <Button
                    variant="contained"
                    color="primary"
                    startIcon={<Home />}
                    href="/"
                  >
                    Go to Homepage
                  </Button>
                  <Button
                    variant="outlined"
                    startIcon={<ArrowBack />}
                    onClick={() => router.back()}
                  >
                    Go Back
                  </Button>
                </Stack>
              </Stack>
            </Paper>
          </Container>
        </Box>
      </DashboardLayout>
    </>
  );
};

export default Page;
