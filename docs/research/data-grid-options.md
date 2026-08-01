# Research: result-grid options — is `pluto_grid` still the right call?

**Date:** 2026-08-01
**Context:** VoltQuery's result grid is `pluto_grid ^8.1.0`, wired in `lib/ui/features/query_workspace/result_grid.dart` (715 lines: staged edits, NULL rendering, boolean toggles, type-aware editors). Prior research: [`editor-grid.md`](editor-grid.md).
**Question:** keep pluto, switch package, or build our own on Flutter's 2D scrollables?

---

## 0. Star check (asked first)

Filtered all 4355 starred repos (`gh api user/starred`) for grid/table/sheet keywords. Result:

- **`bosskmk/pluto_grid`** (745★, last push 2025-12-14) — the only Flutter data-grid starred.
- Everything else that matched is a *competitor product*, not a library: `TableProApp/TablePro` (5.4k★), `TablePlus/TablePlus`, `mathesar-foundation/mathesar` (5.1k★), `gristlabs/grist-core` (11.4k★), `maaslalani/sheets`, `bgreenwell/xleak`.

**Stars add no new candidate.** The 2026-07-31 stack note (`~/flutter-db-ui-stars.md`) already flagged the grid as the one gap filled by a single package.

---

## 1. The requirement, stated properly

A SQL client's grid is not a dashboard table. What it must do:

| # | Requirement | Why it bites |
|---|---|---|
| R1 | **Row virtualization** | `SELECT *` on 1M rows. Table stakes; everything below does this. |
| R2 | **Column virtualization** | `SELECT *` on a 150–300 column table. Most Flutter grids build *every* column for *every* visible row. |
| R3 | **Arbitrary cell widgets** | NULL badge, boolean toggle, JSON/BLOB preview chip, truncated long text. Text-only painters can't. |
| R4 | **Cell editing + staged buffer** | Already built (`grid_edit_buffer.dart`); the grid must not own the write path. |
| R5 | **Excel-range selection + TSV copy** | Non-negotiable for a DBeaver alternative. |
| R6 | **Keyboard-first navigation** | Same. |
| R7 | **Frozen columns** | PK columns pinned left while scrolling wide results. |
| R8 | **No Material coupling** | Shell is `fluent_ui`. `result_grid.dart:204` already wraps pluto in a `Material` ancestor as a workaround. |
| R9 | **Maintained + patchable** | Flutter breaks packages every ~2 releases. Need MIT/BSD source we can fork. |

---

## 2. Candidates — verified numbers (2026-08-01)

| Package | Version / published | Likes | Weekly dl | Repo ★ / last commit | License |
|---|---|---|---|---|---|
| `pluto_grid` | 8.1.0 · 7 mo ago | 1.08k | 32.1k | 745 · 2025-12-14 | MIT |
| `trina_grid` | 2.3.0 · 9 days ago | 139 | 20.9k | 161 · 2026-07-22 | MIT |
| `syncfusion_flutter_datagrid` | 34.1.33 · 4 days ago | 871 | 79.2k | active | **commercial** |
| `two_dimensional_scrollables` | 0.5.3 · 31 days ago | 488 | 194k | flutter/packages · active (19 commits/6 mo) | BSD-3 |
| `material_table_view` | 5.5.2 · 11 mo ago | 254 | 10.9k | 65 · 2026-01-25 | MIT |
| `ultimate_grid` | 0.2.0 · 39 days ago | 4 | 25 | 3 · 2026-06-23 | MIT |
| `flutter_data_grid` | 0.0.23 · 35 days ago | 3 | 128 | unverified uploader | MIT |
| `om_data_grid` | 0.0.23 · 4 mo ago | 4 | 76 | low | MIT |
| `data_table_2` | — | ~600 | high | 255 · 2025-11-28 | MIT |
| `davi` | 4.0.1 · 18 mo ago | 75 | 1.5k | 73 · 2025-01-22 | MIT |
| `table_view_ex` | 0.1.6 · 11 mo ago | 3 | 24 | low | MIT |

### Capability matrix

| | R1 rows | R2 cols | R3 widget cells | R4 edit | R5 range+copy | R6 kbd | R7 freeze | R8 no-Material |
|---|---|---|---|---|---|---|---|---|
| pluto_grid | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| trina_grid | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| syncfusion | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| **TableView** (2d_scrollables) | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ pinned | ✅ |
| **material_table_view** | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ priority freeze | ~ |
| ultimate_grid | ✅ | ❌ (roadmap) | ~ mixed | ✅ | ✅ | ~ | ✅ 9-region | ✅ |
| data_table_2 | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | sticky hdr | ❌ |
| davi | ✅ | ? | ✅ | ~ | ❌ | ❌ | ✅ | ~ |

### Column-virtualization claim — verified in source, not README

Both pluto and its fork build **every** body column for every visible row:

```dart
// pluto_grid/lib/src/ui/pluto_base_row.dart:93  (identical at trina_base_row.dart:99)
children: columns.map(_makeCell).toList(growable: false),
// columns == stateManager.bodyColumns  (pluto_body_rows.dart:66) — all non-frozen columns
```

Rows *are* virtualized (`ListView.builder` with `itemExtent: rowTotalHeight`, `pluto_body_rows.dart`). So cost = `visibleRows × totalColumns`. A 200-column `SELECT *` with 30 visible rows = 6000 cell widgets built and laid out per frame budget.

`material_table_view` **does** virtualize columns despite its README not advertising it — verified in `lib/src/table_content_layout.dart:203-232`: it walks columns accumulating offsets and only pushes indices into `columnsCenter` when the column intersects the viewport, then breaks out. `TableView` from `two_dimensional_scrollables` lazily builds both axes by construction.

---

## 3. Eliminations

- **`syncfusion_flutter_datagrid`** — technically the strongest off-the-shelf option, but the Community License caps at **<$1M revenue, ≤5 developers, ≤10 employees, never >$3M outside capital**. That is a ceiling wired into a product we may want to sell, on closed source we cannot patch when Flutter breaks it. Out.
- **`ultimate_grid`, `flutter_data_grid`, `om_data_grid`** — all 0.x, all bus-factor 1, all under 130 weekly downloads. `ultimate_grid` is the most interesting of the three (custom `RenderObject` + `TextPainter` LRU, Excel selection, TSV copy, `flutter/widgets.dart` only — no Material lock-in, 78 source files, 19 test files) but it is 6 weeks stale, 3 stars, no column virtualization, and `ultimate_table.dart` alone is 68 KB in one file. Adopting it = adopting an unpaid maintenance contract on someone else's prototype.
- **`data_table_2`** — `DataTable` derivative, no row virtualization for large sets. Wrong category.
- **`davi`, `table_view_ex`** — stale (18 / 11 months), low adoption, view-only. `table_view_ex` is a thin sorting/resizing layer over `two_dimensional_scrollables` — if that route is taken, write it in-repo rather than depend on a 24-download package.

---

## 4. `pluto_grid` status — stale, not dead

- Last pub release 8.1.0 ≈ 7 months ago; last GitHub push 2025-12-14; 15 commits since mid-2025; no tagged GitHub release since 2.10.0 (2022).
- Community consensus is that the original author stepped away; development continued as `pluto_grid_plus` → renamed **`trina_grid`** (`doonfrs`, publisher trinavo.com, 29 commits in the last 3 months, 2.3.0 published 9 days ago).
- Risk profile: pluto works on Flutter 3.44.8 today. The failure mode is a future Flutter release breaking it with nobody to fix it — at which point we fork under time pressure, mid-incident.

`trina_grid` is the same codebase: identical `_makeCell` internals, an automated `pluto → trina` migration tool (class renames + import rewrites, dry-run mode), MIT, plus additions we'd use (cell-level renderers, draggable desktop scrollbars, server-side lazy pagination + infinite scroll, CSV/JSON/PDF export). It inherits pluto's two real weaknesses: **no column virtualization** and **Material coupling** (open issue: *"[Feature] Remove hardcoded colors use material or cupertino design"*).

---

## 5. The Flutter-team base package

`two_dimensional_scrollables` 0.5.3 — publisher **flutter.dev**, BSD-3, 194k weekly downloads, 488 likes, in `flutter/packages` with steady 2026 commits. Provides `TableView.builder` (lazy on both axes, pinned rows/columns, cell merging, span decorations, diagonal or axis-locked scrolling) and `TreeView`.

It is deliberately a **primitive**: no selection model, no editing, no sorting, no keyboard navigation, no column resize/reorder. Known rough edges from the tracker: jank with pinned first row/column at ~15k rows (**fixed and merged 2026-03-03**, flutter/flutter#180563), no intrinsic column sizing, no custom row layout, no scroll-to-item. 12 open `TableView` issues — feature requests, not correctness bugs.

Building VoltQuery's grid on it means owning R4–R7 ourselves. Rough estimate for parity with what pluto gives us today: **~2.5–4k lines, 2–3 weeks** (selection model + range math, keyboard nav/focus, edit overlay + commit path, column resize/reorder/freeze UI, TSV clipboard, scrollbars). `material_table_view` (MIT) already solves the hardest layout parts — visible-column math, freeze priorities, sticky columns, column-control popup route — and is worth reading closely, or vendoring, before writing that from scratch.

---

## 6. Recommendation

1. **Now — migrate `pluto_grid` → `trina_grid`.** Drop-in, automated migration, active maintainer, MIT, same API surface `result_grid.dart` already targets. Cost ≈ 1 day incl. re-testing the staged-edit path. Removes the frozen-dependency risk without touching architecture. This is a *maintenance* move, not a bet.
2. **Then — measure before spending anything else.** Run the two cases that decide the rest: (a) `SELECT *` on a 150+ column table, (b) 100k-row scroll with a wide result. Column-count jank is the only thing pluto/trina cannot fix by configuration. If both are smooth on target hardware, stop here.
3. **If (a) janks, or once the grid becomes the differentiator — build `VoltGrid` on `two_dimensional_scrollables`.** It is the only path that gets true 2D virtualization, DB-specific cell rendering (NULL/BLOB/JSON/bool as first-class), fluent-native theming with no `Material` ancestor hack, and a first-party BSD base maintained by the Flutter team. Keep `trina_grid` shipping until VoltGrid reaches parity behind a flag.
4. **Do not adopt** syncfusion (license ceiling, closed source) or any of the 0.x solo-author grids.

**Verdict on the original question:** pluto_grid is not the best choice, but its *fork* is the right next step. It is also not the ceiling — the ceiling is a grid we own, and Flutter's 2D scrollables is the correct foundation for it.

---

## Sources

- [pub.dev/packages/pluto_grid](https://pub.dev/packages/pluto_grid) · [github.com/bosskmk/pluto_grid](https://github.com/bosskmk/pluto_grid)
- [pub.dev/packages/trina_grid](https://pub.dev/packages/trina_grid) · [github.com/doonfrs/trina_grid](https://github.com/doonfrs/trina_grid) · [pluto→trina migration](https://github.com/doonfrs/trina_grid/blob/main/doc/migration/pluto-to-trina.md)
- [pub.dev/packages/two_dimensional_scrollables](https://pub.dev/packages/two_dimensional_scrollables) · [flutter/packages source](https://github.com/flutter/packages/tree/main/packages/two_dimensional_scrollables) · [pinned-row jank fix #180563](https://github.com/flutter/flutter/pull/180563)
- [pub.dev/packages/material_table_view](https://pub.dev/packages/material_table_view) · [github.com/NikolayNIK/material_table_view](https://github.com/NikolayNIK/material_table_view)
- [pub.dev/packages/syncfusion_flutter_datagrid](https://pub.dev/packages/syncfusion_flutter_datagrid) · [Syncfusion Community License](https://www.syncfusion.com/products/communitylicense)
- [pub.dev/packages/ultimate_grid](https://pub.dev/packages/ultimate_grid) · [pub.dev/packages/flutter_data_grid](https://pub.dev/packages/flutter_data_grid) · [pub.dev/packages/om_data_grid](https://pub.dev/packages/om_data_grid) · [pub.dev/packages/davi](https://pub.dev/packages/davi) · [pub.dev/packages/table_view_ex](https://pub.dev/packages/table_view_ex)
- [Flutter Gems — table packages](https://fluttergems.dev/table/) · ["PlutoGrid has been abandoned…" (Medium)](https://medium.com/@simon_41827/pluto-grid-has-been-abandoned-by-the-original-author-like-so-many-flutter-packages-ab034377eb03)
