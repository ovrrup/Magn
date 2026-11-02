# Precision Field Instrument Design System (PFI-01)
*Inspired by Teenage Engineering TP-7, Braun (Dieter Rams), and Swiss Technical Interfaces.*

---
name: Precision Field Instrument
colors:
  surface: '#E6E5E0'
  surface-dim: '#DAD8D0'
  surface-bright: '#F4F3EF'
  surface-container: '#F4F3EF'
  surface-container-high: '#F4F3EF'
  surface-container-highest: '#DAD8D0'
  on-surface: '#141413'
  on-surface-variant: '#787670'
  outline: '#C8C6BE'
  outline-variant: '#C8C6BE'
  primary: '#FF451A'
  on-primary: '#FFFFFF'
  primary-container: '#FF451A'
  on-primary-container: '#FFFFFF'
  secondary: '#141413'
  on-secondary: '#F4F3EF'
  background: '#E6E5E0'
  on-background: '#141413'
typography:
  display-lg:
    fontFamily: monospace
    fontSize: 32px
    fontWeight: '700'
    lineHeight: '1.1'
    letterSpacing: -0.02em
  headline-md:
    fontFamily: monospace
    fontSize: 16px
    fontWeight: '700'
    lineHeight: '1.2'
    letterSpacing: 0.08em
  body-md:
    fontFamily: sans-serif
    fontSize: 14px
    fontWeight: '500'
    lineHeight: '1.4'
    letterSpacing: 0.0em
  label-sm:
    fontFamily: monospace
    fontSize: 10px
    fontWeight: '700'
    lineHeight: '1.2'
    letterSpacing: 0.12em
rounded:
  sm: 4px
  DEFAULT: 8px
  md: 10px
  lg: 16px
  full: 9999px
spacing:
  margin: 16px
  gutter: 12px
  header-h: 56px
  telemetry-h: 38px
  dock-h: 76px
  platter-max: 290px
---

## 1. Architectural Philosophy
The Precision Field Instrument (PFI-01) design system bridges tactile industrial equipment and ultra-focused software flow. It rejects blurry dropshadows, gradient skeuomorphism, and bloated micro-animations in favor of:
- **Mechanical Precision**: Rigid 1px hairline borders (`#C8C6BE` / `#2B2E36` / `#22242A`), strict physical cells, and tactile feedback.
- **High-Information Density & Tabular Typography**: Monospace numbers and uppercase metadata micro-labels with wide tracking (`0.12em`).
- **Tactile Centerpiece**: A mathematical mechanical tape platter with 60 radial warm-up/flow ticks, concentric aluminum grooves, and rotating index line.

## 2. Shared Solid Tri-Theme Palette
Zero gradients are used across all modes. All surfaces are flat, solid, high-contrast coats:

| Token | Anodized Stone (Light - Default) | Obsidian Field Recorder (Dark) | Pure Black OLED |
|---|---|---|---|
| `background` | `#E6E5E0` (Warm Anodized Stone) | `#0E0F12` (Field Matte Noir) | `#000000` (Pure Black OLED) |
| `cardSurface` | `#F4F3EF` (Light Sand Plate) | `#17181C` (Matte Carbon Slate) | `#0B0B0D` (Deep Monolith) |
| `recessedSurface` | `#DAD8D0` (Milled Recess) | `#1F2127` (Milled Recess Dark) | `#141519` (Milled Recess OLED) |
| `inkPrimary` | `#141413` (High Carbon Ink) | `#F4F3EF` (Chalk White Ink) | `#F4F3EF` (Chalk White Ink) |
| `inkSecondary` | `#787670` (Muted Zinc) | `#858890` (Field Slate) | `#787A82` (Neutral Wire) |
| `hairlineBorder` | `#C8C6BE` (Hairline Stone) | `#2B2E36` (Hairline Graphite) | `#22242A` (Hairline Dark) |
| `signalOrange` | `#FF451A` (International Orange) | `#FF451A` (International Orange) | `#FF451A` (International Orange) |

## 3. Screen Layout Blueprints

### A. Main Workspace (`WorkspaceScreen`)
Strict non-overlapping vertical column inside `SafeArea`:
1. **Instrument Header (56px)**:
   - Left: Monospace mode label (`ENDLESS` or `CYCLE 1/4`) and telemetry date (`SUN 01.11 // IGNITION 10M`).
   - Right: Two-segment pill toggle (`ENDLESS` vs `CYCLE`).
   - Border: 1px bottom `hairlineBorder`.
2. **Mechanical Platter (Expanded, max 290px)**:
   - Outer Ring: 60 radial ticks (10px length, 1.5px width, 6° intervals). Light up progressively in `signalOrange` during Warm-Up, all pulse subtly in Flow.
   - Body: `cardSurface` disk with 1.5px rim and 3 concentric rings (75%, 55%, 35% radius).
   - Rotation: 10-second continuous loop while active, rotating radial index line at 45° with 4px `signalOrange` tip dot.
   - Spindle Hub: 68px center circle. Tapping toggles `showDigits` between a 10px mechanical spindle hole and tabular readout (`24:15.82`).
3. **Telemetry & Distraction-Mark Strip (38px, 8px radius)**:
   - Recessed pill filled with `inkPrimary`, contrast text in `cardSurface`.
   - Live state badge (`IDLE`, `WARM-UP`, `✦ FLOW STATE`), flow delta (`FLOW +00:00`), and interactive `+ MARK` impulse capture button.
4. **Active Intention Selector Bar (52px, 10px radius)**:
   - `cardSurface` with 1px `hairlineBorder`.
   - `INTENTION` micro-label and active task title with chevron linking to Tasks Sheet.
5. **Bottom Hardware Dock (76px)**:
   - Divided into 3 equal cells by 1px vertical hairline borders.
   - Left Cell: `TASKS` (or `SKIP` when running cycle).
   - Center Cell: Tactile hardware switch (28px `signalOrange` circle when stopped, `inkPrimary` square when running).
   - Right Cell: `INSIGHTS` (with instant access to System Settings).

### B. Insights & Analytics Sheet (`InsightsSheet`)
- Top pill segmented control (`DAY | WEEK | ALL`).
- 3 Metric Cards: Personal Ignition Time ($T_{flow}$ calculated via 85th percentile early-bailout survival threshold), Total Flow Duration, and Flow Efficiency %.
- Stepped Cognitive Depth Timeline Chart (CustomPainter rendering stepped blocks across Idle, Warm-Up, Focused, and Deep Flow).
- 7-Day Rounded Pill Bar Chart with horizontal dashed average target line.
- 28-Day Consistency Matrix (7x4 circles).
- Milestone Badges (Longest Flow Streak, Deepest Session).
- Scrollable Session History Log.

### C. Tasks Triage Sheet (`TasksSheet`)
- Quick-Add field with immediate keyboard action.
- Three Zero-Guilt Buckets: `TODAY`, `DEFERRED / NOT TODAY`, and `CAPTURED MARKS`.
- Cards with flow minutes accumulation, 1-tap intention radio selector, completion checkbox, and defer button.

### D. System Settings Sheet (`SettingsSheet`)
- Behavior options: Show Digits on Platter, Show Centiseconds, Ignition Threshold, Cycle durations.
- Appearance: Anodized Stone (Light), Obsidian Field Recorder (Dark), Pure Black OLED.
- File-Based Data Management: Validated JSON Export and Import via file_picker and share_plus, with schema verification and Merge vs Overwrite options.
