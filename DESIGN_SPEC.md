# Serene Sky Sanctuary Design System Specification

## 1. Architectural Philosophy & Vision
Serene Sky Sanctuary unites celestial visual tranquility with high-integrity productivity mechanics. The visual language evokes high-altitude dawn, tropospheric gradients, frosted glassmorphic containers, and tactile 2.5D stepping-stone geography.

---
name: Serene Sky Sanctuary
colors:
  # Serene Sky Default (Celestial Troposphere)
  cerulean-blue: '#3888E6'
  airy-sky: '#5CA3F5'
  soft-horizon-blue: '#7CB8FA'
  cloud-white: '#FFFFFF'
  ice-blue-shadow: '#D0E4FF'
  soft-sky-secondary: '#D6E8FF'
  warm-amber: '#FFB547'
  soft-mint-glow: '#6EE7B7'
  deadline-alert-coral: '#FF6B6B'
  navy-text: '#1E293B'
  # Midnight Sky (Dark Mode)
  midnight-top: '#0F172A'
  midnight-bottom: '#1E293B'
  # Pure Black OLED Mode
  oled-black: '#000000'
  oled-surface: '#0B0F17'
  oled-border: '#1E293B'
typography:
  timer-display:
    fontFamily: sans-serif
    fontSize: 72px
    fontWeight: '700'
    lineHeight: '1.0'
    fontFeatures: 'tabular-figures'
  centiseconds-display:
    fontFamily: sans-serif
    fontSize: 32px
    fontWeight: '600'
  headline-lg:
    fontFamily: sans-serif
    fontSize: 22px
    fontWeight: '700'
    letterSpacing: -0.02em
  headline-md:
    fontFamily: sans-serif
    fontSize: 18px
    fontWeight: '600'
  body-md:
    fontFamily: sans-serif
    fontSize: 14px
    fontWeight: '400'
  label-sm:
    fontFamily: sans-serif
    fontSize: 11px
    fontWeight: '600'
    letterSpacing: 0.04em
rounded:
  sm: 8px
  md: 16px
  card: 24px
  pill: 9999px
spacing:
  margin: 16px
  gutter: 12px
  hero-carousel-height: 132px
  dock-height: 56px
---

## 2. Tri-Palette Engine

| Token | Serene Sky Default | Midnight Sky Dark | Pure Black OLED |
|---|---|---|---|
| **Background** | LinearGradient(`0xFF3888E6` -> `0xFF5CA3F5` -> `0xFF7CB8FA`) | LinearGradient(`0xFF0F172A` -> `0xFF1E293B`) | Solid `Color(0xFF000000)` |
| **Glass Surface** | `Color(0xFFFFFFFF)` @ 0.18 opacity | `Color(0xFFFFFFFF)` @ 0.10 opacity | Solid `Color(0xFF0B0F17)` |
| **Glass Border** | 1px `Color(0xFFFFFFFF)` @ 0.32 opacity | 1px `Color(0xFFFFFFFF)` @ 0.18 opacity | 1px `Color(0xFF1E293B)` |
| **Primary Text** | Cloud White `Color(0xFFFFFFFF)` | Cloud White `Color(0xFFFFFFFF)` | Cloud White `Color(0xFFFFFFFF)` |
| **Secondary Text** | Soft Sky `Color(0xFFD6E8FF)` | Slate Gray `Color(0xFF94A3B8)` | Slate Gray `Color(0xFF94A3B8)` |
| **Warm Amber Accent** | `Color(0xFFFFB547)` | `Color(0xFFFFB547)` | `Color(0xFFFFB547)` |
| **Soft Mint Glow** | `Color(0xFF6EE7B7)` | `Color(0xFF6EE7B7)` | `Color(0xFF6EE7B7)` |
| **Deadline Alert Coral**| `Color(0xFFFF6B6B)` | `Color(0xFFFF6B6B)` | `Color(0xFFFF6B6B)` |
| **Primary Dock Button** | Pure White with Navy `0xFF1E293B` Text | Pure White with Navy `0xFF0F172A` Text | Pure White with Navy `0xFF000000` Text |

---

## 3. Screen Blueprint & Structural Guidelines

### A. Navigation Shell (`lib/screens/app_shell.dart`)
- **Strictly Three Tabs**:
  1. **Home**: `Icons.home_rounded`
  2. **Plan**: `Icons.layers_rounded`
  3. **Stats**: `Icons.bar_chart_rounded`
- No Practice tab.
- Translucent frosted glass bottom dock anchored over safe area with active tab indicator dot.

### B. Tab 1: Home Screen (`lib/screens/home_screen.dart`)
- **Top Header**:
  - Left: Frosted Settings `IconButton` (`Icons.tune_rounded`). No profile avatar, no mode pill.
  - Right: Two frosted counter pills:
    - **Streak**: Amber flame icon (`Color(0xFFFFB547)`) + current consecutive active streak days.
    - **Tokens**: Four-point star icon (`Color(0xFFFFB547)`) + total wallet token balance.
- **Peek-Edge Hero Carousel (132px height)**:
  - `PageView.builder` with `viewportFraction: 0.82`, `itemCount: 10000`, `initialIndex: 4000`.
  - Circular card mapping: `index % 4`.
  - Matrix4 scale interpolation: center card scale `1.0`, peeking neighbor cards approximately `0.88` scale.
  - Cards:
    1. **Next Planned Topic**: title, preferred window, estimated token reward.
    2. **Best Session**: longest session duration & highest tokens earned.
    3. **Top Focus Topic**: topic/goal with highest cumulative focus time.
    4. **Flow Readiness**: calculated percentage likelihood of entering Flow State.
- **2.5D Stepping-Stone Progression Geography**:
  - Completely removes old 7-day circle strip.
  - Empty State: Calm, visually balanced message inviting the user to plan a session.
  - Planned Sessions: Rendered vertically as 2.5D white cylindrical pedestals. Newly planned sessions stack **ABOVE** existing ones (ascending order).
  - Interactive: Tapping opens a frosted **Session Detail Dialog** displaying Duration, Topic/Goal, Preferred Window, and Calculated Token Reward with multiplier rules explained.
- **Docked Primary Action**:
  - Full-width Cloud White pill button (56px height, navy text).
  - Empty: "Plan a Session".
  - Planned: "Start • [Next Session Topic]".

### C. Active Focus Screen (`lib/screens/active_focus_screen.dart`)
- Clean, distraction-free sky canvas with decorative animations stripped out.
- Centered frosted **Timer Capsule**:
  - Tabular white digits at `fontSize: 72`, `FontWeight.w700`.
  - Optional `.00` centiseconds at `fontSize: 32` in `Color(0xFFD6E8FF)` when Precision setting is enabled.
  - Topic pill above timer; live reward multiplier pill below timer (e.g. `1.25x Window Bonus`, `1.5x Flow Zone`).
- Bottom CTA: Full-width Cloud White pill button: **"Finish • +[X] Tokens"**, updating dynamically from actual elapsed monotonic time.

### D. Tab 2: Plan Screen (`lib/screens/plan_screen.dart`)
- Top segmented glass toggle: **[Sessions]** vs **[Goals]**.
- **Approaching Deadline Section**:
  - Identifies sessions/goals whose deadline or preferred window is today, overdue, or within 24 hours.
  - Bordered with Deadline Alert Coral `Color(0xFFFF6B6B)`.
  - Hidden completely when no matching items exist.
  - Avoids duplication between highlighted and normal lists.
- Bottom Docked Dual Buttons:
  - Row of two equal-width 52px pill buttons with 12px gap:
    - **"+ Plan Session"**: Duration, preferred window picker, topic/goal dropdown or text.
    - **"+ New Goal"**: Title and optional deadline date picker.

### E. Tab 3: Stats Screen (`lib/screens/stats_screen.dart`)
- Multi-week GitHub-style **Consistency Heatmap Grid** with shaded rounded squares.
- Three summary cards: **Active Streak**, **Total Tokens**, **Total Focus Hours**.
- Chronological **Session History list** displaying actual completed sessions.
- Dynamic streak calculation from local calendar dates.

### F. Settings Sheet (`lib/screens/settings_sheet.dart`)
- Frosted glass interface.
- Precision toggle (`.00` centiseconds).
- Three-option theme selector (Serene Sky / Midnight Sky / Pure Black).
- File-based JSON Backup and Restore with schema verification (`serene_sky_backup_v2`), atomic restore, and dynamic streak recalculation.

---

## 4. Systems Architecture: Flow Engine & Token Calculator

### Hidden Flow State Engine
- Identifies personal **Flow Entry Threshold** ($T_{flow}$) after $\ge 5$ completed sessions.
- Evaluates early drop-off survival inflection to establish the minutes where drop-offs subside (default 15m).
- Computes **Flow Readiness %** based on recent session regularity, completion rates, and historical cadence.

### Token Calculator
- Base reward: **1 token / focus minute**.
- Flow Zone: **1.5x multiplier** for eligible minutes beyond $T_{flow}$ (active with $\ge 5$ sessions).
- Preferred Time Window:
  - **1.25x**: Started INSIDE preferred window.
  - **1.0x**: Started BEFORE preferred window.
  - **0.75x**: Started AFTER preferred window.
- Formula: $\text{Tokens} = \lfloor ((M_{\text{regular}} \times 1.0) + (M_{\text{flow}} \times 1.5)) \times W_{\text{window}} \rfloor$.
