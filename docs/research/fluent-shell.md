# Research: fluent_ui shell coverage

**Resolves #5**
**Date:** 2026-07-31
**Branch:** research/fluent-shell

> **Question:** Can `fluent_ui` deliver the VoltQuery app shell without custom widgets?

---

## Coverage table

| Shell area | Widget | Covered? | Notes |
|---|---|---|---|
| Left-pane app nav | `NavigationView` + `NavigationPane` | ✅ Yes | `PaneDisplayMode.expanded` / `compact` / `top` / `minimal` / `auto` |
| Schema sidebar tree | `TreeView` + `TreeViewItem` | ✅ Yes | Lazy/async loading confirmed (see verdict below) |
| Query/table tabs | `TabView` | ✅ Yes | Closeable (`onClose`), reorderable (`onReorder`), keyboard shortcuts built in |
| Toolbar | `CommandBar` | ✅ Yes | Primary + overflow items, `dynamicOverflow` default, vertical axis supported |
| Translucent material | `Acrylic` | ✅ Yes | `BackdropFilter` blur; heavy — avoid on large surfaces |
| Opaque desktop material | `Mica` | ✅ Yes | Cheap; uses `FluentThemeData.micaBackgroundColor` (theme-color approximation, not live wallpaper sampling) |
| App-level theming (dark) | `FluentThemeData` | ✅ Yes | Dark mode + accent color integrated into both Acrylic and Mica |
| Google-Docs menu bar | `base_menu` (external) | ✅ Yes | Composable headless menu primitives; separate package |

**Overall verdict: fluent_ui covers all primary shell surfaces. No custom widgets required for the shell skeleton.**

---

## Widget-by-widget detail

### 1. NavigationView

Source: `lib/src/controls/navigation/navigation_view/view.dart` + `pane.dart`
([github.com/bdlukaa/fluent_ui](https://github.com/bdlukaa/fluent_ui/blob/master/lib/src/controls/navigation/navigation_view/view.dart))

`NavigationView` wraps the app's content area alongside a `NavigationPane`. Key constructor parameters:

- `titleBar`, `pane: NavigationPane`, `content`
- `paneBodyBuilder` — router integration
- `transitionBuilder`, `onOpenSearch`, `onDisplayModeChanged`

`NavigationPane.displayMode` accepts `PaneDisplayMode`:

| Mode | Behaviour |
|---|---|
| `expanded` | Full left pane with icons + labels |
| `compact` | Icons-only left pane (~50 px wide) |
| `top` | Horizontal pane above content |
| `minimal` | Hidden; hamburger button only |
| `auto` | Adaptive: expanded ≥1008 px, compact 641–1007 px, minimal ≤640 px |

`NavigationPane` also exposes `autoSuggestBox`, `indicator`, `toggleable`, `acrylicDisabled`.

---

### 2. TreeView — lazy/async loading verdict

Source: `lib/src/controls/navigation/tree_view.dart`
([github.com/bdlukaa/fluent_ui](https://github.com/bdlukaa/fluent_ui/blob/master/lib/src/controls/navigation/tree_view.dart))

**VERDICT: Lazy/async node loading IS supported natively.**

Mechanism:

| API | Purpose |
|---|---|
| `TreeViewItem(lazy: true)` | Marks node as expandable even with no children; shows chevron |
| `TreeViewItem(loading: bool)` | When `true`, renders a `ProgressRing` spinner in place of children |
| `TreeViewItem(loadingWidget: Widget?)` | Override the default spinner |
| `TreeViewItem(onExpandToggle: Future<void> Function(item, getsExpanded)?)` | **Async callback** fired on expand/collapse — fetch children here |
| `TreeView(onItemExpandToggle: ...)` | Global async expand callback (fires before item-level callback) |
| `TreeViewController` | Programmatic `addItem`, `removeItem`, `moveItem`, `expandItem`, `collapseItem` |

Pattern for a schema sidebar:
1. Seed the tree with top-level nodes (`lazy: true`).
2. On first expand, `onExpandToggle` fires → query DB for children → call `controller.addItem(...)` → set `item.loading = false`.

Selection modes: `none`, `single`, `multiple` (checkboxes).

---

### 3. TabView

Source: `lib/src/controls/navigation/tab_view/tab_view.dart`
([github.com/bdlukaa/fluent_ui](https://github.com/bdlukaa/fluent_ui/blob/master/lib/src/controls/navigation/tab_view/tab_view.dart))

| Feature | API |
|---|---|
| Close button | `Tab(onClose: VoidCallback?)` — null = not closeable; `closeButtonVisibility`: `always` / `never` / `onHover` |
| Reorder | `TabView(onReorder: ReorderCallback?)` — non-null enables drag-to-reorder |
| New tab button | `onNewPressed: VoidCallback?` — shows "+" button when set |
| Tab width | `tabWidthBehavior`: `equal` / `sizeToContent` / `compact` |
| Overflow | `showScrollButtons: bool` |
| Keyboard shortcuts | `shortcutsEnabled: bool` — Ctrl+T (new), Ctrl+W / F4 (close), Ctrl+1–9 (navigate) |
| Header/footer | `header` / `footer` widgets flanking the tab strip |

---

### 4. CommandBar

Source: `lib/src/controls/surfaces/commandbar.dart`
([github.com/bdlukaa/fluent_ui](https://github.com/bdlukaa/fluent_ui/blob/master/lib/src/controls/surfaces/commandbar.dart))

| Parameter | Purpose |
|---|---|
| `primaryItems: List<CommandBarItem>` | Always-visible toolbar items |
| `secondaryItems: List<CommandBarItem>` | Overflow items in flyout |
| `overflowBehavior: CommandBarOverflowBehavior` | `scrolling` / `noWrap` / `wrap` / `clip` / `dynamicOverflow` (default) |
| `direction: Axis` | Horizontal (default) or vertical |
| `isCompact` / `compactBreakpointWidth` | Compact vs full display |
| `overflowItemBuilder` | Customise the "⋯" button |

`CommandBarCard` wraps it in a styled card. `CommandBarButton` is the standard button item.

---

### 5. Acrylic / Mica theming

Sources:
- `lib/src/controls/surfaces/acrylic.dart` ([github.com/bdlukaa/fluent_ui](https://github.com/bdlukaa/fluent_ui/blob/master/lib/src/controls/surfaces/acrylic.dart))
- `lib/src/controls/surfaces/mica.dart` ([github.com/bdlukaa/fluent_ui](https://github.com/bdlukaa/fluent_ui/blob/master/lib/src/controls/surfaces/mica.dart))

**Acrylic** — translucent, `BackdropFilter` Gaussian blur:
- `tint: Color?`, `tintAlpha: double?` (default 0.8), `blurAmount: double?` (default 30)
- Performance-heavy; source recommends against using on large surfaces.

**Mica** — opaque, cheaper:
- Uses `FluentThemeData.micaBackgroundColor` (a static theme color, not live wallpaper sampling — Flutter platform constraint).
- `elevation`, `backgroundColor`, `borderRadius`, `shape: BoxShape`

Both integrate with `FluentTheme` for dark/light color resolution. For the futuristic dark look: use Mica on large panels (cheap), Acrylic on overlays / sidebars where the blur effect is worth the cost.

---

## base_menu SDK requirement

Source: `pubspec.yaml` at `github.com/davidhicks980/base_menu`
([raw.githubusercontent.com](https://raw.githubusercontent.com/davidhicks980/base_menu/main/pubspec.yaml))

```yaml
environment:
  sdk: ^3.11.4
  flutter: ">=3.44.4"
```

- **Minimum Flutter SDK: 3.44.4**
- Minimum Dart SDK: 3.11.4 (up to <4.0.0)
- Package version: 0.1.5 (publisher: davidhicks.dev, verified)

UI_STACK.md's note "≥ 3.44.4" is **confirmed correct**.

---

## Current stable Flutter version

Source: `docs.flutter.dev/release/archive`

**Flutter 3.44** (documentation baseline: 3.44.7) is the current stable release as of mid-2026.

| Version | Release target |
|---|---|
| 3.41 | February 2026 |
| **3.44** | **May 2026 — current stable** |
| 3.47 | August 2026 — not yet released |
| 3.50 | November 2026 — not yet released |

`base_menu`'s `flutter: ">=3.44.4"` requires a patch of 3.44 that is within the current stable channel. No version conflict.

---

## Gaps and weak points

| Area | Assessment |
|---|---|
| **Mica wallpaper sampling** | Mica does NOT sample the real desktop wallpaper in Flutter — it uses a theme-color approximation. The visual effect is subtler than native WinUI3 Mica. Acceptable for a cross-platform tool; note it if Windows-native fidelity matters. |
| **TreeView lazy loading UX** | Lazy loading is supported but the loading state (`item.loading`) must be managed manually — no built-in error/retry state. For a large schema with unreliable DB connections, add custom error handling around `onExpandToggle`. |
| **Acrylic on large surfaces** | Source code comment explicitly warns against using `Acrylic` on large surfaces due to `BackdropFilter` cost. Use `Mica` for panels; reserve `Acrylic` for small overlays. |
| **Menu bar** | `fluent_ui` does NOT include a Google-Docs-style menu bar (File/Edit/View). `base_menu` is required for this — already in the stack. Built-in Flutter fallback (`MenuBar` + `MenuAnchor`) is also viable if `base_menu` proves immature. |
| **Data grid** | Out of scope for this ticket — confirmed gap in `docs/UI_STACK.md`. |

---

## Summary

`fluent_ui` delivers every primary shell surface for VoltQuery without custom widgets:

- `NavigationView` → left-pane app nav (all display modes covered)
- `TreeView` → schema sidebar with **confirmed native lazy/async loading** via `lazy: true` + `onExpandToggle` async callback
- `TabView` → query/table tabs, closeable + reorderable, keyboard shortcuts built in
- `CommandBar` → toolbar with dynamic overflow
- `Acrylic` + `Mica` → futuristic dark theming (prefer Mica on large surfaces)

The only shell gap is the Google-Docs menu bar, which `base_menu` (already in the stack) covers. `base_menu` requires Flutter ≥ 3.44.4, which matches the current stable Flutter 3.44.
