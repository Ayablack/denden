---
name: DenDen Stream Studio
colors:
  surface: '#0f131c'
  surface-dim: '#0f131c'
  surface-bright: '#353942'
  surface-container-lowest: '#0a0e16'
  surface-container-low: '#181c24'
  surface-container: '#1c2028'
  surface-container-high: '#262a33'
  surface-container-highest: '#31353e'
  on-surface: '#dfe2ee'
  on-surface-variant: '#b9cac5'
  inverse-surface: '#dfe2ee'
  inverse-on-surface: '#2c3039'
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
  tertiary: '#ffe3c5'
  on-tertiary: '#462a00'
  tertiary-container: '#ffc06e'
  on-tertiary-container: '#794c00'
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
  tertiary-fixed: '#ffddb6'
  tertiary-fixed-dim: '#ffb95a'
  on-tertiary-fixed: '#2a1800'
  on-tertiary-fixed-variant: '#643f00'
  background: '#0f131c'
  on-background: '#dfe2ee'
  surface-variant: '#31353e'
typography:
  headline-xl:
    fontFamily: Space Grotesk
    fontSize: 2rem
    fontWeight: '700'
    lineHeight: 2.5rem
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Space Grotesk
    fontSize: 1.5rem
    fontWeight: '600'
    lineHeight: 2rem
    letterSpacing: -0.015em
  headline-md:
    fontFamily: Space Grotesk
    fontSize: 1.25rem
    fontWeight: '600'
    lineHeight: 1.75rem
    letterSpacing: -0.01em
  body-lg:
    fontFamily: Manrope
    fontSize: 1rem
    fontWeight: '400'
    lineHeight: 1.5rem
    letterSpacing: 0em
  body-md:
    fontFamily: Manrope
    fontSize: 0.875rem
    fontWeight: '400'
    lineHeight: 1.25rem
    letterSpacing: 0.005em
  body-sm:
    fontFamily: Manrope
    fontSize: 0.75rem
    fontWeight: '500'
    lineHeight: 1rem
    letterSpacing: 0.01em
  label-code:
    fontFamily: JetBrains Mono
    fontSize: 0.8125rem
    fontWeight: '500'
    lineHeight: 1rem
    letterSpacing: -0.01em
  label-telemetry:
    fontFamily: JetBrains Mono
    fontSize: 0.6875rem
    fontWeight: '600'
    lineHeight: 0.875rem
    letterSpacing: 0.04em
  label-action:
    fontFamily: Manrope
    fontSize: 0.8125rem
    fontWeight: '600'
    lineHeight: 1rem
    letterSpacing: 0.02em
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
spacing:
  gutter: 1rem
  gutter-compact: 0.5rem
  margin: 1.5rem
  margin-window: 0.75rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 0.75rem
  space-lg: 1rem
  space-xl: 1.5rem
  space-2xl: 2rem
---

## Brand & Style
This design system establishes a high-performance desktop streaming and screen-sharing environment tailored for Windows desktop frameworks (Fluent/Flutter). The aesthetic synthesizes oceanic abyss depths with bio-luminescent technical precision—merging the subtle spiral geometry of nautical communication motifs (inspired by transmission shells) with ultra-crisp workstation utility.

- **Atmosphere:** Deep oceanic dark mode, low visual fatigue during prolonged streaming sessions, high focal-contrast overlays.
- **Personality:** Authoritative, high-fidelity, fluid, and whisper-quiet in operation.
- **Visual Stance:** Precision dark minimalism integrated with translucent acrylic glass layers and vibrant bio-cyan energy points.
- **Language & Tone:** Portuguese (Brazil) localization with technical rigor and succinct operational clarity (e.g., "Transmissão Ativa", "Dispositivos de Entrada", "Taxa de Quadros").

## Colors
The color hierarchy is engineered to prioritize content capture and streaming telemetry without chromatic distraction.

- **Obsidian Ocean Surfaces:**
  - `canvas-abyss`: `#0B0F17` (Deepest window backplane and inactive margins)
  - `surface-depth`: `#111726` (Sidebar navigation, dock trays, toolbar containers)
  - `surface-elevated`: `#1A2234` (Inspector panels, modal dialogs, flyout sheets)
  - `stroke-subtle`: `#243048` (Low-contrast structural dividing lines, window borders)

- **Luminescent Accents:**
  - `primary`: `#00E5C9` (Bio-cyan for active capture indicators, toggle switches, primary interaction states)
  - `secondary`: `#00B4D8` (Turquoise glow for audio meter peaks, secondary streaming metrics, focus rings)
  - `tertiary`: `#FFB347` (Warm coral gold for stream key management, alerts, bit-rate drops, and latency notices)
  - `critical`: `#FF6B6B` (Coral crimson for recording live indicators, mute states, and emergency cut-offs)

- **Legibility Neutrals:**
  - `text-primary`: `#F1F5F9` (High-contrast pure clarity for metric readouts and stream statuses)
  - `text-secondary`: `#94A3B8` (Muted labels, metadata, inactive icons)
  - `text-disabled`: `#475569` (Unavailable audio/video devices and locked options)

## Typography
Typography is separated into structural roles:
- **Space Grotesk** commands section headers, toolstrip category titles, and streaming modality switches. Its technical, geometric curvature subtly reflects organic mechanical shells.
- **Manrope** drives all conversational interface copy, preferences, contextual menus, and configuration labels with balanced, humanist clarity in Portuguese.
- **JetBrains Mono** governs the streaming telemetry (e.g., `60 FPS`, `12.4 Mbps`, `48 kHz`, `0.02% perda`), source coordinates, timecodes, and device IDs to guarantee tabular numeric stability without layout jitter.

## Layout & Spacing
The layout follows a multi-pane desktop workstation architecture designed for high-resolution displays (1080p, 1440p, 4K) running on Windows.

- **Layout Hierarchy:**
  - **Titlebar & Command Strip:** Fixed 40px height with seamless integration into native Windows controls.
  - **Left Navigation Rail / Snail Deck:** 64px collapsed, expands to 240px for scene management and output sources.
  - **Stage / Viewport Canvas:** Flexible center canvas anchoring the live stream or screen mirror with 1:1 aspect ratio constraint containers.
  - **Inspector & Audio Dock:** 320px right dock with 8px column-gap subgrids for gain faders and encoder configuration.
- **Breakpoints:**
  - Compact Desktop (<1024px): Collapses telemetry docks into floating overlay drawers; collapses labels to icon-only navigation.
  - Standard Desktop (1024px - 1440px): Full 3-column split view with 16px outer margins.
  - Ultrawide Desktop (>1440px): Centralized viewport with side-by-side multitrack audio inspection and preview-program dual monitors.

## Elevation & Depth
Depth is produced through subtle oceanic surface layering and low-contrast borders instead of heavy, opaque drop shadows:

- **Layer 0 (Window Canvas):** Solid `#0B0F17`.
- **Layer 1 (Recessed Well):** Inset surfaces (`#080C13`) used for inactive screen capture slots and audio channel tracks, bounded by `#1A2234`.
- **Layer 2 (Standard Panels):** Acrylic-like translucency with `#111726` at 85% opacity paired with a background blur (`backdrop-filter: blur(16px)`) and a 1px border of `#243048`.
- **Layer 3 (Modals & Overlays):** `#1A2234` floating panels with a multi-layered bio-shadow: `0 8px 32px -4px rgba(0, 0, 0, 0.65)`, complemented by a delicate, diffuse aura: `0 0 20px -2px rgba(0, 229, 201, 0.08)`.
- **Active Transmission Glow:** Real-time active output borders leverage an internal cyan trace line: `0 0 0 1px #00E5C9, 0 0 12px rgba(0, 229, 201, 0.35)`.

## Shapes
A disciplined "Soft" curvature (Level 1) maintains the rigor of professional Windows desktop software without harsh industrial points:

- **Controls & Micro-surfaces:** 4px (`0.25rem`) border radius for buttons, input text boxes, audio fader handles, and badges.
- **Containers & Tiles:** 8px (`0.5rem`) for capture thumbnails, device selector tiles, and modal dialogs.
- **Floating Overlays & Chips:** 12px (`0.75rem`) for floating status pills and picture-in-picture stream cards.
- **Motif Inlays:** Circular and logarithmic spiral contours (based on the Nautilus curve) are applied solely to transmission waveform graphs, volume dials, and system glyphs.

## Components

### Botões (Buttons)
- **Primário (Transmissão Ativa / Iniciar):** Background `#00E5C9`, text `#0B0F17`, font `Manrope` Semibold 13px. Hover brings `#33EBCE` with a subtle bio-glow.
- **Secundário (Configuração de Dispositivo):** Background `#1A2234`, border 1px solid `#243048`, text `#F1F5F9`. Hover transitions border to `#00B4D8`.
- **Perigo / Encerrar (Parar Transmissão):** Background `#FF6B6B` at 15% opacity, border 1px solid `#FF6B6B`, text `#FF6B6B`. Hover shifts to solid `#FF6B6B` with white text.

### Seletor de Telas & Chips de Janela (Screen & Window Chips)
- Interactive card surfaces (`#111726`) displaying real-time desktop window previews.
- Top indicator tag displaying window titles in `Manrope` 12px, bottom badge in `JetBrains Mono` displaying resolution (ex: `1920x1080 @ 60Hz`).
- Selected capture surface highlights with a 2px `#00E5C9` frame.

### Medidores de Áudio & Controles Deslizantes (Audio Meters & Sliders)
- High-frequency decibel VU meter with 2px vertical segments:
  - `-inf to -12 dB`: Bio-cyan `#00E5C9`
  - `-12 to -3 dB`: Secondary turquoise `#00B4D8`
  - `-3 to 0 dB`: Golden coral `#FFB347`
  - `Clipping / Picos (>0 dB)`: Coral crimson `#FF6B6B`
- Smooth drag knobs with 4px pill profiles and high-precision click-to-type numeric inputs.

### Campos de Entrada (Input Fields & Keys)
- Obfuscated stream-key fields with background `#0E1420`, border 1px solid `#243048`, text `JetBrains Mono` 13px.
- Focus state reveals a razor-sharp 1px border of `#00E5C9` and faint 3px outer halo in `rgba(0, 229, 201, 0.15)`.
- Trailing copy icon with instant feedback badge ("Chave Copiada!").

### Caixas de Seleção & Alternadores (Switches & Checkboxes)
- Fluent-compatible toggle switches with 40x20px capsule track. Inactive state: `#1A2234` track, `#94A3B8` thumb. Active state: `#00E5C9` track, `#0B0F17` thumb.
- Checkboxes: 16x16px with 3px radius, checking with an instant bio-cyan fill and obsidian tick.

### Cartões de Estatística & Telemetria (Telemetry Cards)
- Floating micro-HUD panels displaying network packet metrics, encoder load, bit-rate, and dropped frames.
- Background `#111726` with 80% opacity, rounded-sm (4px), stacked numeric readout (`Space Grotesk` 18px text-primary over `JetBrains Mono` 11px text-secondary).