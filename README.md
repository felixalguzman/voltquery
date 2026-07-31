# VoltQuery

Futuristic cross-platform **SQL database manager** — a DBeaver alternative, built with Flutter (desktop-first: Linux / macOS / Windows).

> **Status:** scaffold. Architecture and build are planned via `/wayfinder` before implementation.

## Planned stack (locked)
See [`docs/UI_STACK.md`](docs/UI_STACK.md) for the full brief and rationale.

- **UI base:** `fluent_ui` (dark + Acrylic → futuristic desktop). `shadcn_flutter` = reference only.
- **SQL editor:** `re_editor` + `re_highlight`
- **Result grid:** `pluto_grid`
- **Menu bar:** `base_menu` (needs Flutter ≥ 3.44.4 — bump before adding)
- **Futuristic layer:** `mix`
- **Charts / schema viz:** `graphic`
- **Feedback:** `toastification`, `skeletonizer`
- **Desktop:** `window_manager`, `hotkey_manager`

## Next step
Run `/wayfinder` to chart the effort into decision tickets (connection mgmt, schema model, editor↔grid wiring, theming tokens, DB drivers), resolve them, then hand off to a build pass.
