# User Reported Messages

This tab lists the messages users have reported as phishing, junk, or not junk through the Microsoft report buttons in Outlook, so reports can be reviewed with the same tooling the Email tab offers for quarantined messages: preview the message safely, read its headers, download the EML, and trace its delivery, all without going into the Defender portal.

The list comes from the Microsoft Defender Submissions store, so it carries every user submission the tenant has, including Microsoft's verdict where the report was sent on to Microsoft for analysis.

## Filters

| Filter               | Shows                                            |
| -------------------- | --------------------------------------------------- |
| Reported as Phishing | Messages the user reported as phishing.          |
| Reported as Junk     | Messages the user reported as junk.              |
| Reported as Malware  | Messages the user reported as malware.           |
| Reported as Not Junk | Messages the user reported as incorrectly caught. |

## Table Details

The properties returned are for the Microsoft Graph email threat submissions API. For more information please see the [Microsoft documentation](https://learn.microsoft.com/graph/api/security-emailthreatsubmission-list-emailthreats).

Reports are listed newest first. This list is loaded per tenant, so select a specific tenant to view its reported messages.

## Report Details

**More Info** opens a flyout with the submission record: when the message was received and reported, the sender, sending IP, recipient, who reported it and as what category, the submission status, and Microsoft's analysis verdict where one exists. Fields with no value are left out rather than shown empty. The actions offered in the table are repeated at the foot of the flyout.

## Table Actions

<table><thead><tr><th>Action</th><th>Description</th><th data-type="checkbox">Bulk Action Available</th></tr></thead><tbody><tr><td>Preview Message</td><td>Renders the reported message safely inside CIPP, without loading remote content or executing anything in it. Greyed out where the report carries no message ID.</td><td>false</td></tr><tr><td>View Message Headers</td><td>Shows the full internet headers of the reported message. Greyed out where the report carries no message ID.</td><td>false</td></tr><tr><td>Download Message (.eml)</td><td>Downloads the reported message as an <code>.eml</code> file for offline analysis. Greyed out where the report carries no message ID.</td><td>false</td></tr><tr><td>View Message Trace</td><td>Runs a message trace on the reported message and shows each delivery event. Greyed out where the report carries no message ID.</td><td>false</td></tr><tr><td>Block Sender</td><td>Adds the sender to the tenant's <a data-mention href="../tenant-allow-block-lists.md">tenant-allow-block-lists.md</a> as a blocked sender, with an optional note and expiration choice. Greyed out where the report has no sender address.</td><td>true</td></tr><tr><td>More Info</td><td>Opens the Extended Info flyout with the full details for the selected row.</td><td>false</td></tr></tbody></table>

## Where the message content comes from

The Submissions store itself only holds the report, not the message, so for the preview, header, and download actions CIPP retrieves the message content in two steps: it first looks for the message in quarantine and exports it from there, and when the message was never quarantined it falls back to reading the copy still in the recipient's (or reporter's) mailbox through the Graph API.

{% hint style="info" %}
The mailbox fallback needs the `Mail.Read` application permission on your Secure Application Model application, which CIPP does not request by default. Without it, preview and download still work for reported messages that are in quarantine, and the actions report a clear error for the rest. The remaining actions on this page work without it.
{% endhint %}

{% include "../../../../../.gitbook/includes/feature-request.md" %}
