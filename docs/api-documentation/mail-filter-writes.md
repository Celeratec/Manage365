# Mail filter writes

These endpoints change Exchange Online and Defender mail filtering for one managed tenant. They are the write path for preset security policies, custom anti-spam, anti-phish, and anti-malware policies, inbound-connector Enhanced Filtering, mailbox junk senders, and Focused Inbox.

Each write does the same four things before it changes the tenant:

1. It reads the current configuration and keeps that snapshot.
2. It requires a numeric `ticketNumber` and records the caller, the ticket, and the change.
3. It returns a `rollback` payload whose commands restore the snapshot.
4. With `dryRun` set to `true`, it returns the diff and the rollback payload and does not change the tenant.

Preset and custom policy changes that would leave the tenant with weaker protection than it has now are rejected. Send `allowWeakerProtection: true` to apply that change anyway. The audit row records the override.

Authentication and tenant scope are the same as the rest of the API. The caller needs the role on each endpoint, and the tenant has to be one they are allowed to manage.

## ExecPresetSecurityPolicy

`Exchange.SpamFilter.ReadWrite`

Turns the Standard or Strict preset on or off, and changes who it covers. The same change is applied to `EOPProtectionPolicyRule` and, when the tenant has one, `ATPProtectionPolicyRule`.

| Field | Description |
| --- | --- |
| tenantFilter | Tenant to change. |
| ticketNumber | Numeric ticket ID. |
| preset | `Standard` or `Strict`. |
| state | `Enable` or `Disable`. Omit it to change scope only. |
| users, groups, domains | Recipients the preset covers. An empty list clears that condition. |
| exceptUsers, exceptGroups, exceptDomains | Recipients excluded from the preset. |
| dryRun | `true` returns the diff and does not apply it. |
| allowWeakerProtection | `true` allows a disable, a smaller scope, or a new exclusion. |

Disabling a preset that is on, removing a user, group, or domain from an enabled preset, or adding an exclusion is weaker protection.

## ExecCustomMailFilterPolicy

`Exchange.SpamFilter.ReadWrite`

Creates, updates, or deletes a custom policy and its rule.

| Field | Description |
| --- | --- |
| policyType | `AntiSpam`, `AntiPhish`, or `AntiMalware`. |
| operation | `Create`, `Update`, or `Delete`. |
| name | Policy name. `Default` and the built-in preset policies cannot be deleted. |
| ruleName | Rule name. Defaults to the policy name. |
| bulkThreshold | Anti-spam bulk threshold from 1 to 9. A higher number lets more bulk mail through. |
| spamAction, highConfidenceSpamAction, bulkSpamAction | `MoveToJmf`, `AddXHeader`, `ModifySubject`, `Redirect`, `Delete`, or `Quarantine`. |
| targetedUserProtectionAction, targetedDomainProtectionAction, mailboxIntelligenceProtectionAction | `NoAction`, `BccMessage`, `Redirect`, `MoveToJmf`, `Delete`, or `Quarantine`. |
| enableFileFilter | Turns the common attachment filter on or off. |
| fileTypes | Extensions the malware filter blocks. |
| fileTypeAction | `Reject` or `Quarantine`. |
| enabled, priority, sentTo, sentToMemberOf, recipientDomainIs | Rule state, priority, and scope. A new rule needs users, groups, or domains. |

A new policy copies any omitted action from the tenant's current Default policy, so the new policy is not quieter than the one it can override. Quarantine, Delete, and Reject are the same strength. Moving from one of those to junk-folder delivery, raising the bulk threshold, turning the file-type filter off, removing a file type, disabling an enabled rule, or deleting an enabled custom policy is weaker protection.

The cmdlets are `New-`, `Set-`, and `Remove-` for `HostedContentFilterPolicy`, `AntiPhishPolicy`, and `MalwareFilterPolicy`, and the matching rule cmdlets.

## ExecInboundConnectorEnhancedFiltering

`Exchange.Connector.ReadWrite`

Sets `EFSkipIPs`, `EFSkipLastIP`, and `EFUsers` on an inbound connector with `Set-InboundConnector`. Send one or more of `efSkipIPs`, `efSkipLastIP`, and `efUsers`. `identity` is the connector name.

## ExecMailboxJunkConfiguration

`Exchange.SpamFilter.ReadWrite`

Adds or removes trusted and blocked senders for one mailbox. The current list is read and merged, then written back with `TrustedSendersAndDomains` or `BlockedSendersAndDomains`.

`Set-MailboxJunkEmailConfiguration -TrustedSendersToAdd` fails through the Exchange Online REST proxy, so this endpoint does not use it. `ExecMailboxSafeSender` uses the same merge when it adds one safe sender.

| Field | Description |
| --- | --- |
| mailbox | Mailbox to update. |
| trustedSendersToAdd, trustedSendersToRemove | Safe senders or domains. |
| blockedSendersToAdd, blockedSendersToRemove | Blocked senders or domains. |

A value in both the add and remove lists is removed. Wildcards are rejected.

## ExecFocusedInbox

`Exchange.Mailbox.ReadWrite`

| Field | Description |
| --- | --- |
| scope | `Mailbox` or `Organization`. |
| mailbox | Required when the scope is `Mailbox`. |
| enabled | `true` or `false`. |

Mailbox scope calls `Set-FocusedInbox`. Organisation scope calls `Set-OrganizationConfig -FocusedInboxOn`.

## Response

A successful call, a dry run, and a blocked call all return the same shape:

| Field | Description |
| --- | --- |
| Results | What happened. |
| Applied | `true` only when Exchange was changed. |
| DryRun | `true` when nothing was applied because this was a dry run. |
| Blocked | `true` when the protection floor rejected the change. |
| BlockReasons | Which fields would have been weaker. |
| TicketNumber, Caller | The ticket and the person who sent the call. |
| Diff | Each changed field with its previous value, new value, and whether it is weaker. |
| Snapshot | The configuration read before the change. |
| Rollback.Commands | Exchange cmdlets and parameters that restore the snapshot. |

Validation errors return HTTP 400. A change Exchange refuses after the snapshot was taken returns HTTP 500, and the body still includes the snapshot and the rollback commands.
