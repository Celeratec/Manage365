---
name: Manage365
description: Multi-tenant M365 administration for MSPs who value speed over ceremony
colors:
  dashboard-blue: "#53A5DB"
  dashboard-blue-deep: "#2D4A5E"
  dashboard-blue-light: "#7FC4E8"
  navy-primary: "#003049"
  orange-accent: "#F77F00"
  indigo-accent: "#635dff"
  purple-accent: "#9E77ED"
  success: "#6BBDC4"
  info: "#5BBEDB"
  warning: "#8FD19E"
  error: "#E09090"
  neutral-50: "#FAFAFA"
  neutral-100: "#F5F5F5"
  neutral-200: "#EEEEEE"
  neutral-300: "#E0E0E0"
  neutral-400: "#BDBDBD"
  neutral-500: "#9E9E9E"
  neutral-600: "#757575"
  neutral-700: "#616161"
  neutral-800: "#424242"
  neutral-900: "#212121"
  surface-dark: "#181818"
  surface-dark-elevated: "#1E1E1E"
typography:
  display:
    fontFamily: "Inter, sans-serif"
    fontSize: "48px"
    fontWeight: 600
    lineHeight: 1.5
  headline:
    fontFamily: "Inter, sans-serif"
    fontSize: "32px"
    fontWeight: 600
    lineHeight: 1.5
  title:
    fontFamily: "Inter, sans-serif"
    fontSize: "24px"
    fontWeight: 600
    lineHeight: 1.5
  body:
    fontFamily: "Inter, sans-serif"
    fontSize: "14px"
    fontWeight: 400
    lineHeight: 1.6
  label:
    fontFamily: "Inter, sans-serif"
    fontSize: "12px"
    fontWeight: 500
    lineHeight: 1.75
rounded:
  sm: "4px"
  md: "6px"
  lg: "8px"
  pill: "48px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "16px"
  lg: "24px"
  xl: "32px"
components:
  button-primary:
    backgroundColor: "{colors.dashboard-blue}"
    textColor: "#FFFFFF"
    rounded: "{rounded.md}"
    padding: "8px 16px"
  button-primary-hover:
    backgroundColor: "{colors.dashboard-blue-deep}"
    textColor: "#FFFFFF"
  input-filled:
    backgroundColor: "transparent"
    textColor: "{colors.neutral-900}"
    rounded: "{rounded.md}"
    padding: "0 12px"
  chip-default:
    backgroundColor: "{colors.neutral-200}"
    textColor: "{colors.neutral-800}"
    rounded: "{rounded.md}"
---

# Design System: Manage365

## 1. Overview

**Creative North Star: "The Control Room"**

Manage365 is a control room for MSP technicians managing dozens of Microsoft 365 tenants. Every element exists to surface information and enable action. There is no marketing, no onboarding friction, no decorative flourish. The interface assumes expertise and rewards it with density and speed.

The design philosophy is utilitarian without being ugly. Information is compressed but readable. Actions are discoverable but not intrusive. The system trusts users to know what they're doing and gets out of their way.

This is not a consumer app. It's not trying to delight first-time visitors or explain itself. It's a daily driver for professionals who will spend hundreds of hours in it. Efficiency compounds. Every pixel counts.

**Key Characteristics:**

- **Information-dense** — Tables, cards, and dashboards pack data tight. White space is for structure, not aesthetics.
- **Action-oriented** — Primary actions are visible and reachable. Bulk operations are first-class citizens.
- **Context-preserving** — Tenant switching, navigation, and workflows never lose your place.
- **Quiet confidence** — The interface doesn't shout. Status colors are muted. Shadows are structural, not decorative.

## 2. Colors

A restrained palette built around Dashboard Blue with semantic colors for status. The primary accent appears sparingly — mostly on interactive elements and active states.

### Primary

- **Dashboard Blue** (#53A5DB / oklch(70% 0.11 230)): Primary actions, links, active nav items, and focus rings. The familiar blue of system interfaces — draws attention without shouting.
- **Dashboard Blue Deep** (#2D4A5E): Hover states for primary buttons. Adds weight when pressed.
- **Dashboard Blue Light** (#7FC4E8): Chip backgrounds, subtle highlights, secondary accents.

### Secondary (configurable presets)

- **Navy Primary** (#003049): Alternative preset. Darker, more serious.
- **Orange Accent** (#F77F00): Alternative preset. High energy, action-forward.
- **Indigo Accent** (#635dff): Alternative preset. Modern, slightly playful.
- **Purple Accent** (#9E77ED): Alternative preset. Softer, creative.

### Semantic

- **Success** (#6BBDC4): Teal-cyan. Completed actions, healthy status, pass states.
- **Info** (#5BBEDB): Cyan. Informational badges, hints, neutral status.
- **Warning** (#8FD19E): Mint-green. Unusual for warning — intentionally soft to avoid alarm fatigue.
- **Error** (#E09090): Muted rose. Failures, blocked actions, critical status. Soft enough for frequent display.

### Neutral

- **Neutral 50–100** (#FAFAFA, #F5F5F5): Light mode backgrounds. Paper surfaces.
- **Neutral 200–400** (#EEEEEE, #E0E0E0, #BDBDBD): Borders, dividers, disabled states.
- **Neutral 500–600** (#9E9E9E, #757575): Secondary text, icons.
- **Neutral 700–900** (#616161, #424242, #212121): Primary text, headings, emphasis.
- **Surface Dark** (#181818): Dark mode default background.
- **Surface Dark Elevated** (#1E1E1E): Dark mode paper/card surfaces.

### Named Rules

**The Dashboard Blue Rule.** The primary accent is used on interactive elements: buttons, links, active states, focus rings. It does not appear on static informational content. If something is blue, it should be clickable or indicate selection.

**The Soft Semantic Rule.** Status colors are intentionally muted. Errors and warnings appear frequently in admin tools; screaming red and orange cause alarm fatigue. Our semantic colors are visible but calm.

## 3. Typography

**Display Font:** Inter (with system sans-serif fallback)
**Body Font:** Inter (with system sans-serif fallback)

**Character:** Inter is the workhorse of modern UI. It's neutral, highly legible at small sizes, and renders crisply on screens. No personality, by design — the content is the personality.

### Hierarchy

- **Display** (600, 48px, 1.5): Page titles, dashboard heroes. Rare.
- **Headline** (600, 32px, 1.5): Section headers, modal titles.
- **Title** (600, 24px, 1.5): Card headers, panel titles.
- **Subtitle** (500, 16px, 1.75): Sub-section labels, emphasized body text.
- **Body** (400, 14px, 1.6): Primary content, table cells, descriptions. Max line length 75ch.
- **Label** (500, 12px, 1.75): Form labels, chip text, metadata.
- **Caption** (400, 11px, 1.6): Timestamps, fine print, tertiary information.

### Named Rules

**The 14px Body Rule.** Body text is 14px, not 16px. Admin interfaces benefit from density. Users are close to their screens and focused.

**The 600 Heading Rule.** All headings use weight 600 (semibold), never bold (700). This creates clear hierarchy without shouting.

## 4. Elevation

Structural shadows that clearly define what's floating versus grounded. Modals, dropdowns, and popovers cast visible shadows. Cards on flat surfaces use minimal or no shadow.

### Shadow Vocabulary

- **Level 1** (`0px 1px 2px rgba(0, 0, 0, 0.24)`): Subtle lift. Buttons at rest, chips.
- **Level 4** (`0px 1px 5px rgba(0, 0, 0, 0.24)`): Cards on surfaces. Gentle separation.
- **Level 8** (`0px 4px 6px rgba(0, 0, 0, 0.24)`): Dropdown menus, tooltips. Clear float.
- **Level 16** (`0px 10px 15px rgba(0, 0, 0, 0.24)`): Modals, dialogs. Prominent overlay.
- **Level 24** (`0px 25px 50px rgba(0, 0, 0, 0.24)`): Large modals, full-screen overlays.

### Named Rules

**The Structural Shadow Rule.** Shadows communicate z-index, not decoration. If it floats, it has a shadow. If it's inline, it doesn't. Background tint handles surface layering.

**The Dark Mode Overlay Rule.** In dark mode, shadows are less visible. Elevated surfaces use lighter backgrounds (#1E1E1E vs #181818) instead of relying solely on shadow.

## 5. Components

### Buttons

- **Shape:** Gently rounded corners (6px radius). Not pill-shaped, not sharp.
- **Primary:** Dashboard Blue background, white text, 8px 16px padding.
- **Hover / Focus:** Background darkens to Dashboard Blue Deep. Focus ring: 2px Dashboard Blue at 25% opacity.
- **Secondary / Ghost:** Transparent background, Dashboard Blue text, subtle border on hover.
- **Ripple:** Disabled. Interaction feedback via color change, not animation.

### Chips

- **Style:** 6px radius, neutral background (light: #EEEEEE, dark: surface elevated), neutral text.
- **State:** Selected chips use Dashboard Blue Light background.
- **Delete icon:** Heroicons XCircle outline.

### Cards / Containers

- **Corner Style:** 6px radius (consistent with other components).
- **Background:** Paper color (white in light mode, #1E1E1E in dark mode).
- **Shadow Strategy:** Level 4 for cards floating on backgrounds. No shadow for inline containers.
- **Border:** None by default. Optional 1px neutral-300 border for subtle definition.
- **Internal Padding:** 24px horizontal, 20px vertical for content. 16px for headers/actions.

### Inputs / Fields

- **Style:** Filled variant with 1px border. 6px radius. Background transparent.
- **Height:** 40px for single-line inputs. Flexible for multiline.
- **Focus:** Border shifts to primary color. Glow: `0px 0px 0px 2px rgba(25, 118, 210, 0.25)`.
- **Error:** Border shifts to error color. No background tint.
- **Disabled:** Reduced opacity (38% text), no interaction.

### Navigation

- **Side nav:** Collapsible, pinnable. 14px item text, 8px icon spacing.
- **Active state:** Dashboard Blue text and icon, subtle alpha background.
- **Hover:** Background alpha (8% in light mode, 8% white in dark mode).
- **Top nav:** Tenant selector prominent, account menu right-aligned.

### Data Tables

- **Header:** 11px uppercase, 600 weight. Sticky on scroll.
- **Rows:** Alternate background optional. Last row has no bottom border.
- **Cell padding:** Compact. Text truncates with ellipsis.
- **Actions:** Inline action menus, bulk action toolbar on selection.

## 6. Do's and Don'ts

### Do:

- **Do** use Dashboard Blue only for interactive elements. If it's blue, it should do something.
- **Do** keep body text at 14px. Density is a feature, not a bug.
- **Do** use structural shadows to communicate elevation. Modals float; inline content doesn't.
- **Do** respect the neutral scale for non-interactive surfaces. Reserve color for status and actions.
- **Do** support both light and dark modes. Dark mode uses elevated surface tints, not just shadows.
- **Do** include visible focus indicators. Keyboard navigation is critical for power users.
- **Do** truncate long content with ellipsis rather than breaking layouts.

### Don't:

- **Don't** mimic Azure Portal. No overwhelming nested menus, no slow page loads, no lost context.
- **Don't** add marketing fluff. No gradient hero sections, no stock photography, no "Get Started" hand-holding.
- **Don't** use 2010s enterprise patterns. No cramped 11px grids, no Windows XP iconography, no gray-on-gray.
- **Don't** over-design for aesthetics. No excessive white space that wastes screen real estate.
- **Don't** use border-left greater than 1px as a colored accent stripe. Use background tints or icons instead.
- **Don't** use gradient text (background-clip: text). Solid colors only.
- **Don't** default to glassmorphism or blur effects. They're slow and distracting.
- **Don't** animate CSS layout properties. Transitions on color/opacity/transform only.
- **Don't** use bounce or elastic easing. Ease-out-quart or similar exponential curves.
- **Don't** add loading spinners when data can be prefetched or shown progressively.
- **Don't** require confirmation dialogs for reversible actions.
