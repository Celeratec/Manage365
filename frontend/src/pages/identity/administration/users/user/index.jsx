import { Layout as DashboardLayout } from '../../../../../layouts/index'
import { CippIcons } from '../../../../../utils/icon-registry'
import { useSettings } from '../../../../../hooks/use-settings'
import { useRouter } from 'next/router'
import { ApiGetCall, ApiPostCall } from '../../../../../api/ApiCall'
import { HeaderedTabbedLayout } from '../../../../../layouts/HeaderedTabbedLayout'
import tabOptions from './tabOptions'
import { CippCopyToClipBoard } from '../../../../../components/CippComponents/CippCopyToClipboard'
import { Box, Stack } from '@mui/system'
import { Grid } from '@mui/system'
import { CippUserInfoCard } from '../../../../../components/CippCards/CippUserInfoCard'
import { CippUserSwitcher } from '../../../../../components/CippComponents/CippUserSwitcher'
import { SvgIcon, Typography } from '@mui/material'
import { CippBannerListCard } from '../../../../../components/CippCards/CippBannerListCard'
import { CippTimeAgo } from '../../../../../components/CippComponents/CippTimeAgo'
import { Fragment, useEffect, useState, useRef, useMemo, useCallback } from 'react'
import { useCippUserActions } from '../../../../../components/CippComponents/CippUserActions'
import { useCippRoleAssignmentActions } from '../../../../../components/CippComponents/CippRoleAssignmentActions'
import { CippDataTable } from '../../../../../components/CippTable/CippDataTable'
import dynamic from 'next/dynamic'
const CippMap = dynamic(
  () => import('../../../../../components/CippComponents/CippMap'),
  {
    ssr: false,
  }
)
import { Badge, Devices, Group, Login, PersonAdd, Security } from '@mui/icons-material'
import { Divider } from '@mui/material'
import { PencilIcon } from '@heroicons/react/24/outline'
import { getGroupTypeLabel } from '../../../../../utils/group-types'
import {
  Button,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  IconButton,
  CircularProgress,
} from "@mui/material";
import { Close } from "@mui/icons-material";
import { useForm, useWatch } from "react-hook-form";
import CippFormComponent from "../../../../../components/CippComponents/CippFormComponent";
import { CippApiResults } from "../../../../../components/CippComponents/CippApiResults";
import gdaproles from "../../../../../data/GDAPRoles.json";
import { CippPropertyList } from "../../../../../components/CippComponents/CippPropertyList";
import { CippCodeBlock } from "../../../../../components/CippComponents/CippCodeBlock";
import { CippHead } from "../../../../../components/CippComponents/CippHead";
import { CippUserDevicesSection } from "../../../../../components/CippComponents/CippUserDevicesSection";
import { usePermissions } from '../../../../../hooks/use-permissions'
import { useDialog } from '../../../../../hooks/use-dialog'
import { CippApiDialog } from '../../../../../components/CippComponents/CippApiDialog'

// The only six values Graph accepts for userPreferredMethodForSecondaryAuthentication.
// Shared by the "Set Default" dropdown, the default marker, and the system-preferred alert.
const MFA_PREF_LABELS = {
  push: 'Microsoft Authenticator (push)',
  oath: 'Authenticator app or hardware token (OATH code)',
  sms: 'SMS',
  voiceMobile: 'Voice call - mobile',
  voiceAlternateMobile: 'Voice call - alternate mobile',
  voiceOffice: 'Voice call - office',
}

// systemPreferredAuthenticationMethod is undocumented on signInPreferences and comes
// back in the legacy MFA vocabulary ("SoftwareOTP"), NOT the six values above, so it
// maps to @odata.type suffixes rather than to a preference value.
// Keyed lowercase so a casing change upstream doesn't silently break matching; an
// unrecognised value simply marks no card.
const SYSTEM_PREF_METHOD_TYPES = {
  phoneappnotification: [
    'microsoftAuthenticatorAuthenticationMethod',
    'passwordlessMicrosoftAuthenticatorAuthenticationMethod',
  ],
  phoneappotp: [
    'microsoftAuthenticatorAuthenticationMethod',
    'softwareOathAuthenticationMethod',
  ],
  softwareotp: ['softwareOathAuthenticationMethod'],
  hardwareotp: ['hardwareOathAuthenticationMethod'],
  onewaysms: ['phoneAuthenticationMethod'],
  twowayvoicemobile: ['phoneAuthenticationMethod'],
  twowayvoicealternatemobile: ['phoneAuthenticationMethod'],
  twowayvoiceoffice: ['phoneAuthenticationMethod'],
  fido2: ['fido2AuthenticationMethod'],
  temporaryaccesspass: ['temporaryAccessPassAuthenticationMethod'],
  windowshelloforbusiness: ['windowsHelloForBusinessAuthenticationMethod'],
  qrcodepin: ['qrCodePinAuthenticationMethod'],
  externalmethod: ['externalAuthenticationMethod'],
}

// Keyed by the @odata.type suffix Graph returns. /authentication/methods is a
// polymorphic collection, so the identifying field differs per method type.
const MFA_METHOD_TYPES = {
  microsoftAuthenticatorAuthenticationMethod: {
    label: 'Microsoft Authenticator',
    icon: <CippIcons.PhoneIphone />,
    identifier: (method) => method.displayName || method.deviceTag,
  },
  passwordlessMicrosoftAuthenticatorAuthenticationMethod: {
    // Deprecated by Graph, but still present on users registered before the merge.
    label: 'Microsoft Authenticator (passwordless)',
    icon: <CippIcons.PhoneIphone />,
    identifier: (method) => method.displayName,
  },
  phoneAuthenticationMethod: {
    // SMS and voice are the same registration — phoneType is what separates them.
    label: 'Phone',
    icon: <CippIcons.Smartphone />,
    identifier: (method) =>
      method.phoneNumber && method.phoneType
        ? `${method.phoneNumber} (${method.phoneType})`
        : method.phoneNumber,
  },
  fido2AuthenticationMethod: {
    label: 'Passkey (FIDO2)',
    icon: <CippIcons.Key />,
    identifier: (method) => method.model || method.displayName,
  },
  softwareOathAuthenticationMethod: {
    // Any TOTP-capable app, not just Microsoft Authenticator — password managers included.
    label: 'Software OATH token',
    icon: <CippIcons.Dialpad />,
    identifier: (method) => method.displayName,
  },
  hardwareOathAuthenticationMethod: {
    // This type has no displayName; the serial number lives on the device
    // relationship, which Graph only returns when explicitly expanded.
    label: 'Hardware OATH token',
    icon: <CippIcons.Password />,
    identifier: (method) => method.device?.serialNumber,
  },
  emailAuthenticationMethod: {
    label: 'Email',
    icon: <CippIcons.Mail />,
    identifier: (method) => method.emailAddress,
  },
  windowsHelloForBusinessAuthenticationMethod: {
    label: 'Windows Hello for Business',
    icon: <CippIcons.Fingerprint />,
    identifier: (method) => method.displayName,
  },
  platformCredentialAuthenticationMethod: {
    label: 'Platform credential',
    icon: <CippIcons.Laptop />,
    identifier: (method) => method.displayName || method.platform,
  },
  temporaryAccessPassAuthenticationMethod: {
    label: 'Temporary Access Pass',
    icon: <CippIcons.Key />,
    identifier: () => null,
  },
  qrCodePinAuthenticationMethod: {
    // Only id and lastUsedDateTime come back on this type — nothing to identify it by.
    label: 'QR code',
    icon: <CippIcons.QrCode />,
    identifier: () => null,
  },
  externalAuthenticationMethod: {
    label: 'External provider',
    icon: <CippIcons.Language />,
    identifier: (method) => method.displayName,
  },
}

const getMethodType = (method) =>
  method['@odata.type']?.split('.').pop() || 'N/A'

// A method type Graph adds later still renders: raw suffix as label, generic icon.
const getMethodMeta = (method) =>
  MFA_METHOD_TYPES[getMethodType(method)] ?? {
    label: getMethodType(method),
    icon: <CippIcons.Check />,
    identifier: () => null,
  }

// Which of the six preference values this specific method can satisfy. Graph stores
// the default by method *type*, not by method id. A mobile number backs both SMS and
// voice; FIDO2/Hello/email/TAP back none, so they can never be the default.
const prefValuesForMethod = (method) => {
  const type = getMethodType(method)
  if (type === 'phoneAuthenticationMethod') {
    if (method.phoneType === 'mobile') return ['sms', 'voiceMobile']
    if (method.phoneType === 'alternateMobile') return ['voiceAlternateMobile']
    if (method.phoneType === 'office') return ['voiceOffice']
    return []
  }
  // The Authenticator app always shows a verification code alongside push, and Graph
  // does not surface that as a separate softwareOathAuthenticationMethod entity — so an
  // Authenticator registration backs 'oath' too. Omitting it left Authenticator-only
  // users unable to select a preference they can actually satisfy.
  if (
    type === 'microsoftAuthenticatorAuthenticationMethod' ||
    type === 'passwordlessMicrosoftAuthenticatorAuthenticationMethod'
  ) {
    return ['push', 'oath']
  }
  // The 'oath' preference covers both software and hardware OATH tokens.
  if (
    type === 'softwareOathAuthenticationMethod' ||
    type === 'hardwareOathAuthenticationMethod'
  ) {
    return ['oath']
  }
  return []
}

const SignInLogsDialog = ({ open, onClose, userId, tenantFilter }) => {
  return (
    <Dialog open={open} onClose={onClose} maxWidth="lg" fullWidth>
      <DialogTitle sx={{ py: 2 }}>
        Sign-In Logs
        <IconButton
          aria-label="close"
          onClick={onClose}
          sx={{ position: "absolute", right: 8, top: 8 }}
        >
          <CippIcons.Close />
        </IconButton>
      </DialogTitle>
      <DialogContent dividers>
        <CippDataTable
          noCard={true}
          title="Sign-In Logs"
          simpleColumns={[
            "createdDateTime",
            "status",
            "ipAddress",
            "clientAppUsed",
            "resourceDisplayName",
            "status.errorCode",
            "location",
          ]}
          api={{
            url: "/api/ListUserSigninLogs",
            data: {
              UserId: userId,
              tenantFilter: tenantFilter,
              top: 50,
            },
            queryKey: `ListSignIns-${userId}`,
          }}
        />
      </DialogContent>
    </Dialog>
  );
};

const AddRoleForm = ({ user, tenant, onClose, onSuccess, mutation }) => {
  const formControl = useForm({ mode: "onChange" });
  const assignmentType = useWatch({
    control: formControl.control,
    name: "assignmentType",
  });
  const assignmentTypeValue = assignmentType?.value || assignmentType;
  const isTemporary = assignmentTypeValue === "Temporary";

  const handleSubmit = formControl.handleSubmit((formData) => {
    const actionType = isTemporary ? "AddTemporary" : "Add";
    const roles = Array.isArray(formData.roles) ? formData.roles : [formData.roles];
    mutation.mutate(
      {
        url: "/api/ExecRoleAssignment",
        data: {
          tenantFilter: tenant,
          userId: user.id,
          userPrincipalName: user.userPrincipalName,
          displayName: user.displayName,
          roles: roles.map((r) => ({ label: r.label, value: r.value })),
          action: actionType,
          expiration: formData.expiration
            ? Math.floor(new Date(formData.expiration).getTime() / 1000)
            : undefined,
          reason: formData.reason || undefined,
        },
      },
      { onSuccess }
    );
  });

  return (
    <form onSubmit={handleSubmit}>
      <Stack spacing={2} sx={{ mt: 1 }}>
        <CippFormComponent
          type="autoComplete"
          name="roles"
          label="Select Admin Roles"
          multiple={true}
          creatable={false}
          formControl={formControl}
          options={gdaproles.map((role) => ({ label: role.Name, value: role.ObjectId }))}
          validators={{ required: "Please select at least one role" }}
        />
        <CippFormComponent
          type="radio"
          name="assignmentType"
          label="Assignment Type"
          formControl={formControl}
          options={[
            { label: "Permanent", value: "Permanent" },
            { label: "Temporary", value: "Temporary" },
          ]}
          validators={{ required: "Please select an assignment type" }}
        />
        {isTemporary && (
          <CippFormComponent
            type="datePicker"
            name="expiration"
            label="Expiration Date/Time"
            dateTimeType="datetime"
            formControl={formControl}
            validators={{ required: "Please select an expiration date" }}
          />
        )}
        <CippFormComponent
          type="textField"
          name="reason"
          label="Reason (optional)"
          formControl={formControl}
        />
        <CippApiResults apiObject={mutation} />
        <DialogActions sx={{ px: 0, pb: 0 }}>
          <Button onClick={onClose} disabled={mutation.isPending}>
            Cancel
          </Button>
          <Button
            type="submit"
            variant="contained"
            disabled={mutation.isPending}
            startIcon={
              mutation.isPending ? (
                <CircularProgress size={16} color="inherit" />
              ) : (
                <PersonAdd />
              )
            }
          >
            {mutation.isPending ? "Assigning..." : "Assign Role"}
          </Button>
        </DialogActions>
      </Stack>
    </form>
  );
};

const Page = () => {
  const userSettingsDefaults = useSettings();
  const router = useRouter();
  const { userId } = router.query;
  const [signInLogsDialogOpen, setSignInLogsDialogOpen] = useState(false);
  const [addRoleDialogOpen, setAddRoleDialogOpen] = useState(false);
  const userActions = useCippUserActions();
  const { checkPermissions } = usePermissions();
  const canWriteUser = checkPermissions(["Identity.User.ReadWrite"]);
  const removeMethodDialog = useDialog();
  const defaultMethodDialog = useDialog();
  const [selectedMethod, setSelectedMethod] = useState(null);
  const tenant = router.query.tenantFilter ?? userSettingsDefaults.currentTenant;
  const settingsReady = userSettingsDefaults.isInitialized && !!tenant;
  const queryReady = router.isReady && !!userId && settingsReady;

  const userRequest = ApiGetCall({
    url: `/api/ListUsers?UserId=${userId}&tenantFilter=${tenant}`,
    queryKey: `ListUsers-${userId}-${tenant}`,
    waiting: queryReady,
  });

  // Trigger refetch when query conditions become ready
  useEffect(() => {
    if (queryReady && !userRequest.isSuccess && !userRequest.isFetching) {
      userRequest.refetch();
    }
  }, [queryReady, userId, tenant]);

  const userBulkRequest = ApiPostCall({
    urlFromData: true,
  });
  const bulkFetchedForId = useRef(null);

  const roleAssignments = ApiGetCall({
    url: `/api/ListRoleAssignments?principalId=${userId}&tenantFilter=${
      router.query.tenantFilter ?? userSettingsDefaults.currentTenant
    }`,
    queryKey: `ListRoleAssignments-${userId}`,
    waiting: queryReady,
  });
  const roleAssignmentActions = useCippRoleAssignmentActions();

  const addRoleMutation = ApiPostCall({
    urlFromData: true,
    relatedQueryKeys: ["ListRoles"],
  });

  const refreshFunction = useCallback(() => {
    const userPrincipalName = userRequest.data?.[0]?.userPrincipalName;
    const requests = [
      {
        id: "userMemberOf",
        url: `/users/${userId}/memberOf`,
        method: "GET",
      },
      {
        id: "mfaDevices",
        url: `/users/${userId}/authentication/methods?$top=99`,
        method: "GET",
      },
      {
        id: "signInPreferences",
        url: `/users/${userId}/authentication/signInPreferences`,
        method: "GET",
      },
      {
        id: "signInLogs",
        url: `/auditLogs/signIns?$filter=(userId eq '${userId}')&$top=1`,
        method: "GET",
      },
    ];

    if (userPrincipalName) {
      requests.push({
        id: "managedDevices",
        url: `/deviceManagement/managedDevices?$filter=userPrincipalName eq '${userPrincipalName}'`,
        method: "GET",
      });
    }

    bulkFetchedForId.current = userId
    userBulkRequest.mutate({
      url: "/api/ListGraphBulkRequest",
      data: {
        Requests: requests,
        tenantFilter: router.query.tenantFilter ?? userSettingsDefaults.currentTenant,
        noPaginateIds: ['signInLogs', 'signInPreferences'],
      },
    });
  }, [userId, userSettingsDefaults.currentTenant, userBulkRequest]);

  useEffect(() => {
    if (
      userId &&
      userSettingsDefaults.currentTenant &&
      userRequest.isSuccess &&
      bulkFetchedForId.current !== userId
    ) {
      refreshFunction()
    }
  }, [
    userId,
    userSettingsDefaults.currentTenant,
    userRequest.isSuccess,
  ])

  const bulkData = userBulkRequest?.data?.data ?? []
  const signInLogsData = bulkData?.find((item) => item.id === 'signInLogs')
  const userMemberOfData = bulkData?.find((item) => item.id === 'userMemberOf')
  const mfaDevicesData = bulkData?.find((item) => item.id === 'mfaDevices')
  const managedDevicesData = bulkData?.find(
    (item) => item.id === 'managedDevices'
  )
  const signInPrefsData = bulkData?.find(
    (item) => item.id === 'signInPreferences'
  )

  // signInPreferences is a singleton resource, so the payload is .body itself, not .body.value.
  // It can 403/404 on some tenants; everything downstream falls back to the unmarked state.
  const signInPrefs = signInPrefsData?.body ?? {}

  const signInLogs = signInLogsData?.body?.value || []
  const userMemberOf = userMemberOfData?.body?.value || []
  const mfaDevices = mfaDevicesData?.body?.value || []
  const managedDevices = managedDevicesData?.body?.value || []

  // Set the title and subtitle for the layout
  const title = userRequest.isSuccess
    ? userRequest.data?.[0]?.displayName
    : 'Loading...'

  const subtitle = userRequest.isSuccess
    ? [
        {
          icon: <CippIcons.Mail />,
          text: (
            <CippCopyToClipBoard
              type="chip"
              text={userRequest.data?.[0]?.userPrincipalName}
            />
          ),
        },
        {
          icon: <CippIcons.Fingerprint />,
          text: (
            <CippCopyToClipBoard type="chip" text={userRequest.data?.[0]?.id} />
          ),
        },
        {
          icon: <CippIcons.CalendarIcon />,
          text: (
            <>
              Created:{' '}
              <CippTimeAgo data={userRequest.data?.[0]?.createdDateTime} />
            </>
          ),
        },
        {
          icon: <CippIcons.Launch />,
          text: (
            <Button
              color="muted"
              style={{ paddingLeft: 0 }}
              size="small"
              href={`https://entra.microsoft.com/${userSettingsDefaults.currentTenant}/#view/Microsoft_AAD_UsersAndTenants/UserProfileMenuBlade/~/overview/userId/${userId}`}
              target="_blank"
              rel="noopener noreferrer"
            >
              View in Entra
            </Button>
          ),
        },
      ]
    : []

  const data = userRequest.data?.[0];
  const userPrincipalName = data?.userPrincipalName;

  // Prepare the sign-in log item
  let signInLogItem = null;
  let conditionalAccessPoliciesItems = [];
  let mfaDevicesItems = [];

  if (signInLogs.length > 0) {
    const signInData = signInLogs[0];

    signInLogItem = {
      id: 1,
      cardLabelBox: {
        cardLabelBoxHeader: new Date(signInData.createdDateTime).getDate().toString(),
        cardLabelBoxText: new Date(signInData.createdDateTime).toLocaleString("default", {
          month: "short",
          year: "numeric",
        }),
      },
      text: `Login ${signInData.status.errorCode === 0 ? "successful" : "failed"} from ${
        signInData.ipAddress || "unknown location"
      }`,
      subtext: `Logged into application ${signInData.resourceDisplayName || "Unknown Application"}`,
      statusColor: signInData.status.errorCode === 0 ? "success.main" : "error.main",
      statusText: signInData.status.errorCode === 0 ? "Success" : "Failed",
      actionButton: (
        <Button
          variant="contained"
          size="small"
          onClick={() => setSignInLogsDialogOpen(true)}
          startIcon={
            <SvgIcon fontSize="small">
              <CippIcons.EyeIcon />
            </SvgIcon>
          }
        >
          More Sign-In Logs
        </Button>
      ),
      propertyItems: [
        {
          label: "Client App Used",
          value: signInData.clientAppUsed || "N/A",
        },
        {
          label: "Device Detail",
          value:
            signInData.deviceDetail?.operatingSystem || signInData.deviceDetail?.browser || "N/A",
        },
        {
          label: "MFA Type used",
          value: signInData.mfaDetail?.authMethod || "N/A",
        },
        {
          label: "Additional Details",
          value: signInData.status?.additionalDetails || "N/A",
        },
      ],
      children: (
        <>
          {signInData?.location && (
            <>
              <Typography variant="h6">Location</Typography>
              <Grid container spacing={2}>
                <Grid size={{ xs: 12, md: 8 }}>
                  <CippMap
                    markers={[
                      {
                        position: [
                          signInData.location.geoCoordinates.latitude,
                          signInData.location.geoCoordinates.longitude,
                        ],
                        popup: `${signInData.location.city}, ${signInData.location.state}, ${signInData.location.countryOrRegion}`,
                      },
                    ]}
                  />
                </Grid>
                <Grid size={{ xs: 12, md: 4 }}>
                  <CippPropertyList
                    propertyItems={[
                      { label: "City", value: signInData.location.city },
                      { label: "State", value: signInData.location.state },
                      { label: "Country/Region", value: signInData.location.countryOrRegion },
                    ]}
                  />
                </Grid>
              </Grid>
            </>
          )}
        </>
      ),
    };

    // Prepare the conditional access policies items
    if (
      signInData.appliedConditionalAccessPolicies &&
      Array.isArray(signInData.appliedConditionalAccessPolicies)
    ) {
      // Filter policies where result is "success"
      const appliedPolicies = signInData.appliedConditionalAccessPolicies.filter(
        (policy) => policy.result === "success",
      );

      if (appliedPolicies.length > 0) {
        conditionalAccessPoliciesItems = appliedPolicies.map((policy) => ({
          id: policy.id,
          cardLabelBox: {
            cardLabelBoxHeader: new Date(signInData.createdDateTime).getDate().toString(),
            cardLabelBoxText: new Date(signInData.createdDateTime).toLocaleString("default", {
              month: "short",
              year: "numeric",
            }),
          },
          text: policy.displayName,
          subtext: `Policy applied: ${policy.result}`,
          statusColor: "success.main",
          statusText: "Applied",
          propertyItems: [
            {
              label: "Grant Controls",
              value:
                policy.enforcedGrantControls.length > 0
                  ? policy.enforcedGrantControls.join(", ")
                  : "None",
            },
            {
              label: "Session Controls",
              value:
                policy.enforcedSessionControls.length > 0
                  ? policy.enforcedSessionControls.join(", ")
                  : "None",
            },
            {
              label: "Conditions Satisfied",
              value: policy.conditionsSatisfied || "N/A",
            },
          ],
        }));
      } else {
        // No applied policies
        conditionalAccessPoliciesItems = [
          {
            id: 1,
            cardLabelBox: {
              cardLabelBoxHeader: new Date(signInData.createdDateTime).getDate().toString(),
              cardLabelBoxText: new Date(signInData.createdDateTime).toLocaleString("default", {
                month: "short",
                year: "numeric",
              }),
            },
            text: "No conditional access policies applied",
            subtext: "No conditional access policies were applied during this sign-in.",
            statusColor: "warning.main",
            statusText: "No Policies Applied",
            propertyItems: [],
          },
        ];
      }
    } else {
      // appliedConditionalAccessPolicies is missing or not an array
      conditionalAccessPoliciesItems = [
        {
          id: 1,
          cardLabelBox: {
            cardLabelBoxHeader: new Date(signInData.createdDateTime).getDate().toString(),
            cardLabelBoxText: new Date(signInData.createdDateTime).toLocaleString("default", {
              month: "short",
              year: "numeric",
            }),
          },
          text: "No conditional access policies available",
          subtext: "No conditional access policies data is available for this sign-in.",
          statusColor: "warning.main",
          statusText: "No Data",
          propertyItems: [],
        },
      ];
    }
  } else if (signInLogsData?.status !== 200) {
    signInLogItem = {
      id: 1,
      cardLabelBox: "!",
      text: "Error loading sign-in logs. Do you have a P1 license?",
      subtext: signInLogsData?.error?.message || "Unknown error",
      statusColor: "error.main",
      statusText: "Error",
      propertyItems: [],
    };

    // Handle error for conditional access policies
    conditionalAccessPoliciesItems = [
      {
        id: 1,
        cardLabelBox: "!",
        text: "Error loading conditional access policies. Do you have a P1 license?",
        subtext: signInLogsData?.error?.message || "Unknown error",
        statusColor: "error.main",
        statusText: "Error",
        propertyItems: [],
      },
    ];
  } else if (signInLogs.length === 0) {
    signInLogItem = {
      id: 1,
      cardLabelBox: "-",
      text: "No sign-in logs available",
      subtext:
        "There are no sign-in logs for this user, or you do not have a P1 license to detect this data.",
      statusColor: "warning.main",
      statusText: "No Data",
      propertyItems: [
        {
          label: "Error",
          value: signInLogsData?.error?.message || "Unknown error",
        },
        {
          label: "Inner Error",
          value: (
            <CippCodeBlock
              language="json"
              code={JSON.stringify(signInLogsData?.error?.innerError, null, 2) || "Unknown error"}
            />
          ),
        },
      ],
    };

    conditionalAccessPoliciesItems = [
      {
        id: 1,
        cardLabelBox: "-",
        text: "No conditional access policies available",
        subtext:
          "There are no conditional access policies for this user, or you do not have a P1 license to detect this data.",
        statusColor: "warning.main",
        statusText: "No Data",
        propertyItems: [],
      },
    ];
  }

  const mfaDevicesFiltered = mfaDevices.filter(
    (method) =>
      method['@odata.type'] !== '#microsoft.graph.passwordAuthenticationMethod'
  )

  const userPreferredMethod =
    signInPrefs.userPreferredMethodForSecondaryAuthentication
  // Only meaningful while system-preferred MFA is on; the field can be populated but inert.
  const systemPreferredTypes =
    (signInPrefs.isSystemPreferredAuthenticationMethodEnabled &&
      SYSTEM_PREF_METHOD_TYPES[
        String(signInPrefs.systemPreferredAuthenticationMethod ?? '').toLowerCase()
      ]) ||
    []
  const availablePrefValues = [
    ...new Set(mfaDevicesFiltered.flatMap(prefValuesForMethod)),
  ]
  const defaultMethodOptions = Object.entries(MFA_PREF_LABELS)
    .filter(([value]) => availablePrefValues.includes(value))
    .map(([value, label]) => ({ label, value }))

  // Prepare MFA devices items
  if (mfaDevices.length > 0) {
    if (mfaDevicesFiltered.length > 0) {
      mfaDevicesItems = mfaDevicesFiltered.map((device, index) => {
        const methodType = getMethodType(device)
        const meta = getMethodMeta(device)
        const identifier = meta.identifier(device)
        // Both preferences are type-level, so every method of a preferred type is marked.
        const methodPrefValues = prefValuesForMethod(device)
        const statusLabels = []
        if (
          userPreferredMethod &&
          methodPrefValues.includes(userPreferredMethod)
        ) {
          statusLabels.push('User default')
        }
        // Matched by @odata.type, since the system value uses a different vocabulary.
        if (systemPreferredTypes.includes(methodType)) {
          statusLabels.push('System-preferred')
        }
        return {
          id: index,
          cardLabelBox: {
            cardLabelBoxHeader: meta.icon,
          },
          text: identifier ? `${meta.label} · ${identifier}` : meta.label,
          // lastUsedDateTime is beta-only and optional — Graph nulls it for method
          // types that don't populate it, so keep a fallback.
          subtext: device.lastUsedDateTime
            ? `Last used ${new Date(device.lastUsedDateTime).toLocaleDateString()}`
            : 'Last used unknown',
          statusColor:
            statusLabels.length > 0 ? 'primary.main' : 'success.main',
          statusText:
            statusLabels.length > 0 ? statusLabels.join(' · ') : 'Enabled',
          // The card id is the collapse key, so the Graph method id travels via selectedMethod.
          cardLabelBoxActions: canWriteUser ? (
            <IconButton
              size="small"
              title="Remove this MFA method"
              onClick={() => {
                setSelectedMethod({ ...device, methodType: meta.label })
                removeMethodDialog.handleOpen()
              }}
            >
              <CippIcons.Delete fontSize="small" />
            </IconButton>
          ) : undefined,
          propertyItems: [
            {
              label: 'Device Name',
              value: device.displayName || 'N/A',
            },
            {
              label: 'App Version',
              value: device.phoneAppVersion || 'N/A',
            },
            {
              label: 'Created Date',
              value: device.createdDateTime
                ? new Date(device.createdDateTime).toLocaleString()
                : 'N/A',
            },
            {
              label: 'Authentication Method',
              value: methodType,
            },
          ],
        }
      })
    } else {
      // No MFA devices other than password
      mfaDevicesItems = [
        {
          id: 1,
          cardLabelBox: '-',
          text: 'No MFA devices available',
          subtext: 'The user does not have any MFA devices registered.',
          statusColor: 'warning.main',
          statusText: 'No Devices',
          propertyItems: [],
        },
      ]
    }
  } else if (mfaDevicesData?.status !== 200) {
    // Error fetching MFA devices
    mfaDevicesItems = [
      {
        id: 1,
        cardLabelBox: '!',
        text: 'Error loading MFA devices',
        subtext: `Status code: ${mfaDevicesData?.status}`,
        statusColor: 'error.main',
        statusText: 'Error',
        propertyItems: [
          {
            label: 'Error',
            value: mfaDevicesData?.body?.error?.message || 'Unknown Error',
          },
          {
            label: 'Inner Error',
            value: (
              <CippCodeBlock
                language="json"
                code={
                  JSON.stringify(
                    mfaDevicesData?.body?.error?.innerError,
                    null,
                    2
                  ) || 'Unknown Error'
                }
              />
            ),
          },
        ],
      },
    ]
  } else if (mfaDevices.length === 0) {
    // No MFA devices data available
    mfaDevicesItems = [
      {
        id: 1,
        cardLabelBox: '-',
        text: 'No MFA devices available',
        subtext: 'The user does not have any MFA devices registered.',
        statusColor: 'warning.main',
        statusText: 'No Devices',
        propertyItems: [],
      },
    ]
  }

  // Memoize group membership items
  const groupMembershipItems = useMemo(() => {
    if (!userMemberOf) return [];
    // Raw Graph groups have no groupType field, but the edit page needs the label
    const groups = userMemberOf
      .filter((item) => item?.["@odata.type"] === "#microsoft.graph.group")
      .map((group) => ({ ...group, groupType: getGroupTypeLabel(group) }));
    return [
      {
        id: 1,
        cardLabelBox: {
          cardLabelBoxHeader: <Group />,
        },
        text: "Groups",
        subtext: "List of groups the user is a member of",
        statusText: ` ${groups.length} Group(s)`,
        statusColor: "info.main",
        table: {
          title: "Group Memberships",
          hideTitle: true,
          actions: [
            {
              icon: <PencilIcon />,
              label: "Edit Group",
              link: "/identity/administration/groups/edit?groupId=[id]&groupType=[groupType]",
              category: "edit",
            },
          ],
          data: groups,
          refreshFunction: refreshFunction,
          simpleColumns: ["displayName", "groupTypes", "securityEnabled", "mailEnabled"],
        },
      },
    ];
  }, [userMemberOf, refreshFunction]);

  const roleAssignmentRows = roleAssignments.data ?? []
  const permanentRoleCount = roleAssignmentRows.filter(
    (row) => row.AssignmentType === 'Permanent'
  ).length
  const eligibleRoleCount = roleAssignmentRows.filter(
    (row) => row.AssignmentType === 'Eligible'
  ).length
  const roleMembershipItems = roleAssignments.isSuccess
    ? [
        {
          id: 1,
          cardLabelBox: {
            cardLabelBoxHeader: <CippIcons.AdminPanelSettings />,
          },
          text: 'Admin Roles',
          subtext:
            'Directory roles held by this user and how they are assigned (permanent, eligible or time-bound)',
          statusText: ` ${roleAssignmentRows.length} assignment(s) - ${permanentRoleCount} permanent, ${eligibleRoleCount} eligible`,
          statusColor: permanentRoleCount > 0 ? 'warning.main' : 'info.main',
          actionButton: (
            <Button
              variant="contained"
              size="small"
              startIcon={<PersonAdd />}
              onClick={() => setAddRoleDialogOpen(true)}
            >
              Add Role
            </Button>
          ),
          table: {
            title: 'Admin Roles',
            hideTitle: true,
            actions: roleAssignmentActions,
            data: roleAssignmentRows,
            simpleColumns: [
              'RoleDisplayName',
              'AssignmentType',
              'MemberType',
              'Scope',
              'EndDateTime',
              'PolicySummary',
            ],
            refreshFunction: refreshFunction,
          },
        },
      ]
    : []

  const ownedDevicesItems = managedDevices.length > 0
    ? [
        {
          id: 1,
          cardLabelBox: {
            cardLabelBoxHeader: <CippIcons.Devices />,
          },
          text: "Managed Devices",
          subtext: "List of devices managed for this user",
          statusText: `${managedDevices.length} Device(s)`,
          statusColor: "info.main",
          table: {
            title: "Managed Devices",
            hideTitle: true,
            data: managedDevices,
            refreshFunction: refreshFunction,
            simpleColumns: ["deviceName", "operatingSystem", "osVersion", "managementType"],
            actions: [
              {
                icon: <CippIcons.EyeIcon />,
                label: "View Device",
                link: `/endpoint/MEM/devices/device?deviceId=[id]&tenantFilter=${userSettingsDefaults.currentTenant}`,
                category: "view",
                pinned: true,
              },
            ],
          },
        },
      ]
    : managedDevicesData?.status !== 200
    ? [
        {
          id: 1,
          cardLabelBox: "!",
          text: "Error loading devices",
          subtext: managedDevicesData?.error?.message || "Unknown error",
          statusColor: "error.main",
          statusText: "Error",
          propertyItems: [],
        },
      ]
    : [
        {
          id: 1,
          cardLabelBox: "-",
          text: "No devices",
          subtext: "This user does not have any managed devices.",
          statusColor: "warning.main",
          statusText: "No Devices",
          propertyItems: [],
        },
      ];

  return (
    <HeaderedTabbedLayout
      tabOptions={tabOptions}
      title={title}
      titleControl={
        <CippUserSwitcher
          title={title}
          currentUserId={userId}
          tenantFilter={router.query.tenantFilter ?? userSettingsDefaults.currentTenant}
        />
      }
      actions={userActions}
      actionsData={data}
      subtitle={subtitle}
      isFetching={userRequest.isLoading}
    >
      {/* The loading state is the loaded page's own scaffold with each card in its
          skeleton form — generic form-row bars looked nothing like what replaces them
          and left the rest of the viewport empty. */}
      {userRequest.isLoading && (
        <Box sx={{ flexGrow: 1, py: { xs: 2, md: 4 } }}>
          <Grid container spacing={2}>
            <Grid size={{ xs: 12, lg: 4 }}>
              <CippUserInfoCard isFetching />
            </Grid>
            <Grid size={{ xs: 12, lg: 8 }}>
              <Stack spacing={3}>
                {['Latest Logon', 'Applied Conditional Access Policies', 'Multi-Factor Authentication Devices', 'Memberships'].map(
                  (section) => (
                    <Fragment key={section}>
                      <Typography variant="h6">{section}</Typography>
                      <CippBannerListCard isFetching items={[]} />
                    </Fragment>
                  )
                )}
              </Stack>
            </Grid>
          </Grid>
        </Box>
      )}
      {userRequest.isSuccess && (
        <Box
          sx={{
            flexGrow: 1,
            py: { xs: 2, md: 4 },
          }}
        >
          <CippHead title={title} />
          <Grid container spacing={2}>
            {/* Stacked below lg so a phone-width split does not break labels one word per line. */}
            <Grid size={{ xs: 12, lg: 4 }}>
              <CippUserInfoCard
                user={data}
                tenant={userSettingsDefaults.currentTenant}
                isFetching={userRequest.isLoading}
                onRefresh={() => userRequest.refetch()}
              />
            </Grid>
            <Grid size={{ xs: 12, lg: 8 }}>
              <Stack spacing={3}>
                {/* Sign-In Activity Section */}
                <Stack direction="row" alignItems="center" spacing={1}>
                  <Login color="primary" />
                  <Typography variant="h6">Sign-In Activity</Typography>
                </Stack>
                <CippBannerListCard
                  isFetching={userBulkRequest.isPending}
                  items={signInLogItem ? [signInLogItem] : []}
                  isCollapsible={signInLogItem ? true : false}
                />

                <Divider sx={{ my: 1 }} />

                {/* Security Section */}
                <Stack direction="row" alignItems="center" spacing={1}>
                  <Security color="primary" />
                  <Typography variant="h6">Security</Typography>
                </Stack>
                <CippBannerListCard
                  isFetching={userBulkRequest.isPending}
                  items={conditionalAccessPoliciesItems}
                  isCollapsible={conditionalAccessPoliciesItems.length > 0 ? true : false}
                />
                <Stack
                  direction="row"
                  sx={{
                    justifyContent: "space-between",
                    alignItems: "center"
                  }}>
                  <Typography variant="h6">
                    Multi-Factor Authentication Devices
                  </Typography>
                  {canWriteUser && (
                    <Button
                      size="small"
                      variant="outlined"
                      startIcon={<CippIcons.LockPerson />}
                      disabled={defaultMethodOptions.length === 0}
                      title={
                        defaultMethodOptions.length === 0
                          ? 'This user has no registered method that can be set as the default second factor.'
                          : undefined
                      }
                      onClick={() => defaultMethodDialog.handleOpen()}
                    >
                      Set Default MFA Method
                    </Button>
                  )}
                </Stack>
                <CippBannerListCard
                  isFetching={userBulkRequest.isPending}
                  items={mfaDevicesItems}
                  isCollapsible={mfaDevicesItems.length > 0 ? true : false}
                />

                <Divider sx={{ my: 1 }} />

                {/* Memberships Section */}
                <Stack direction="row" alignItems="center" spacing={1}>
                  <Badge color="primary" />
                  <Typography variant="h6">Memberships</Typography>
                </Stack>
                <CippBannerListCard
                  isFetching={userBulkRequest.isPending}
                  items={groupMembershipItems}
                  isCollapsible={true}
                />
                <CippBannerListCard
                  isFetching={roleAssignments.isFetching}
                  items={roleMembershipItems}
                  isCollapsible={true}
                />

                <Divider sx={{ my: 1 }} />

                <Stack direction="row" alignItems="center" spacing={1}>
                  <Devices color="primary" />
                  <Typography variant="h6">Devices</Typography>
                </Stack>
                <CippUserDevicesSection userId={userId} tenant={userSettingsDefaults.currentTenant} />
                <Typography variant="subtitle2" color="text.secondary" sx={{ mt: 1 }}>
                  Intune managed devices
                </Typography>
                <CippBannerListCard
                  isFetching={userBulkRequest.isPending}
                  items={ownedDevicesItems}
                  isCollapsible={true}
                />
              </Stack>
            </Grid>
          </Grid>
        </Box>
      )}
      <SignInLogsDialog
        open={signInLogsDialogOpen}
        onClose={() => setSignInLogsDialogOpen(false)}
        userId={userId}
        tenantFilter={userSettingsDefaults.currentTenant}
      />
      <Dialog
        open={addRoleDialogOpen}
        onClose={() => !addRoleMutation.isPending && setAddRoleDialogOpen(false)}
        maxWidth="sm"
        fullWidth
      >
        <DialogTitle sx={{ display: "flex", alignItems: "center", gap: 1 }}>
          <PersonAdd color="primary" />
          Add Role to {data?.displayName}
        </DialogTitle>
        <DialogContent>
          {addRoleDialogOpen && (
            <AddRoleForm
              user={data}
              tenant={tenant}
              onClose={() => setAddRoleDialogOpen(false)}
              onSuccess={() => {
                refreshFunction();
                setAddRoleDialogOpen(false);
              }}
              mutation={addRoleMutation}
            />
          )}
        </DialogContent>
      </Dialog>
      <CippApiDialog
        createDialog={removeMethodDialog}
        title="Remove MFA Method"
        row={selectedMethod ?? {}}
        allowResubmit={true}
        api={{
          type: 'POST',
          url: '/api/ExecResetMFA',
          data: { ID: `!${userPrincipalName}`, MethodId: 'id' },
          confirmText:
            'Are you sure you want to remove the [methodType] method from this user?',
          onSuccess: refreshFunction,
        }}
      />
      <CippApiDialog
        createDialog={defaultMethodDialog}
        title="Set Default MFA Method"
        row={{}}
        fields={[
          {
            type: 'autoComplete',
            name: 'MethodType',
            label: 'Default method',
            options: defaultMethodOptions,
            multiple: false,
            creatable: false,
            validators: { required: 'Please select a default MFA method' },
          },
        ]}
        api={{
          type: 'POST',
          url: '/api/ExecSetDefaultMFAMethod',
          data: { ID: `!${userPrincipalName}` },
          onSuccess: refreshFunction,
        }}
      />
    </HeaderedTabbedLayout>
  );
};

Page.getLayout = (page) => (
  <DashboardLayout allTenantsSupport={false}>{page}</DashboardLayout>
)

export default Page;
