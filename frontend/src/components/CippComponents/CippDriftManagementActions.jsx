import React from 'react'
import { CippIcons } from '../../utils/icon-registry'
import { CippFormTemplateTenantSelector } from './CippFormTemplateTenantSelector.jsx'

/**
 * Creates the standard drift management actions array
 * @param {Object} options - Configuration options
 * @param {string} options.templateId - The template ID for conditional actions
 * @param {Function} options.onRefresh - Function to call when refresh is triggered
 * @param {Function} options.onGenerateReport - Function to call when generate report is triggered (optional)
 * @returns {Array} Array of action objects
 */
export const createDriftManagementActions = ({
  templateId,
  templateType = 'classic',
  showEditTemplate = false,
  onRefresh,
  onGenerateReport,
  currentTenant,
  templateTenants = [],
  excludedTenants = [],
}) => {
  const actions = [
    {
      label: 'Refresh Data',
      icon: <CippIcons.Sync />,
      noConfirm: true,
      category: 'manage',
      customFunction: onRefresh,
    },
  ]

  // Add Generate Report action if handler is provided
  if (onGenerateReport) {
    actions.push({
      label: 'Generate Report',
      icon: <CippIcons.PictureAsPdf />,
      noConfirm: true,
      category: 'manage',
      customFunction: onGenerateReport,
    })
  }

  // Add template-specific actions if templateId is available
  if (templateId) {
    // Conditionally add Edit Template action
    if (showEditTemplate) {
      actions.push({
        label: 'Edit Template',
        pinned: true,
        icon: <CippIcons.Edit />,
        color: 'info',
        category: 'edit',
        noConfirm: true,
        customFunction: () => {
          // Use Next.js router for internal navigation
          import('next/router')
            .then(({ default: router }) => {
              router.push(
                `/tenant/standards/templates/template?id=${templateId}&type=${templateType}`
              )
            })
            .catch(() => {
              const id = String(templateId ?? "")
              const type = String(templateType ?? "")
              if (!/^[\w-]+$/.test(id) || !/^[\w-]+$/.test(type)) {
                return
              }
              const url = new URL("/tenant/standards/templates/template", window.location.origin)
              url.searchParams.set("id", id)
              url.searchParams.set("type", type)
              window.location.assign(`${url.pathname}${url.search}`)
            })
        },
      })
    }

    actions.push({
      label: 'Run Standard Now',
      type: 'GET',
      url: '/api/ExecStandardsRun',
      icon: <CippIcons.PlayArrow />,
      data: {
        TemplateId: templateId,
      },
      customDataformatter: (_row, _action, formData) => ({
        TemplateId: templateId,
        tenantFilter: formData.tenantFilter?.value ?? formData.tenantFilter,
      }),
      children: ({ formHook }) => (
        <CippFormTemplateTenantSelector
          formControl={formHook}
          templateTenants={templateTenants}
          excludedTenants={excludedTenants}
        />
      ),
      confirmText: 'Are you sure you want to force a run of this standard?',
      allowResubmit: true,
      multiPost: false,
      category: 'manage',
    })
    actions.push({
      label: 'Run Standard Now (All Tenants in Template)',
      type: 'GET',
      url: '/api/ExecStandardsRun',
      icon: <CippIcons.PlayArrow />,
      data: {
        TemplateId: templateId,
        tenantFilter: 'allTenants',
      },
      confirmText: 'Are you sure you want to force a run of this standard for every tenant in the template?',
      multiPost: false,
      category: 'manage',
    })
  }

  return actions
}

/**
 * Default export for backward compatibility
 */
export default createDriftManagementActions
