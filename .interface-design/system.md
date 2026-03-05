# VANTA Design System

## Direction & Feel

**Metaphor:** "Escritorio ordenado de un contador eficiente" — warm, professional, organized.
**Temperature:** Warm off-white surfaces, emerald green primary, warm blacks for dark mode.
**Density:** Medium — comfortable spacing, not cramped but not wasteful.
**Personality:** Reliable, precise, approachable. Like a well-organized office, not a tech startup.

## Signature Element

**Document Lifecycle Status Bar** — A stepped progress indicator showing document states (Borrador > Confirmada > Recibida). Completed steps show a checkmark with primary color, current step has a card with shadow, cancelled states show in red. Used across all document types (Sales, Quotes, Purchase Orders, Dispatch Guides).

Partial: `shared/documents/_status_bar.html.erb`
CSS: `.doc-status-bar`, `.doc-status-step`

## Color Palette

### Light Mode
- `--background: #F9F8F6` (warm off-white)
- `--foreground: #1A1A1A` (near-black)
- `--card: #FFFFFF`
- `--muted: #F0EEEB` (warm gray)
- `--muted-foreground: #6B6560` (warm mid-gray)
- `--primary: #059669` (emerald green)
- `--primary-foreground: #FFFFFF`
- `--border: rgba(0,0,0,0.08)` (subtle, disappears when not looking)
- `--destructive: #DC2626`
- `--input-background: #F5F3F0` (slightly darker than card, "inset" feel)

### Dark Mode
- `--background: #111111` (warm black, not gray-800)
- `--foreground: #E8E6E3`
- `--card: #1A1A1A`
- `--muted: #252525`
- `--muted-foreground: #9C9890`
- `--primary: #34D399` (lighter emerald for contrast)
- `--border: rgba(255,255,255,0.08)`
- `--input-background: #1F1F1F`

### Semantic Colors
- Success: `#059669` / `#34D399` (same as primary)
- Warning: `#D97706` / `#FBBF24`
- Info: `#2563EB` / `#60A5FA`
- Destructive: `#DC2626` / `#F87171`

## Depth Strategy

**Borders-only** — Clean, technical. No shadows on cards.
- Cards: `border border-border rounded-xl p-5`
- Only exception: status bar current step gets a subtle shadow for emphasis
- Sidebar: same background as canvas, separated by border only

## Spacing

**Base unit:** 4px (Tailwind default)
- Micro: `gap-1`, `gap-1.5` (icon gaps)
- Component: `p-3`, `p-4`, `p-5` (card padding, button padding)
- Section: `space-y-4`, `gap-4` (between cards in a grid)
- Page: `space-y-6` (between major sections)

## Border Radius

- Inputs/buttons: `rounded-lg` (8px)
- Cards: `rounded-xl` (12px)
- Badges: `rounded-full`
- Consistent scale, never mix sharp and soft

## Typography

### Hierarchy
- **Page title:** `text-xl font-semibold text-foreground` (in layout header via `content_for :page_title`)
- **Card section header (show pages):** `text-xs font-medium text-muted-foreground uppercase tracking-wide`
- **Card section header (forms):** `text-sm font-semibold text-foreground`
- **Body text:** `text-sm text-foreground`
- **Supporting text:** `text-sm text-muted-foreground`
- **Labels (definition lists):** `text-xs text-muted-foreground`
- **Values (definition lists):** `text-sm font-medium text-foreground mt-0.5`
- **Monospace:** `font-mono` for codes (VTA-001), tax IDs, UUIDs, SKUs
- **Tabular numbers:** `tabular-nums` for all monetary amounts and counts

### Font
System font stack (no custom font loaded). The warmth comes from color and spacing, not typography.

## Component Patterns

### Page Layout
- All pages use `content_for :page_title` (rendered in layout header)
- No redundant h1/p heading blocks inside pages
- Wrapper: `max-w-5xl mx-auto space-y-6` (documents, entities)
- Wrapper: `max-w-7xl mx-auto` (index pages with tables)
- Wrapper: `max-w-4xl mx-auto` (settings, enterprise config)
- Wrapper: `max-w-3xl mx-auto` (simple forms like providers, carriers)

### Headers (Show Pages)
```erb
<div class="flex flex-col sm:flex-row sm:items-start justify-between gap-4">
  <div class="space-y-1">
    <h1 class="text-xl font-semibold text-foreground">...</h1>
    <p class="text-sm text-muted-foreground">...</p>
  </div>
  <div class="flex flex-wrap gap-2">
    <!-- buttons: btn-secondary for nav, btn-primary for main action -->
  </div>
</div>
```

### Info Cards (Show Pages)
```erb
<div class="card">
  <h3 class="text-xs font-medium text-muted-foreground uppercase tracking-wide mb-2">Section Title</h3>
  <dl class="grid grid-cols-1 sm:grid-cols-2 gap-4">
    <div>
      <dt class="text-xs text-muted-foreground">Label</dt>
      <dd class="text-sm font-medium text-foreground mt-0.5">Value</dd>
    </div>
  </dl>
</div>
```

### Tables (Index Pages)
```
- Header row: `bg-muted/40`
- Header cells: `table-th` class (or `px-5 py-2.5 text-xs font-medium text-muted-foreground uppercase`)
- Body cells: `px-5 py-3.5`
- Row hover: `hover:bg-muted/30 transition-colors`
- Action buttons: `table-action-btn` class (icon-only, 28x28px)
- Codes: `font-mono font-medium`
- Amounts: `tabular-nums font-medium text-right`
```

### Form Cards
```erb
<div class="card">
  <h3 class="text-sm font-semibold text-foreground">Section Title</h3>
  <p class="mt-1 text-sm text-muted-foreground">Description.</p>
  <div class="mt-6 grid grid-cols-1 gap-y-6 gap-x-4 sm:grid-cols-6">
    <!-- fields -->
  </div>
</div>
```

### Items Table (in Forms)
- Table header: `bg-muted/50`
- Dashed add section: `border-2 border-dashed border-border rounded-lg`
- Totals: right-aligned `dl` with `w-64`, separated by `border-t`

### Auth Pages (Login, Password Reset, Invitation)
- Centered: `min-h-screen flex items-center justify-center bg-background p-6`
- Container: `max-w-sm`
- Logo: `h-12 w-auto mb-6`
- Title: `text-xl font-semibold`
- Form inside `.card`
- Button: `w-full btn-primary h-11`
- No split layout, no external images, no gradient panels

### Buttons
- `btn-primary`: emerald green, white text
- `btn-secondary`: border, transparent bg
- `btn-destructive`: red
- `btn-success`: green (for "Marcar Recibida" type actions)
- `btn-ghost`: no border, text only

### Badges
- `badge-success`, `badge-warning`, `badge-info`, `badge-secondary`, `badge-destructive`
- All use `rounded-full px-2.5 py-0.5 text-xs font-medium`

### Sidebar
- Light background (same as canvas), border separation
- Icons: `w-4 h-4`
- Grouped sections with `sidebar-nav-section-label`
- Sections: General, Operaciones, Catalogo, Configuracion
- Active item: `bg-primary/10 text-primary`
- Width: 252px expanded, 68px collapsed

### Dashboard
- 4 metric cards in `grid-cols-2 lg:grid-cols-4`
- Quick actions row
- 2 recent activity lists (sales + quotes) in `lg:grid-cols-2`

## Files Reference

- CSS: `app/assets/tailwind/application.css`
- Layout: `app/views/layouts/application.html.erb`
- Sidebar: `app/views/shared/_sidebar.html.erb`
- Status bar: `app/views/shared/documents/_status_bar.html.erb`
- Dashboard: `app/views/dashboard/index.html.erb`
- Empty state: `app/views/shared/table/_empty_state.html.erb`
- Pagination: `app/views/shared/table/_pagination.html.erb`
