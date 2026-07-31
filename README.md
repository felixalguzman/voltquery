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

## Building

### Linux prerequisites
`hotkey_manager` (locked stack) needs **keybinder-3.0** at build time, or the Linux build fails with `The hotkey_manager package requires keybinder-3.0`:

- Arch: `sudo pacman -S libkeybinder3`
- Debian/Ubuntu: `sudo apt install libkeybinder-3.0-dev`
- Fedora: `sudo dnf install keybinder3-devel`

`linux/CMakeLists.txt` compiles with `-Wall` but **not** `-Werror`: `hotkey_manager_linux` emits uninitialized-variable warnings that would otherwise fail the whole build under clang.

## Next step
Run `/wayfinder` to chart the effort into decision tickets (connection mgmt, schema model, editor↔grid wiring, theming tokens, DB drivers), resolve them, then hand off to a build pass.
