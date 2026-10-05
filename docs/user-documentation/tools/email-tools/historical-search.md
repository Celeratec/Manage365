# Historical Search

Historical Search runs asynchronous message trace and mail protection reports inside Exchange Online, covering up to 90 days of data in a single search. Where Message Trace answers "where is this message right now", Historical Search produces a downloadable CSV report over a longer window: the report is prepared by Exchange Online in the background and delivered when it completes. It shares the Message Trace page as its second tab.

{% hint style="info" %}
Historical searches cover up to <mark style="color:blue;">90 days</mark> of data and return up to <mark style="color:blue;">100,000 rows</mark> per report as CSV. Each tenant may start <mark style="color:blue;">250 searches per day</mark>, and cancelled searches still count toward that quota. Large searches can take several hours to complete.
{% endhint %}

{% hint style="warning" %}
**Downloading the CSV requires a customer-tenant admin login.** Microsoft's report download endpoint is not GDAP-aware, so a delegated partner session cannot retrieve the file. To get a completed report, either sign in to the customer tenant as an admin holding the Message Tracking role (Global Administrator or Exchange Administrator) and use **Download CSV** there, or set a **Notify Address** in the customer tenant when starting the search so Exchange Online emails the CSV on completion. Starting, monitoring and cancelling searches all work normally over delegated access; only the file download is affected.
{% endhint %}

## Search Jobs

The table lists the searches submitted in the last 10 days, refreshed from Exchange Online each time the page loads.

| Column       | Description                                                                                             |
| ------------ | ------------------------------------------------------------------------------------------------------- |
| Report Title | The name given to the search when it was started.                                                       |
| Report Type  | The kind of report requested, such as Message trace or Defender for Office 365.                          |
| Status       | Where the job is in its lifecycle: Not Started, In Progress, Done or Cancelled.                          |
| Job Progress | Exchange Online's progress description for the job.                                                     |
| Rows         | The number of rows the finished report contains.                                                        |
| Submit Date  | When the search was started, in UTC.                                                                    |
| Start Date   | The beginning of the period the report covers.                                                          |
| End Date     | The end of the period the report covers.                                                                |

## Table Actions

<table><thead><tr><th>Action</th><th>Description</th><th data-type="checkbox">Bulk Action Available</th></tr></thead><tbody><tr><td>Download CSV</td><td>Downloads the finished report. Only available once the job's status is Done.</td><td>false</td></tr><tr><td>Cancel Search</td><td>Cancels a job that has not started running yet. Once a job is In Progress it can no longer be cancelled, and a cancelled job still counts toward the daily quota.</td><td>false</td></tr></tbody></table>

## New Historical Search

**New Historical Search** opens a panel to start a search. At least one sender address, recipient address or message ID must be provided.

| Option              | Description                                                                                                                                                       |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Report Title        | A name for the report, shown in the job list and in the notification email.                                                                                       |
| Report Type         | The report to produce: Message trace, Message trace detail, Defender for Office 365 (ATP), Spam, Spoof, DLP, Unified DLP, Transport rule, Connector, Outbound security or P2 sender attribution. |
| Start Date          | The beginning of the period to report on, up to 90 days back.                                                                                                     |
| End Date            | The end of the period to report on.                                                                                                                               |
| Sender Addresses    | Sending addresses to filter on, up to 100. Unlike Message Trace, wildcards such as `*@contoso.com` are supported here.                                            |
| Recipient Addresses | Receiving addresses to filter on, up to 100. Wildcards are supported.                                                                                             |
| Message ID          | The internet message ID of a specific message. More than one may be entered, separated by commas.                                                                 |
| Direction           | Restrict the report to Received or Sent messages, or leave on All.                                                                                                |
| Delivery Status     | Restrict the report to messages that were Delivered, Expanded or Failed.                                                                                          |
| Original Client IP  | Restricts results to messages originating from this client IP address.                                                                                            |
| Notify Address      | An internal address to email when the report is ready.                                                                                                            |

{% hint style="warning" %}
Searching a distribution group's address may not return every message sent to its members. For complete results, search the individual recipient addresses instead.
{% endhint %}

{% include "../../../../.gitbook/includes/feature-request.md" %}
