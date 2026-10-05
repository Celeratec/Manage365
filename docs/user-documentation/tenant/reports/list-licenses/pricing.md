# Pricing

The License Pricing tab holds the monthly per-seat price of every licence, which the [optimization.md](optimization.md "mention") tab uses to cost a tenant's licences and value its suggestions. CIPP ships with estimated prices, and you can override any of them with what you actually pay. Prices are shared by every tenant, so the page is the same whichever tenant is selected.

## Action Buttons

### Currency

Chooses the currency the prices are shown and set in. The list offers every currency that has prices, either shipped estimates or your own overrides. Prices are held separately per currency and are never converted, so a licence priced only in another currency shows no price here. The choice is remembered in this browser and shared with the Optimization tab.

## Table Details

| Column               | Description                                                                                                                                                            |
| -------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Product Display Name | The licence's product name.                                                                                                                                            |
| Sku Part Number      | The licence's part number, for example `O365_BUSINESS_PREMIUM`.                                                                                                        |
| Monthly Price        | The price per seat per month in the selected currency. Empty when the licence has no price in that currency.                                                           |
| Currency             | The currency of the price.                                                                                                                                             |
| Source               | Where the price comes from: **Override** for a price you set, **Estimate** for the estimate shipped with CIPP, or **Unknown** when there is no price in this currency. |
| Sku Id               | The licence's SKU identifier.                                                                                                                                          |

{% hint style="info" %}
An override always takes priority over the shipped estimate. Setting prices you actually pay, and pricing the licences marked **Unknown**, makes the figures on the Optimization tab more accurate, since a licence with no price is left out of its savings and plan suggestions.
{% endhint %}

## Table Actions

<table><thead><tr><th>Action</th><th>Description</th><th data-type="checkbox">Bulk Action Available</th></tr></thead><tbody><tr><td>Set / override price</td><td>Sets your own monthly price per seat for the licence, in the currency currently selected. The price replaces the shipped estimate for that currency only, and applies to every tenant.</td><td>true</td></tr><tr><td>Remove override</td><td>Removes your price for the licence in that currency after you confirm, so it falls back to the shipped estimate. Greyed out unless the row's source is <strong>Override</strong>.</td><td>true</td></tr><tr><td>More Info</td><td>Opens the Extended Info flyout with the full details for the selected row.</td><td>false</td></tr></tbody></table>

{% include "../../../../../.gitbook/includes/feature-request.md" %}
