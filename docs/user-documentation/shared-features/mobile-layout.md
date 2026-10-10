# Mobile Layout

CIPP adapts to the width of the window it is running in, so the same pages work on a phone or a tablet as they do on a desktop. Nothing is removed on a smaller screen: the same tables, actions, filters and wizards are all there, presented in a form that fits the space and can be driven with a thumb.

The layout is chosen from the width of the browser window rather than from the device you are using, so a narrow window on a desktop gets the same treatment as a phone.

| Window width         | What changes                                                                                                                      |
| -------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| Below roughly 1200px | The left-hand navigation collapses behind a menu button, the tenant selector becomes a chip in the menu bar, and the search and display mode icons move into your account menu.                   |
| Below roughly 900px  | Tables become card lists, dialogs and flyouts take the full screen, and page actions move to a button in the bottom right corner. |

Pages are laid out to fit the width of the screen, so scrolling is vertical. Where content genuinely cannot be made narrower, such as a marketing email built around a fixed-width layout, it scrolls sideways within its own card rather than moving the page beneath it.

## Menu Bar

On a narrow window the menu bar carries the menu button, the current tenant, notifications and your account. The controls that no longer fit move rather than disappear.

| Control          | Where it goes                                                                                                                                                                    |
| ---------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Navigation       | Behind the menu button on the far left. The menu opens as a drawer that can also be swiped closed.                                                                                |
| Tenant selector  | A chip in the menu bar showing the current tenant, which opens a full-screen picker. See [tenant-select.md](menu-bar/tenant-select.md "mention").                                 |
| Universal search | The **Universal Search** entry in your account menu. See [universal-search.md](menu-bar/universal-search.md "mention").                                                           |
| Light/dark mode  | The **Light Mode** or **Dark Mode** entry in your account menu.                                                                                                                   |
| Help and support | On a phone, the help links and **Clear Cache and Reload** move into your account menu, because the speed dial's corner is given to page actions. See [speed-dial.md](speed-dial.md "mention"). |

The navigation drawer has a search box at the top. Typing in it narrows the menu to matching entries and opens the sections they sit in, so a page several levels down can be reached without expanding each level by hand.

## Tables

Below roughly 900px, tables are presented as a list of cards, one card per row. Each card is built from the columns the table is already showing.

| Part of the card   | What it holds                                                                        |
| ------------------ | -------------------------------------------------------------------------------------- |
| Title              | The row's name, such as a display name, device name or subject.                       |
| Subtitle           | The row's identifier, such as a user principal name, mail address or serial number.   |
| Chips              | Up to three status values, such as an account state, severity or result.              |
| Details            | Up to three further fields, shown as label and value pairs.                           |
| **+N more fields** | Everything else on the row. Selecting it opens the full detail view.                  |

Where a row has more information than the card shows, tapping the card opens the same detail flyout that **More Info** opens on a desktop. Tapping the button in the card's top right corner opens the row's actions, exactly the actions the ellipsis offers on a desktop. Text on a card can be selected and copied, and dragging to select it does not open the flyout.

The first batch of cards is drawn using your **Default Page Size** preference, up to a maximum of 50, so a large page size does not turn into hundreds of cards on a phone. A count beneath the list reads **Showing 50 of 340**, with a **Load 50 more** button while there is more to show.

### Controls Above the List

A row of controls sits above the cards and stays in place as you scroll.

| Control       | Description                                                                                                                                           |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Search        | Filters the list as you type, matching the same values the desktop search box matches.                                                                |
| **Select**    | Enters selection mode, described below. Shown only where the table supports selecting rows.                                                           |
| Sort          | Opens a list of the columns you can sort on. Tapping one cycles it through ascending, descending, and off. One column sorts at a time.                 |
| Table options | Opens the sheet described below. It carries a badge counting the filters currently applied.                                                           |
| Table view    | Switches this table to the full desktop table, described under [#switching-to-the-full-table](mobile-layout.md#switching-to-the-full-table "mention"). |

The **Table options** sheet gathers everything the desktop toolbar's menus hold.

| Section            | Description                                                                                                       |
| ------------------ | ------------------------------------------------------------------------------------------------------------------- |
| Data source        | The Live and Cached switch, and the **Sync** button, on pages that offer them.                                    |
| Presets            | The page's table filter presets, as chips. The active preset is ticked.                                           |
| Graph filters      | The page's Graph filter presets, where the page is backed by Graph Explorer.                                      |
| Reset all filters  | Clears the search box and every applied filter.                                                                   |
| Edit graph filters | Opens the filter builder, on pages backed by Graph Explorer.                                                      |
| Export to CSV/PDF  | The same exports the desktop **Export** menu offers.                                                              |
| View API response  | Opens the raw JSON returned by the call behind the table.                                                         |
| Refresh data       | Reloads the table.                                                                                                |
| Fields shown       | Ticks and unticks the columns the cards are built from, which is the same column selection the desktop table uses. |

Filters, presets, saved column selections and the **Save last used table filter** preference all behave exactly as they do on a desktop, because the card list and the table are driven by the same controls underneath.

### Selecting Rows

Selecting **Select** puts a checkbox on every card. Tapping a card then ticks it rather than opening its details.

A bar appears at the foot of the screen with the number of rows selected, a **Select all** button covering every row that matches the current filters, an **Actions** button opening the bulk actions available, and **Done** to leave selection mode.

### Switching to the Full Table

The table icon above the list switches to the full desktop table for the page you are on, complete with column headers, column filters and horizontal scrolling. A card icon in that table's toolbar switches back.

The switch applies to that table only and lasts as long as you stay on the page. To change what tables do by default, use the **Table view on small screens** preference described in [user-settings.md](menu-bar/user-settings.md "mention"), which offers **Automatic (cards on mobile)**, **Always card list**, and **Always classic table**.

## Detail Flyouts

Detail flyouts fill the screen and read as a page of their own, with a back arrow in the top left. Where the flyout supports moving between rows, the previous and next controls sit in a bar at the foot of the screen rather than in the header.

Your device's back gesture closes the flyout and returns you to the list, with the list still loaded and still scrolled where you left it, rather than leaving the page entirely. The same applies to the navigation drawer, bottom sheets and other overlays: back closes the topmost one first.

## Page Actions

Where a page has its own actions, such as adding a record or running a report, they are collected behind a round button in the bottom right corner. Selecting it opens the full list.

{% hint style="info" %}
On a desktop this corner holds the speed dial. On a phone the speed dial stands down so that page actions can use the corner, and the help and support options it offers move into your account menu.
{% endhint %}

## Pages with Tabs

On a page with tabs, the tab bar is replaced by a single control showing the view you are on. Selecting it opens the list of views, and choosing one navigates to it. On pages with a heading, such as an individual user or device, the control sits beside the heading as a chip.

Pages with only one view show no control at all, since there is nowhere else to go.

Where the view you are on carries the same name as the page, the page's own heading is not printed above the control, so the name appears once rather than twice.

## Breadcrumbs

The breadcrumb trail stays on one line. Leading entries collapse behind an ellipsis that expands them when selected, and the bookmark button moves to the right-hand edge of the row.

On the Home page and the dashboard the trail is hidden altogether, since it repeats what the page and its view picker already say. See [breadcrumb-navigation.md](breadcrumb-navigation.md "mention").

## Notices

Pages that open with a long explanatory notice show the first three lines of it, followed by a **Show more** link that expands the rest and a **Show less** link to collapse it again, so the page's actual content is not pushed below the fold. Notices short enough to fit are shown in full with no link.

## Forms, Dialogs and Wizards

Dialogs use the full width of the screen, and their buttons stack with the main action at the top so it falls under your thumb.

Where a form places controls side by side, they stack into a single column instead. This applies both to rows of fields, such as the name, type and value of a row in Table Maintenance, and to whole panes, such as the summary that sits beside the permission list when you edit a CIPP role.

Wizards replace the horizontal step indicator with a progress bar reading **Step 2 of 5**, the name of the step you are on, and how far through you are. A step that is loading or has failed is reflected in the bar, as it is in the step icons on a desktop. **Back**, **Next** and **Submit** stack, with the action that moves you forward on top.

Text fields are rendered slightly larger on touch devices, which stops mobile browsers zooming in when you tap into a field and leaving the page zoomed afterwards.

{% hint style="info" %}
Tooltips do not open on touch devices. A tooltip is a hover affordance, and on a touch screen a long press would leave one stuck to the screen while you scroll. Anything a tooltip explains is also available elsewhere on the page.
{% endhint %}

## Reports

Report previews are laid out for the screen rather than shown as an embedded document, and choosing a test suite or one of its actions is done from a list you pick from.

PDF reports are handed to your device rather than displayed in place, because mobile browsers cannot scroll an embedded PDF. You are shown the report's name and size with a button to open it in your device's own PDF viewer, which can scroll, zoom, print and share it, and a download button where the report offers one.

{% include "../../../.gitbook/includes/feature-request.md" %}
