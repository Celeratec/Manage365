import { CippIcons } from '../../utils/icon-registry'
import { usePermissions } from '../../hooks/use-permissions'

const GLOBAL_ADMIN_TEMPLATE_ID = '62e90394-69f5-4237-9190-012177145e10'

const isGlobalAdmin = (row) =>
  row?.RoleDefinitionId === GLOBAL_ADMIN_TEMPLATE_ID
// Catalogue rows (roles nobody holds) have no principal and get no actions.
const isDirect = (row) => !!row?.PrincipalId && row?.MemberType !== 'Group'
const principalLabel = (row) =>
  row?.PrincipalUserPrincipalName ||
  row?.PrincipalDisplayName ||
  row?.PrincipalId ||
  ''

// Anything touching Global Administrator needs the principal's name typed back. For a bulk
// selection that includes a Global Administrator the dialog asks for a generic count phrase.
const globalAdminPhrase = (rowOrRows) => {
  if (Array.isArray(rowOrRows)) {
    return rowOrRows.some(isGlobalAdmin)
      ? `CONFIRM ${rowOrRows.length} ASSIGNMENTS`
      : null
  }
  return isGlobalAdmin(rowOrRows) ? principalLabel(rowOrRows) : null
}

const justificationField = {
  type: 'textField',
  name: 'Justification',
  label: 'Justification (recorded on the PIM request and in the logbook)',
  required: true,
  validators: { required: 'A justification is required' },
}

// Same ceiling as Config/RoleAssignment.json MaxRoleAssignmentDuration (default P365D).
const MAX_ROLE_ASSIGNMENT_MS = 365 * 24 * 60 * 60 * 1000

const durationValue = (value) => (value && typeof value === 'object' ? value.value : value)

// XmlConvert treats a year as 365 days and a month as 30 days. Weeks are 7 days.
const isoDurationToMs = (value) => {
  const raw = durationValue(value)
  if (!raw || raw === 'custom') return null
  const match = /^P(?:(\d+)Y)?(?:(\d+)M)?(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$/.exec(raw)
  if (!match) return null
  const days = Number(match[1] || 0) * 365 + Number(match[2] || 0) * 30 + Number(match[3] || 0) * 7 + Number(match[4] || 0)
  const hours = Number(match[5] || 0)
  const minutes = Number(match[6] || 0)
  const seconds = Number(match[7] || 0)
  return (((days * 24 + hours) * 60 + minutes) * 60 + seconds) * 1000
}

const durationValidator = (value) => {
  const raw = durationValue(value)
  if (!raw || raw === 'custom') return true
  const ms = isoDurationToMs(raw)
  if (ms == null) return 'Use an ISO 8601 duration such as PT1H, P30D or P365D'
  if (ms <= 0) return 'Duration must be greater than zero'
  if (ms > MAX_ROLE_ASSIGNMENT_MS) return 'Duration cannot exceed 365 days (P365D)'
  return true
}

const eligibilityDurationField = {
  type: 'autoComplete',
  name: 'Duration',
  label: 'Eligibility lifetime',
  multiple: false,
  creatable: true,
  required: true,
  options: [
    { label: '3 months', value: 'P90D' },
    { label: '6 months', value: 'P180D' },
    { label: '1 year', value: 'P365D' },
  ],
  validators: {
    required: 'Select how long the eligibility lasts',
    validate: durationValidator,
  },
}

const activeDurationField = {
  type: 'autoComplete',
  name: 'Duration',
  label: 'Active for',
  multiple: false,
  creatable: true,
  required: true,
  options: [
    { label: '30 minutes', value: 'PT30M' },
    { label: '1 hour', value: 'PT1H' },
    { label: '8 hours', value: 'PT8H' },
    { label: '1 day', value: 'P1D' },
    { label: '7 days', value: 'P7D' },
    { label: '30 days', value: 'P30D' },
    { label: '90 days', value: 'P90D' },
    { label: '180 days', value: 'P180D' },
    { label: '365 days', value: 'P365D' },
    { label: 'Custom end date', value: 'custom' },
  ],
  validators: {
    required: 'Select how long the assignment stays active',
    validate: durationValidator,
  },
}

const customWindowFields = () => {
  const now = new Date()
  const maxEnd = new Date(now.getTime() + MAX_ROLE_ASSIGNMENT_MS)
  const whenCustom = {
    field: 'Duration',
    compareType: 'contains',
    compareValue: 'custom',
  }
  return [
    {
      type: 'datePicker',
      name: 'StartDateTime',
      label: 'Active from (optional)',
      dateTimeType: 'datetime',
      minDate: now,
      maxDate: maxEnd,
      condition: whenCustom,
    },
    {
      type: 'datePicker',
      name: 'EndDateTime',
      label: 'Active until',
      dateTimeType: 'datetime',
      minDate: now,
      maxDate: maxEnd,
      condition: whenCustom,
      validators: {
        validate: (value, formValues) => {
          const selected = durationValue(formValues?.Duration)
          if (selected !== 'custom' && !(typeof selected === 'string' && selected.includes('custom'))) return true
          if (!value) return 'Choose an end date'
          const endMs = value * 1000
          if (endMs <= Date.now()) return 'End date is in the past'
          const startMs = formValues?.StartDateTime ? formValues.StartDateTime * 1000 : Date.now()
          if (endMs <= startMs) return 'End date must be after the start date'
          if (endMs - startMs > MAX_ROLE_ASSIGNMENT_MS) return 'The assignment cannot last longer than 365 days (P365D)'
          return true
        },
      },
    },
  ]
}

const baseData = {
  PrincipalId: 'PrincipalId',
  RoleDefinitionId: 'RoleDefinitionId',
  DirectoryScopeId: 'DirectoryScopeId',
  AssignmentType: 'AssignmentType',
}

/**
 * Row/bulk actions for role assignment rows as returned by /api/ListRoleAssignments.
 * Shared by the Role Assignments page and the user view's Admin Roles card, so both surfaces
 * offer exactly the same secure-direction set: convert permanent -> eligible, grant a time-bound
 * active assignment, extend/renew, remove. Nothing here can create a permanent assignment.
 */
export const useCippRoleAssignmentActions = ({
  relatedQueryKeys = ['ListRoleAssignments*'],
} = {}) => {
  const { checkPermissions } = usePermissions()
  const canWriteRole = checkPermissions(['Identity.Role.ReadWrite'])
  // The browser's IANA zone, so the result wording ("until ...") reads in local time; the API
  // falls back to UTC when it is missing.
  const timeZoneData = {
    TimeZone: `!${Intl.DateTimeFormat().resolvedOptions().timeZone}`,
  }
  const [customStartField, customEndField] = customWindowFields()

  return [
    {
      label: 'Convert to eligible',
      type: 'POST',
      icon: <CippIcons.SwapHoriz />,
      url: '/api/ExecPIMRoleAssignment',
      data: { ...baseData, ...timeZoneData, Action: '!ConvertToEligible' },
      fields: [eligibilityDurationField, justificationField],
      confirmText:
        'Convert the permanent [RoleDisplayName] assignment of [PrincipalUserPrincipalName] to an eligible assignment? The eligibility is created and verified before the permanent assignment is removed; the principal will need to activate the role to use it.',
      confirmPhrase: globalAdminPhrase,
      relatedQueryKeys,
      condition: (row) =>
        canWriteRole &&
        row?.PIMCapable &&
        row?.AssignmentType === 'Permanent' &&
        isDirect(row) &&
        row?.PrincipalType !== 'ServicePrincipal',
    },
    {
      label: 'Grant time-bound active assignment',
      type: 'POST',
      icon: <CippIcons.HourglassBottom />,
      url: '/api/ExecPIMRoleAssignment',
      data: { ...baseData, ...timeZoneData, Action: '!GrantActive' },
      fields: [activeDurationField, customStartField, customEndField, justificationField],
      confirmText:
        'Grant [PrincipalUserPrincipalName] an active [RoleDisplayName] assignment for the chosen time? The maximum is 365 days. Entra removes the assignment automatically when it expires, and the tenant PIM policy can still refuse a long assignment.',
      confirmPhrase: globalAdminPhrase,
      relatedQueryKeys,
      condition: (row) =>
        canWriteRole &&
        row?.PIMCapable &&
        row?.AssignmentType === 'Eligible' &&
        isDirect(row),
    },
    {
      label: 'Grant eligible assignment',
      type: 'POST',
      icon: <CippIcons.PersonAdd />,
      url: '/api/ExecPIMRoleAssignment',
      data: { ...baseData, ...timeZoneData, Action: '!GrantEligible' },
      fields: [eligibilityDurationField, justificationField],
      confirmText:
        'Grant [PrincipalUserPrincipalName] an eligible [RoleDisplayName] assignment for the chosen lifetime? The maximum is 365 days. This does not remove an active assignment. A permanent assignment has to be converted instead.',
      confirmPhrase: globalAdminPhrase,
      relatedQueryKeys,
      condition: (row) =>
        canWriteRole &&
        row?.PIMCapable &&
        isDirect(row) &&
        row?.PrincipalType !== 'ServicePrincipal' &&
        row?.AssignmentType !== 'Eligible' &&
        row?.AssignmentType !== 'Permanent',
    },
    {
      label: 'Extend',
      type: 'POST',
      icon: <CippIcons.MoreTime />,
      url: '/api/ExecPIMRoleAssignment',
      data: { ...baseData, ...timeZoneData, Action: '!Extend' },
      fields: [activeDurationField, customStartField, customEndField, justificationField],
      confirmText:
        'Extend the [AssignmentType] [RoleDisplayName] assignment of [PrincipalUserPrincipalName]? The new end is counted from now and cannot exceed 365 days. The tenant PIM policy can still refuse it.',
      confirmPhrase: globalAdminPhrase,
      relatedQueryKeys,
      condition: (row) =>
        canWriteRole &&
        row?.PIMCapable &&
        ['Active', 'Eligible'].includes(row?.AssignmentType) &&
        !!row?.EndDateTime &&
        isDirect(row),
    },
    {
      label: 'Renew',
      type: 'POST',
      icon: <CippIcons.Autorenew />,
      url: '/api/ExecPIMRoleAssignment',
      data: { ...baseData, ...timeZoneData, Action: '!Renew' },
      fields: [activeDurationField, customStartField, customEndField, justificationField],
      confirmText:
        'Renew the expired [AssignmentType] [RoleDisplayName] assignment of [PrincipalUserPrincipalName] for the chosen time? The maximum is 365 days.',
      confirmPhrase: globalAdminPhrase,
      relatedQueryKeys,
      condition: (row) =>
        canWriteRole &&
        row?.PIMCapable &&
        ['Active', 'Eligible'].includes(row?.AssignmentType) &&
        !!row?.EndDateTime &&
        new Date(row.EndDateTime) < new Date() &&
        isDirect(row),
    },
    {
      label: 'Remove assignment',
      type: 'POST',
      icon: <CippIcons.PersonRemove />,
      url: '/api/ExecPIMRoleAssignment',
      data: { ...baseData, ...timeZoneData, Action: '!Remove' },
      fields: [justificationField],
      confirmText:
        'Remove the [AssignmentType] [RoleDisplayName] assignment of [PrincipalUserPrincipalName]? The last active Global Administrator is never removed.',
      confirmPhrase: globalAdminPhrase,
      relatedQueryKeys,
      condition: (row) => canWriteRole && row?.PIMCapable && isDirect(row),
      // Exactly one of the two removal actions is shown per row; condition stays for bulk.
      hideCondition: (row) => row?.PIMCapable === false,
    },
    {
      // Tenants without Entra ID P2 have no PIM API; removal goes through the directoryRoles
      // member endpoint the Roles page has always used.
      label: 'Remove assignment',
      type: 'POST',
      icon: <CippIcons.PersonRemove />,
      url: '/api/ExecRemoveAdminRole',
      customDataformatter: (row) => {
        const rows = Array.isArray(row) ? row : [row]
        return rows.map((r) => ({
          tenantFilter: r.Tenant,
          RoleTemplateId: r.RoleDefinitionId,
          RoleName: r.RoleDisplayName,
          Users: [
            {
              value: r.PrincipalId,
              label: principalLabel(r),
              addedFields: {
                displayName: r.PrincipalDisplayName,
                userPrincipalName: r.PrincipalUserPrincipalName,
              },
            },
          ],
        }))
      },
      confirmText:
        'Remove [PrincipalUserPrincipalName] from [RoleDisplayName]? This tenant has no Entra ID P2, so the assignment is removed directly.',
      confirmPhrase: globalAdminPhrase,
      relatedQueryKeys: [...relatedQueryKeys, 'ListRoles*'],
      condition: (row) =>
        canWriteRole && row?.PIMCapable === false && isDirect(row),
      hideCondition: (row) => row?.PIMCapable !== false,
    },
  ]
}
