# Flutter UI Packages — Desktop SQL Manager (DBeaver Alternative)

**Goal:** desktop-first Flutter app to manage a SQL database. Modern / futuristic look.
**Source:** filtered from your GitHub stars (felixalguzman, 4350 stars → 60 UI repos → desktop-relevant picks).
**Date:** 2026-07-31

---

## TL;DR — top picks for this app

| Pick | Repo | Why for a DB tool |
|------|------|-------------------|
| **App shell / theme (BASE)** | `bdlukaa/fluent_ui` | WinUI3 in Flutter. Complete desktop kit, native bones (toolbars, tree, tabs, panes). Dark + Acrylic/Mica reads genuinely futuristic. **Locked base.** |
| **Design reference only** | `sunarya-thito/shadcn_flutter` | NOT a dependency. Use as a *component-shape / spacing / dark-theme reference* when styling fluent widgets. Its web DNA (big radii, cards) is wrong for a desktop DB tool. |
| **SQL editor pane** | `reqable/re-editor` | Lightweight code/text editor **widget** with syntax highlighting. This is your query editor. Non-negotiable — hard to build well yourself. |
| **Menu bar** | `davidhicks980/base_menu` | Composable menu primitives — Google-Docs-style File/Edit/View bar. |
| **Alt native base** | `serverpod/stockholm` | Desktop-first widgets built for Serverpod Insights (a data inspector) — same use case. Thinner than fluent_ui; fallback if fluent feels too Windows-y. |
| **Result charts** | `entronad/graphic` | Grammar-of-graphics viz for showing query results. Pairs with grid. |

---

## By app region

### 1. App shell / navigation / theme

**Decision: base = `bdlukaa/fluent_ui`.** Rationale: a DBeaver-alt needs native desktop *bones* (density, real toolbars/panes, tree sidebar, tabs, keyboard-first), not web-dashboard decoration. fluent_ui delivers those + a dark/Acrylic theme that reads futuristic. shadcn_flutter was rejected as base — its DNA is web (big radii, card-heavy, loose spacing) and de-web'ing it fights the grain.

- **`bdlukaa/fluent_ui`** ⭐ starred — **LOCKED BASE.** WinUI3 in Flutter. `NavigationView`, `TreeView`, `TabView`, `CommandBar`, panes, Acrylic. Theme dark + accent for the futuristic look.
- `serverpod/stockholm` ⭐ starred — **fallback base.** Desktop-first, same use-case (built for a data inspector), but thinner. Switch to this only if fluent feels too Windows-branded.
- `sunarya-thito/shadcn_flutter` ⭐ starred — **REFERENCE ONLY, not a dep.** Mine it for component shapes, dark palette values, and spacing ideas when styling fluent widgets.
- Other options considered & not used: `macos_ui` (mac-only vibe), `forui`/`moon_flutter`/`tdesign-flutter` (web-ish or off-brand), `Arna`, `zenit_ui`.

**Skip** (retro, not futuristic): `miquelbeltran/flutter95`, `erickzanardo/nes_ui`.

### 2. SQL editor pane
- **`reqable/re-editor`** — code editor widget w/ highlighting. Your query editor. **Top need.**

### 3. Data grid / result table
> ⚠️ **Gap in your stars.** No strong data-grid package starred. A DB tool lives or dies on its result grid. Consider adding (not currently starred):
> - `bosskmk/pluto_grid` — the de-facto Flutter data grid (sort, filter, edit, freeze cols).
> - `syncfusion/flutter_datagrid` — heavier, commercial-ish.

### 4. Charts / data-viz (result visualization)
- `entronad/graphic` — grammar-of-graphics.
- `entronad/flutter_echarts` — Apache ECharts widget (very futuristic default look).
- `Nimblesite/nimble_charts`, `juliansteenbakker/community_charts`, `rudi-q/cristalyse` — alternatives.
- `nabil6391/graphview` — good for **schema / ER / relationship diagrams**.
- `alnitak/flutter_flow_chart` — flow/ER diagram authoring.

### 5. Styling / theming engine (build the futuristic custom look)
- **`conceptadev/mix`** — styling system. Use to define a consistent futuristic design language (tokens, variants).
- **`conceptadev/naked_ui`** — headless widgets. Behavior only, you style. Best if you want a truly custom futuristic UI, not off-the-shelf.
- `rydmike/flex_color_scheme` — theme + color scheme generator (dark neon palettes easy).
- `rydmike/flex_color_picker` — color picker (useful for a settings/theme panel).

### 6. Sheets / panels / layout
- `woltapp/wolt_modal_sheet` — multi-page modals (connection wizard, query params).
- `fujidaiti/smooth_sheets`, `jamesblasco/modal_bottom_sheet`, `mcrovero/rubber` — sheets.
- `woltapp/wolt_responsive_layout_grid`, `fluttercommunity/responsive_scaffold` — responsive layout.

### 7. Handy widgets
- `Milad-Akarie/skeletonizer` — skeleton loaders (query running state).
- `payam-zahedi/toastification` — toasts (query success/error).
- `chulwoo-park/timelines` — query history / migration timeline.
- `Sub6Resources/flutter_html` — render html (docs/help panes).
- `simc/auto_size_text` — fit text in tight cells/labels.

### Menu bar (Google-Docs-style File / Edit / View)
- **`davidhicks980/base_menu`** — **starred** ⭐ ([pub](https://pub.dev/packages/base_menu)) — "Composable widgets for building menu systems." Headless/accessible menu **primitives** (radix-style, for Flutter). Topics: `menubar, desktop, flutter, accessibility`. **This is the Google-Docs menu-bar util** — top pick for the app's File/Edit/View bar.
- Built-in fallback (no package): `MenuBar` + `MenuAnchor` + `SubmenuButton` from `material.dart`.
- Other pub options: `super_context_menu` (Superlist), `menu_bar`, `contextual_menu`.
- `leanflutter/hotkey_manager` — **starred** — system/in-app hotkeys, pairs with menu shortcuts.

### 8. Dev tooling (build UI in isolation)
- `widgetbook/widgetbook` — storybook for your components. Worth it for a component-heavy app.
- `bluefireteam/dashbook`, `Dropsource/monarch` — alternatives.

---

## Suggested stack for the DBeaver-alt

```
shell/theme  : fluent_ui        (LOCKED base — dark + Acrylic accent)
              ↳ shadcn_flutter   (REFERENCE ONLY, do NOT add as dep)
              ↳ stockholm        (fallback base if fluent too Windows-y)
styling      : mix + naked_ui   (custom futuristic layer on top of fluent)
menu bar     : base_menu        (File/Edit/View, Google-Docs style)
sql editor   : re-editor
data grid    : pluto_grid       ⭐ starred
charts       : flutter_echarts  (futuristic default) or graphic
schema view  : graphview
panels       : fluent_ui ContentDialog / wolt_modal_sheet
feedback     : toastification + skeletonizer
component dev : widgetbook
```

## Build brief (for /wayfinder auto-build)
Locked decisions so the agent doesn't re-litigate:
1. **Base kit = `fluent_ui`.** Add to pubspec. Wrap app in `FluentApp`, dark theme, accent color set.
2. **shadcn_flutter is reference-only** — never add as a dependency.
3. **Shell layout:** `NavigationView` (left pane = connection/schema `TreeView`) + `TabView` (each tab = a query/table) + top `CommandBar` and a `base_menu` menu bar (File/Edit/View/Query).
4. **Query editor tab:** `re-editor` pane (top) + `pluto_grid` results (bottom), splitter between.
5. **Futuristic layer:** define design tokens with `mix` (dark bg, neon accent, subtle glass); use `naked_ui` for any custom widget fluent lacks.
6. **Feedback:** `toastification` for query ok/err, `skeletonizer` while running.
7. Target desktop first (Windows/macOS/Linux). Keyboard-first (`hotkey_manager`).

## Gaps worth starring (not in your stars, but core to a DB tool)
- ~~`bosskmk/pluto_grid` — data grid~~ ✅ **starred**.
- `fluttercommunity/flutter_fancy_tree_view` or similar — for the schema/table tree sidebar (fluent_ui's `TreeView` may cover this).
- A SQL syntax highlighter for `re-editor` (or wire `highlight` / `flutter_highlight`).

---

*Full unfiltered UI-package list from your stars available on request.*
