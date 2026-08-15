export const ACCESS_TYPES = {
  guest: {
    key: "guest",
    label: "Guest Access",
    microsoftTerm: "B2B Collaboration",
    shortDescription:
      "External users are invited to your tenant as guest accounts. They appear in your directory and are subject to your Conditional Access policies.",
    fullDescription:
      "Guest Access (B2B Collaboration) creates a guest user object in your Entra ID directory. The guest authenticates using their home organization credentials or Email One-Time Passcode for personal accounts (Gmail, Outlook.com, etc.). Guests are subject to your Conditional Access policies and appear in your directory.",
    characteristics: [
      "Creates a guest account in your directory",
      "Subject to your Conditional Access policies",
      "Supports organizational and personal email addresses (Gmail, Outlook.com via Email OTP)",
      "Requires Entra External Collaboration settings to allow invitations",
      "Used for: Teams channels (standard & private), SharePoint sites, M365 Groups",
    ],
    settingsLinks: [
      {
        label: "External Collaboration",
        href: "/tenant/administration/cross-tenant-access/external-collaboration",
      },
      {
        label: "Cross-Tenant Access (B2B Collaboration)",
        href: "/tenant/administration/cross-tenant-access/policy",
      },
      {
        label: "Teams Guest Access",
        href: "/teams-share/teams/teams-settings",
      },
    ],
    chipColor: "info",
  },
  external: {
    key: "external",
    label: "External Access",
    microsoftTerm: "B2B Direct Connect",
    shortDescription:
      "External users access shared channels directly from their own tenant. No guest account is created — they have no directory footprint.",
    fullDescription:
      "External Access (B2B Direct Connect) allows users from other M365 organizations to participate in Teams shared channels without being added to your directory. They authenticate in their home tenant and access resources directly. No guest object is created.",
    characteristics: [
      "No guest account created — no directory footprint in your tenant",
      "NOT subject to your Conditional Access policies (unless inbound trust is configured)",
      "Requires a work or school account — personal emails (Gmail, etc.) are NOT supported",
      "Requires cross-tenant access policies configured on BOTH tenants",
      "Used for: Teams shared channels only",
    ],
    settingsLinks: [
      {
        label: "Cross-Tenant Access (B2B Direct Connect)",
        href: "/tenant/administration/cross-tenant-access/policy",
      },
      {
        label: "Teams Federation",
        href: "/teams-share/teams/teams-settings",
      },
    ],
    chipColor: "warning",
  },
};

export const ACCESS_TYPE_CONTEXTS = {
  teamsSharedChannel: {
    primary: "external",
    secondary: "guest",
    note: "Shared channels use External Access (B2B Direct Connect). Only work or school accounts from other M365 organizations can be added. Personal email addresses like Gmail are not supported. Existing guest users in your directory can also be added.",
  },
  teamsPrivateChannel: {
    primary: "guest",
    note: "Private channels use Guest Access (B2B Collaboration). External email addresses are invited as guest accounts. Both organizational and personal emails (Gmail, Outlook.com, etc.) are supported — personal emails authenticate via Email One-Time Passcode.",
  },
  teamsStandardChannel: {
    primary: "guest",
    note: "Standard channels use Guest Access (B2B Collaboration). External users must be invited as guests and added to the parent Team.",
  },
  sharepoint: {
    primary: "guest",
    note: "SharePoint uses Guest Access (B2B Collaboration). External users are invited as guest accounts and added to the site. Sharing links ('Anyone' links) bypass the guest invitation flow entirely.",
  },
  userManagement: {
    primary: "guest",
    note: "Guest accounts shown here were created via B2B Collaboration invitations. External Access (B2B Direct Connect) users do not appear in your directory.",
  },
  crossTenantAccess: {
    showBoth: true,
    note: "Cross-tenant access policies control both Guest Access (B2B Collaboration) and External Access (B2B Direct Connect). These are separate settings layers that can be configured independently.",
  },
  externalCollaboration: {
    primary: "guest",
    note: "External Collaboration settings control Guest Access (B2B Collaboration) only — who can invite guests, which domains are allowed, and what permissions guests have. These settings do not affect External Access (B2B Direct Connect) for shared channels, which is controlled by cross-tenant access policies.",
  },
  teamsGuestSettings: {
    primary: "guest",
    note: "These settings control whether guest users (B2B Collaboration) can use Teams. Shared channel access for external users (B2B Direct Connect) is controlled separately by cross-tenant access policies.",
  },
};

export const DECISION_TREE = {
  general: {
    question: "What type of email address does the external user have?",
    options: [
      {
        label: "Personal email (Gmail, Yahoo, Outlook.com, etc.)",
        result: {
          accessType: "guest",
          title: "Use Guest Access (B2B Collaboration)",
          description: "Personal email addresses must use Guest Access. The user will be invited to your directory and authenticate via Email One-Time Passcode (OTP).",
          supported: ["SharePoint sites", "Teams standard channels", "Teams private channels"],
          notSupported: ["Teams shared channels — requires a work/school account from another M365 organization"],
          nextSteps: [
            "Invite the user as a guest from the External Access Wizard or a site/team details page",
            "Ensure Email OTP is enabled in Authentication Methods",
            "Add the user to the target SharePoint site or Team",
          ],
        },
      },
      {
        label: "Work/school email from another organization",
        question: "What resource do they need access to?",
        options: [
          {
            label: "SharePoint site or Teams standard/private channel",
            result: {
              accessType: "guest",
              title: "Recommended: Guest Access (B2B Collaboration)",
              description: "Guest Access creates a directory object in your tenant, making the user subject to your Conditional Access policies. This provides the most control over the external user.",
              supported: ["SharePoint sites", "Teams standard channels", "Teams private channels", "M365 Groups"],
              notSupported: [],
              nextSteps: [
                "Invite the user as a guest from the External Access Wizard",
                "Ensure the user's domain is allowed in Entra External Collaboration settings",
                "Add the user to the target resource",
              ],
            },
          },
          {
            label: "Teams shared channel",
            result: {
              accessType: "external",
              title: "Use External Access (B2B Direct Connect)",
              description: "Shared channels require B2B Direct Connect. The external user accesses the channel directly from their own tenant — no guest account is created in your directory.",
              supported: ["Teams shared channels"],
              notSupported: ["SharePoint sites (use Guest Access instead)", "Standard/private channels (use Guest Access instead)"],
              nextSteps: [
                "Configure a cross-tenant access partner policy for the external organization",
                "Ensure B2B Direct Connect inbound is set to Allow",
                "The external organization must also configure outbound B2B Direct Connect",
                "Add the user to the shared channel",
              ],
            },
          },
        ],
      },
      {
        label: "Not sure / other",
        result: {
          accessType: "guest",
          title: "Start with Guest Access (B2B Collaboration)",
          description: "If you're unsure about the email type, Guest Access is the safest starting point. It works with both organizational and personal email addresses.",
          supported: ["SharePoint sites", "Teams standard channels", "Teams private channels"],
          notSupported: ["Teams shared channels (if the domain is personal)"],
          nextSteps: [
            "Try inviting the user as a guest",
            "If the invitation fails, check External Collaboration settings for domain restrictions",
            "Use the Sharing Troubleshooter to diagnose any access issues",
          ],
        },
      },
    ],
  },
  sharepoint: {
    result: {
      accessType: "guest",
      title: "SharePoint uses Guest Access (B2B Collaboration)",
      description: "External users are invited as guest accounts and added to the SharePoint site. Both organizational and personal email addresses are supported. Sharing links ('Anyone' links) can also be used to bypass the guest invitation flow entirely.",
      supported: ["All external email types via guest invitation", "Anonymous access via sharing links"],
      notSupported: ["B2B Direct Connect — SharePoint does not support External Access"],
      nextSteps: [
        "Ensure SharePoint external sharing is enabled (at least 'Existing guests')",
        "Check that the user's domain is allowed in both Entra and SharePoint domain lists",
        "Invite the user and add them to the site, or create a sharing link",
      ],
    },
  },
  teamsStandard: {
    result: {
      accessType: "guest",
      title: "Standard channels use Guest Access (B2B Collaboration)",
      description: "External users must be invited as guests and added to the parent Team. They then have access to all standard channels. Both organizational and personal email addresses are supported.",
      supported: ["Organizational emails", "Personal emails (via Email OTP)"],
      notSupported: [],
      nextSteps: [
        "Invite the user as a guest to the tenant",
        "Add them to the Team",
        "They will automatically have access to all standard channels",
      ],
    },
  },
  teamsPrivate: {
    result: {
      accessType: "guest",
      title: "Private channels use Guest Access (B2B Collaboration)",
      description: "Private channels use Guest Access. The guest must be a member of the parent Team first, then added to the private channel specifically. Both organizational and personal email addresses are supported.",
      supported: ["Organizational emails", "Personal emails (via Email OTP)"],
      notSupported: [],
      nextSteps: [
        "Invite the user as a guest to the tenant",
        "Add them to the parent Team first",
        "Then add them to the specific private channel",
      ],
    },
  },
  teamsShared: {
    result: {
      accessType: "external",
      title: "Shared channels use External Access (B2B Direct Connect)",
      description: "Shared channels allow users from other M365 organizations to participate without being added to your directory. This requires cross-tenant access policies configured on BOTH tenants. Personal email addresses (Gmail, Yahoo, etc.) are NOT supported.",
      supported: ["Work/school accounts from other M365 organizations"],
      notSupported: [
        "Personal emails (Gmail, Yahoo, Outlook.com) — use a standard or private channel instead",
        "Accounts from organizations without Microsoft 365",
      ],
      nextSteps: [
        "Verify the external user has a work/school account",
        "Configure a cross-tenant access partner policy",
        "Ensure B2B Direct Connect is allowed inbound AND the external org allows outbound",
        "Add the user to the shared channel",
      ],
    },
  },
};
