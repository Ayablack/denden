---
name: DenDen Desktop Stream Engine
colors:
  surface: '#0d131e'
  surface-dim: '#0d131e'
  surface-bright: '#333945'
  surface-container-lowest: '#080e19'
  surface-container-low: '#161c27'
  surface-container: '#1a202b'
  surface-container-high: '#242a36'
  surface-container-highest: '#2f3541'
  on-surface: '#dde2f2'
  on-surface-variant: '#b9cac5'
  inverse-surface: '#dde2f2'
  inverse-on-surface: '#2b303c'
  outline: '#84948f'
  outline-variant: '#3b4a46'
  surface-tint: '#00dfc4'
  primary: '#70ffe5'
  on-primary: '#00372f'
  primary-container: '#00e5c9'
  on-primary-container: '#006155'
  inverse-primary: '#006b5d'
  secondary: '#4cd6fb'
  on-secondary: '#003642'
  secondary-container: '#00b2d6'
  on-secondary-container: '#003f4e'
  tertiary: '#ffe3c7'
  on-tertiary: '#472a00'
  tertiary-container: '#ffc072'
  on-tertiary-container: '#7a4c00'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#41fcdf'
  primary-fixed-dim: '#00dfc4'
  on-primary-fixed: '#00201b'
  on-primary-fixed-variant: '#005046'
  secondary-fixed: '#b3ebff'
  secondary-fixed-dim: '#4cd6fb'
  on-secondary-fixed: '#001f27'
  on-secondary-fixed-variant: '#004e5f'
  tertiary-fixed: '#ffddb8'
  tertiary-fixed-dim: '#ffb95f'
  on-tertiary-fixed: '#2a1700'
  on-tertiary-fixed-variant: '#653e00'
  background: '#0d131e'
  on-background: '#dde2f2'
  surface-variant: '#2f3541'
typography:
  headline-lg:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
    letterSpacing: -0.015em
  headline-md:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
    letterSpacing: -0.01em
  headline-sm:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '600'
    lineHeight: 24px
    letterSpacing: 0em
  body-lg:
    fontFamily: Inter
    fontSize: 15px
    fontWeight: '400'
    lineHeight: 22px
    letterSpacing: 0em
  body-md:
    fontFamily: Inter
    fontSize: 13px
    fontWeight: '400'
    lineHeight: 18px
    letterSpacing: 0em
  body-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
    letterSpacing: 0.01em
  label-lg:
    fontFamily: Inter
    fontSize: 13px
    fontWeight: '500'
    lineHeight: 18px
    letterSpacing: 0.01em
  label-md:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.02em
  label-sm:
    fontFamily: Inter
    fontSize: 11px
    fontWeight: '500'
    lineHeight: 14px
    letterSpacing: 0.04em
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
spacing:
  gutter: 1rem
  margin: 1.25rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 0.75rem
  space-lg: 1rem
  space-xl: 1.5rem
---

## Brand & Style

The design system establishes a high-performance, distraction-free Windows desktop utility environment built specifically for real-time video/audio streaming administration and playback. The aesthetic prioritizes absolute operational clarity, low eye strain during prolonged sessions, and pixel-precise desktop ergonomics.

Key brand and interaction tenets:
- **Utilitarian Elegance:** Every pixel serves operational purpose. Avoid ornamental clutter, artificial social features, or decorative illustrations.
- **Deep Immersion:** The canvas recedes into deep naval charcoal, allowing content, bitrates, telemetry, and stream previews to command foreground attention.
- **Precision Feedback:** Electric cyan and high-readability neutral tones highlight system state, connection health, and administrative controls instantly.
- **Native Desktop Integration:** Follows high-density desktop paradigms with refined mouse-driven affordances, strict keyboard accessibility, and clean Windows window chrome integration.

## Colors

The palette leverages a layered dark architecture engineered for OLED and high-contrast desktop displays.

### Surface Architecture
- **Surface Canvas (Background):** `#0B0F17` (Deepest Navy Abyss) — Global window frame and inactive titlebar ground.
- **Surface Container (Base Panels):** `#111722` (Charcoal Navy) — Primary application scaffolding, workspace panels, and tab bodies.
- **Surface High (Cards / Modals / Popovers):** `#182030` (Elevated Navy Slate) — Cards, dropdown menus, context menus, and elevated metric panels.
- **Surface Highest (Control Surfaces):** `#222D42` (Interactive States & Inactive Inputs) — Unfocused form fields, secondary button fills, and hovering list items.

### Outlines & Dividers
- **Outline Subtle (Variant):** `#1E293B` — Standard 1px panel dividers, container borders, and quiet table borders.
- **Outline Medium:** `#334155` — Input borders, active component borders, and inactive slider tracks.

### Functional Accents
- **Primary Accent:** `#00E5C9` (Vibrant Cyan) — Primary interaction states, filled CTA buttons, focus halos, buffer health, and active stream indicators.
- **Primary Accent Hover / Variant:** `#00B4D8` (Turquoise Blue) — Hover states on interactive primaries, secondary progress indicators, and informative metadata.
- **Text & Foreground:**
  - **On-Surface Primary:** `#F1F5F9` (Slate Crisp White) — Headings, input values, active metrics, primary labels.
  - **On-Surface Secondary:** `#94A3B8` (Muted Slate) — Unit labels, secondary metadata, table column headers.
  - **On-Surface Disabled:** `#475569` (Dark Slate) — Disabled actions, inactive track outlines.
- **Status & Alerts:**
  - **Warning / Degraded:** `#F59E0B` (Amber) — High latency warnings, frame drops, network jitter.
  - **Destructive / Error:** `#EF4444` (Coral Red) — Disconnects, stream termination, error logs.
  - **Success / Optimal:** `#10B981` (Emerald) — Stable sync, active broadcast confirmation.

## Typography

Typography relies entirely on `Inter` (with native system fallbacks to `Roboto` or `Noto Sans` on Linux/Android if cross-compiled). 

Key usage rules:
- Desktop efficiency prioritizes `body-md` (13px) and `body-sm` (12px) for high-density administrative tabular data, log viewers, and diagnostic overlays.
- Numbers, timestamps, bitrate meters, and port addresses must utilize tabular figures (`font-feature-settings: 'tnum' on, 'zero' on`) for jitter-free real-time rendering.
- Section titles inside cards and utility panels strictly use `headline-sm` (16px) or `label-lg` (13px SemiBold) with high-contrast `#F1F5F9`.

## Layout & Spacing

The layout is built for dedicated desktop form factors adhering to standard Windows 10/11 multi-monitor environments.

### Structure & Anatomy
- **Integrated Window Titlebar (40px Height):** Contains the application identity, primary utility navigation items (`Consumo`, `Administração`, `Configurações`), and standard Windows caption controls (Minimize, Maximize, Close). Zero sidebar navigation; orientation is entirely top-down hierarchical.
- **Main Canvas:** Structured via fixed multi-pane splitters or responsive flex columns depending on the active module:
  - *Consumo:* Video viewport centered with sticky compact telemetry bar below or beside.
  - *Administração / Configurações:* Two-column master-detail or structured multi-card grid.
- **Desktop Density:** Base grid increments use an 8px base grid with a 4px half-step for precise control docking. Padding within input controls and table rows remains compact to maximize visual real estate without compromising mouse hit-boxes (minimum 32px touch/mouse targets for buttons).

## Elevation & Depth

To maintain zero latency visual response and crisp alignment with Windows modern styling, visual separation relies on tonal layering and crisp low-contrast borders rather than deep diffuse drop shadows.

- **Level 0 (Canvas Base):** Solid `#0B0F17`.
- **Level 1 (Panels & Shell):** Solid `#111722` bordered by 1px `#1E293B`.
- **Level 2 (Active Cards & Overlays):** Solid `#182030` bordered by 1px `#1E293B`.
- **Level 3 (Popups, Dropdown Menus, Tooltips):** Solid `#182030` bordered by 1px `#334155` with an ambient shadow: `0 8px 24px rgba(0, 0, 0, 0.45)`.
- **Focus States:** High-contrast 2px ring in primary cyan (`#00E5C9`) with 0px offset for immediate accessibility during tab-key traversal.

## Shapes

The design system adopts a **Soft (Level 1)** geometric standard optimized for modern Windows desktop software:
- **Buttons, Text Inputs, and Dropdown Menus:** `4px` border radius (`roundedness: 1`).
- **Cards, Panels, and Video Player Shells:** `6px` to `8px` (`rounded-lg`).
- **Pills / Status Badges:** `4px` slight rounding to maintain clean architectural lines rather than rounded organic curves.
- **Sliders & Progress Indicators:** `2px` track corner rounding for a technical precision instrument feel.

## Components

Standard Flutter Material 3 widget implementation guidelines for Windows:

### Top Navigation & Window Titlebar
- Implemented as a custom non-client window header (`PreferredSizeWidget`).
- Title tabs (`Consumo`, `Administração`, `Configurações`) are styled as flat `TextButton` widgets:
  - Default: Text color `#94A3B8`, background transparent.
  - Hover: Text color `#F1F5F9`, background `#182030`.
  - Active: Text color `#00E5C9` with a subtle bottom border accent (2px `#00E5C9`).

### FilledButton
- Used strictly for high-priority actions (e.g., "Iniciar Transmissão", "Conectar", "Aplicar Mudanças").
- Background: `#00E5C9`, Foreground: `#0B0F17` (Bold typography for ultra-contrast).
- Hover: `#00B4D8`.
- Disabled: Background `#222D42`, text `#475569`.

### OutlinedButton & TextButton
- **OutlinedButton:** 1px border `#334155`, text `#F1F5F9`, hover background `#182030`. Used for secondary commands like "Testar Latência" or "Exportar Logs".
- **TextButton:** Transparent fill, hover background `#182030`, foreground `#94A3B8`, hover foreground `#F1F5F9`.

### TextField
- Container background: `#182030`.
- Border: 1px outline `#1E293B`; focused border: 1.5px `#00E5C9`.
- Typography: `#F1F5F9` text, `#475569` placeholder text.
- Height: Compact 36px desktop field height with 8px horizontal content padding.

### DropdownMenu / DropdownButton
- Menu background: `#182030`, item text `#F1F5F9`.
- Hover state on menu item: `#222D42`.
- Border outline: 1px `#334155`.
- Selected item indicator: Cyan leading/trailing mark or highlighted text.

### Switch
- Track (Off): `#1E293B`, border `#334155`.
- Track (On): `#00E5C9`.
- Thumb: `#F1F5F9` (Off) / `#0B0F17` (On).
- Size: Compact desktop scale.

### LinearProgressIndicator
- Used for buffer load, bitrate health, and CPU/GPU usage metrics.
- Background track: `#182030`.
- Active fill: `#00E5C9` (Normal), `#F59E0B` (High Load / Degraded), `#EF4444` (Critical).
- Height: 4px for ambient cards, 6px for dedicated performance meters.

### Card
- Surface: `#111722` or `#182030`.
- Border: 1px `#1E293B`.
- Content padding: 16px desktop spacing (`space-lg`).
- Zero drop shadow; structure is maintained via boundary lines and tone.