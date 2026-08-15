import { useEffect, useMemo, useCallback, useState } from "react";
import { useRouter } from "next/router";
import { useForm } from "react-hook-form";
import { Layout as DashboardLayout } from "../../../../layouts/index.js";
import { useSettings } from "../../../../hooks/use-settings";
import { ApiGetCall, ApiPostCall } from "../../../../api/ApiCall";
import countryList from "../../../../data/countryList.json";
import { Grid } from "@mui/system";
import CippFormComponent from "../../../../components/CippComponents/CippFormComponent";
import {
  Alert,
  Avatar,
  Button,
  Chip,
  CircularProgress,
  Container,
  Divider,
  Paper,
  Tooltip,
  Typography,
} from "@mui/material";
import { alpha } from "@mui/material/styles";
import { Box, Stack } from "@mui/system";
import {
  ArrowBack,
  Email,
  Person,
  Business,
  Phone,
  Smartphone,
  LocationOn,
  Work,
  Badge,
  CloudSync,
  Save,
  Language,
} from "@mui/icons-material";
import Link from "next/link";
import { getInitials, stringToColor } from "../../../../utils/get-initials";

const countryLookup = new Map(countryList.map((country) => [country.Name, country.Code]));

const EditContact = () => {
  const tenantDomain = useSettings().currentTenant;
  const router = useRouter();
  const { id } = router.query;

  const contactInfo = ApiGetCall({
    url: `/api/ListContacts?tenantFilter=${tenantDomain}&id=${id}`,
    queryKey: `ListContacts-${id}`,
    waiting: !!id,
  });

  const saveProperties = ApiPostCall({
    relatedQueryKeys: [`ListContacts-${id}`],
  });

  const defaultFormValues = useMemo(
    () => ({
      displayName: "",
      firstName: "",
      lastName: "",
      email: "",
      hidefromGAL: false,
      streetAddress: "",
      postalCode: "",
      city: "",
      state: "",
      country: "",
      companyName: "",
      mobilePhone: "",
      businessPhone: "",
      jobTitle: "",
      website: "",
      mailTip: "",
    }),
    []
  );

  const formControl = useForm({
    mode: "onChange",
    defaultValues: defaultFormValues,
  });

  const processedContactData = useMemo(() => {
    if (!contactInfo.isSuccess || !contactInfo.data) return null;
    const contact = Array.isArray(contactInfo.data) ? contactInfo.data[0] : contactInfo.data;
    if (!contact) return null;

    const address = contact.addresses?.[0] || {};
    // A single phone may be serialized as a bare object rather than an array
    const phones = Array.isArray(contact.phones)
      ? contact.phones
      : contact.phones
        ? [contact.phones]
        : [];
    const phoneMap = new Map(phones.map((p) => [p.type, p.number]));

    return {
      displayName: contact.displayName || "",
      firstName: contact.givenName || "",
      lastName: contact.surname || "",
      email: contact.mail || "",
      hidefromGAL: contact.hidefromGAL || false,
      streetAddress: address.street || "",
      postalCode: address.postalCode || "",
      city: address.city || "",
      state: address.state || "",
      country: address.countryOrRegion ? countryLookup.get(address.countryOrRegion) || "" : "",
      companyName: contact.companyName || "",
      mobilePhone: phoneMap.get("mobile") || "",
      businessPhone: phoneMap.get("business") || "",
      jobTitle: contact.jobTitle || "",
      website: contact.website || "",
      mailTip: contact.mailTip || "",
    };
  }, [contactInfo.isSuccess, contactInfo.data]);

  const resetForm = useCallback(() => {
    if (processedContactData) {
      formControl.reset(processedContactData);
    }
  }, [processedContactData, formControl]);

  useEffect(() => {
    resetForm();
  }, [resetForm]);

  const contact = useMemo(() => {
    if (!contactInfo.data) return null;
    return Array.isArray(contactInfo.data) ? contactInfo.data[0] : contactInfo.data;
  }, [contactInfo.data]);

  const handleSaveProperties = useCallback(
    (values) => {
      saveProperties.mutate({
        url: "/api/EditContact",
        data: {
          tenantID: tenantDomain,
          ContactID: contact?.id,
          DisplayName: values.displayName,
          hidefromGAL: values.hidefromGAL,
          email: values.email,
          FirstName: values.firstName,
          LastName: values.lastName,
          Title: values.jobTitle,
          StreetAddress: values.streetAddress,
          PostalCode: values.postalCode,
          City: values.city,
          State: values.state,
          CountryOrRegion: values.country?.value || values.country,
          Company: values.companyName,
          // Explicit nulls so the API can clear phone values that were un-set
          mobilePhone: values.mobilePhone || null,
          phone: values.businessPhone || null,
          website: values.website,
          mailTip: values.mailTip,
        },
      });
    },
    [tenantDomain, contact, saveProperties]
  );

  if (!id || !tenantDomain) {
    return (
      <Container maxWidth={false} sx={{ py: 4 }}>
        <Button component={Link} href="/email/administration/contacts" startIcon={<ArrowBack />} sx={{ mb: 2 }}>
          Back to Contacts
        </Button>
        <Alert severity="warning">No contact selected. Please select a contact from the list.</Alert>
      </Container>
    );
  }

  if (contactInfo.isLoading) {
    return (
      <Container maxWidth={false} sx={{ py: 4 }}>
        <Button component={Link} href="/email/administration/contacts" startIcon={<ArrowBack />} sx={{ mb: 2 }}>
          Back to Contacts
        </Button>
        <Box sx={{ display: "flex", justifyContent: "center", py: 8 }}>
          <CircularProgress />
        </Box>
      </Container>
    );
  }

  if (contactInfo.isError || !contact) {
    return (
      <Container maxWidth={false} sx={{ py: 4 }}>
        <Button component={Link} href="/email/administration/contacts" startIcon={<ArrowBack />} sx={{ mb: 2 }}>
          Back to Contacts
        </Button>
        <Alert severity="error">Failed to load contact details. Please try again.</Alert>
      </Container>
    );
  }

  const isDirSynced = contact.onPremisesSyncEnabled || contact.IsDirSynced;

  return (
    <Container maxWidth={false} sx={{ py: 4 }}>
      <Stack spacing={2}>
        <Button
          component={Link}
          href="/email/administration/contacts"
          startIcon={<ArrowBack />}
          sx={{ alignSelf: "flex-start" }}
        >
          Back to Contacts
        </Button>

        {isDirSynced && (
          <Alert severity="warning" icon={<CloudSync />}>
            This contact is synced from on-premises Active Directory. Some properties may not be editable.
          </Alert>
        )}

        {/* Hero Section */}
        <Paper
          elevation={0}
          sx={{
            p: 3,
            borderRadius: 2,
            background: `linear-gradient(135deg, ${alpha("#1976d2", 0.12)} 0%, ${alpha("#1976d2", 0.04)} 100%)`,
            borderLeft: "4px solid #1976d2",
          }}
        >
          <Stack direction="row" spacing={2} alignItems="center">
            <Avatar
              sx={{
                bgcolor: stringToColor(contact.displayName || "C"),
                width: 56,
                height: 56,
                fontSize: "1.25rem",
                fontWeight: 600,
              }}
            >
              {getInitials(contact.displayName || "Contact")}
            </Avatar>
            <Box sx={{ flex: 1, minWidth: 0 }}>
              <Typography variant="h6" sx={{ fontWeight: 700, mb: 0.5 }}>
                {contact.displayName || "Unknown Contact"}
              </Typography>
              <Typography variant="body2" color="text.secondary" noWrap sx={{ mb: 1 }}>
                {contact.mail || contact.WindowsEmailAddress}
              </Typography>
              <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
                <Chip icon={<Person fontSize="small" />} label="Contact" size="small" color="primary" variant="outlined" />
                {isDirSynced && (
                  <Tooltip title="Synced from on-premises Active Directory">
                    <Chip icon={<CloudSync fontSize="small" />} label="On-Prem Synced" size="small" color="info" variant="outlined" />
                  </Tooltip>
                )}
                {contact.companyName && (
                  <Chip icon={<Business fontSize="small" />} label={contact.companyName} size="small" variant="outlined" />
                )}
                {contact.jobTitle && (
                  <Chip icon={<Work fontSize="small" />} label={contact.jobTitle} size="small" variant="outlined" />
                )}
              </Stack>
            </Box>
          </Stack>
        </Paper>

        {/* Properties Form */}
        <Paper variant="outlined" sx={{ p: 3, borderRadius: 2 }}>
          <Stack direction="row" justifyContent="space-between" alignItems="center" sx={{ mb: 2 }}>
            <Typography variant="subtitle1" sx={{ fontWeight: 600 }}>
              Contact Properties
            </Typography>
            <Button
              variant="contained"
              startIcon={saveProperties.isPending ? <CircularProgress size={16} color="inherit" /> : <Save />}
              onClick={formControl.handleSubmit(handleSaveProperties)}
              disabled={saveProperties.isPending || isDirSynced}
            >
              {saveProperties.isPending ? "Saving..." : "Save Properties"}
            </Button>
          </Stack>

          {saveProperties.isSuccess && (
            <Alert severity="success" sx={{ mb: 2 }}>
              Contact properties saved successfully.
            </Alert>
          )}
          {saveProperties.isError && (
            <Alert severity="error" sx={{ mb: 2 }}>
              Failed to save contact properties. Please try again.
            </Alert>
          )}

          <Grid container spacing={2}>
            <Grid size={{ md: 10, xs: 12 }}>
              <CippFormComponent type="textField" label="Display Name" name="displayName" formControl={formControl} validators={{ required: "Display Name is required" }} />
            </Grid>
            <Grid size={{ md: 5, xs: 12 }}>
              <CippFormComponent type="textField" label="First Name" name="firstName" formControl={formControl} />
            </Grid>
            <Grid size={{ md: 5, xs: 12 }}>
              <CippFormComponent type="textField" label="Last Name" name="lastName" formControl={formControl} />
            </Grid>

            <Divider sx={{ my: 1, width: "100%" }} />

            <Grid size={{ md: 8, xs: 12 }}>
              <CippFormComponent
                type="textField"
                label="Email"
                name="email"
                formControl={formControl}
                validators={{
                  required: "Email is required",
                  pattern: { value: /^[^\s@]+@[^\s@]+\.[^\s@]+$/, message: "Please enter a valid email address" },
                }}
              />
            </Grid>
            <Grid size={{ md: 4, xs: 12 }}>
              <CippFormComponent type="switch" label="Hidden from Global Address List" name="hidefromGAL" formControl={formControl} />
            </Grid>

            <Divider sx={{ my: 1, width: "100%" }} />

            <Grid size={{ md: 6, xs: 12 }}>
              <CippFormComponent type="textField" label="Company Name" name="companyName" formControl={formControl} />
            </Grid>
            <Grid size={{ md: 6, xs: 12 }}>
              <CippFormComponent type="textField" label="Job Title" name="jobTitle" formControl={formControl} />
            </Grid>

            <Divider sx={{ my: 1, width: "100%" }} />

            <Grid size={{ md: 12, xs: 12 }}>
              <CippFormComponent type="textField" label="Street Address" name="streetAddress" formControl={formControl} />
            </Grid>
            <Grid size={{ md: 4, xs: 12 }}>
              <CippFormComponent type="textField" label="City" name="city" formControl={formControl} />
            </Grid>
            <Grid size={{ md: 4, xs: 12 }}>
              <CippFormComponent type="textField" label="Postal Code" name="postalCode" formControl={formControl} />
            </Grid>
            <Grid size={{ md: 4, xs: 12 }}>
              <CippFormComponent
                type="autoComplete"
                label="Country"
                name="country"
                multiple={false}
                creatable={false}
                options={countryList.map(({ Code, Name }) => ({ label: Name, value: Code }))}
                formControl={formControl}
              />
            </Grid>

            <Divider sx={{ my: 1, width: "100%" }} />

            <Grid size={{ md: 6, xs: 12 }}>
              <CippFormComponent type="textField" label="Mobile Phone" name="mobilePhone" formControl={formControl} />
            </Grid>
            <Grid size={{ md: 6, xs: 12 }}>
              <CippFormComponent type="textField" label="Business Phone" name="businessPhone" formControl={formControl} />
            </Grid>
          </Grid>
        </Paper>
      </Stack>
    </Container>
  );
};

EditContact.getLayout = (page) => <DashboardLayout>{page}</DashboardLayout>;

export default EditContact;
