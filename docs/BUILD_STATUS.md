# VoltQuery — build status (resume here)

Snapshot of the implementation so a fresh session (or you) can pick up. The
**spec** (what to build) lives in [`docs/README.md`](README.md) → CONTEXT.md,
ADRs 0001–0009, `docs/design/*`. This file tracks **what's built** so far.

## Done (60 PRs merged to `master`)

Multi-engine SQL manager, working live for **SQLite · PostgreSQL · MySQL/MariaDB**
— all interchangeable behind the driver port (ADR-0003).

- **Drivers** (`lib/data/drivers/`): `sqlite/` (raw sqlite3), `postgres/`,
  `mysql/`, chosen by `driver_factory.dart`. Capability-gated (e.g. query-cancel
  is off — not exposed by the postgres/mysql packages in these versions).
- **Query workspace** (`lib/ui/features/query_workspace/`): re_editor + pluto_grid
  in a resizable `panes` split; **Worksheet tabs**, each with its **own** Session
  (`worksheetSessionProvider.autoDispose.family`, ADR-0002/0004). `WorksheetRunner`
  materializes results (render-capped). **Multi-statement Run** (ADR-0007, #12/#15):
  a dialect-aware `SqlStatementSplitter` splits the buffer, statements run in order
  **stop-on-error**, each writes its own HistoryEntry; row-returning statements get
  **result sub-tabs**, the rest a **Messages log**. A successful DDL evicts the
  schema-tree cache so the sidebar self-refreshes. **Run** (whole), **Run at
  cursor** / **Run selection** (⌃⏎ = selection-else-cursor) via the splitter's
  offset-aware `statementAt`; **continue-on-error** toggle; **manual-commit**
  toggle (Commit/Rollback); **Cancel** (stops the rest of a script + abandons the
  Session).
- **Schema sidebar** (`schema_browser/`): **lazy tree** (ADR-0008, #13) — Postgres
  nests Schema → objects; SQLite/MySQL show objects at root. Every level loads on
  the fluent `TreeView`'s `onExpandToggle` via a per-Connection `SchemaRepository`
  (one-entry-per-parent-ref cache, evict-on-failure). Row-tap opens the table in
  a new worksheet tab; chevron reveals columns + a lazy **Indexes** group
  (`indexes()` implemented across the driver trio). Runs on the per-Connection
  introspection Session. Columns mark **PK** (accent key) and **FK** (link glyph)
  across all three engines. **Right-click any node → context menu** (#53, on
  base_menu): tables/views get *Copy Name · Copy CREATE · Open in Editor ·
  Preview Data*; columns get *Copy Name*; indexes get *Copy Name · Copy CREATE*.
  "Copy CREATE" fetches per-engine DDL (SQLite `sqlite_master`; MySQL `SHOW
  CREATE`; Postgres `pg_get_viewdef`/`pg_get_indexdef`, tables reconstructed from
  the catalog with a header note) via new `SchemaIntrospector.tableDdl`/
  `indexDdl`, cached in the `SchemaRepository`.
- **Demo database** (temp-file SQLite, seeded per run): `customers`, `products`,
  `orders`, `order_items` (composite PK), a PK-less `audit_log` and a
  `customer_orders` view, with FKs and three indexes. Shaped to exercise the
  app's own features — every `ColumnEditorKind` the grid renders (boolean, date,
  datetime, decimal, integer, text), the two cases the grid must refuse to edit
  (view, no PK), a composite row identity, and a NULL in a nullable column.
- **Result grid** (`query_workspace/result_grid.dart`): pluto_grid, read-only
  unless the result maps 1:1 onto one table's rows. Then cells become editable
  with **typed editors** per `ColumnEditorKind` (toggle, date picker, enum
  dropdown, validated numbers), edits are **staged** — never written on a
  keystroke — and **Review & Apply** shows the exact statements before they run,
  inside a transaction so a partial failure applies nothing. PK columns are
  read-only (the UPDATE addresses the row by them). Enum options come from
  `pg_enum`, MySQL `column_type`, or a SQLite `CHECK (col IN (...))`.
- **Connections** (`connections/`): built-in demo + saved connections (drift),
  switch/add/delete; SQLite file-open; a **tabbed connection dialog**
  (General / Security / SSH / Advanced) over a `ConnectionOptions` model stored
  as one JSON column, so adding a setting isn't a schema migration. Carries
  **TLS mode** (disable / require / verify-full, default *require*; Postgres
  honours all three + a custom CA PEM, MySQL can only encrypt), a **colour tag**
  shown as a bar in the connections list, a **read-only** guard, SQLite
  **FK enforcement**, and a connect timeout. Inline **Test connection** with a
  selectable, copyable error.
- **Credentials vault** (`data/services/secret_store.dart`, ADR-0006): Argon2id →
  AES-256-GCM envelope crypto, master password, locked each launch, header padlock.
  *Deviation:* vault used on all platforms; mac/win keychain deferred.
- **Persistence** (drift `voltquery.db`, ADR-0005): query **history** panel +
  saved connections (schema v2 + migration). Secret-free.
- **App shell** (`ui/core/shell/app_shell.dart`): a **menu bar** (File / Query /
  View) built on **base_menu** (headless menus, WAI-ARIA keyboard nav; needs
  Flutter ≥3.44.4, repo on 3.44.8) over the sidebar | workspace split, plus
  **app-wide shortcuts** (⌃⏎ Run,
  F5 Run-script, Ctrl+N new tab, Ctrl+O open) routed to the active Worksheet via a
  `WorksheetCommands` bus — so Run works regardless of focus (⌃⏎ chains after a
  run). NavigationView rail is still TODO (#21). The menu-bar dropdowns and the
  tree context menus share one chrome in **`ui/core/menu/`** (`MenuSurface` /
  `MenuActionRow` / `MenuDivider` + a `ContextMenuRegion` right-click wrapper) so
  base_menu stays behind our own widgets and every menu matches.
- **State**: Riverpod **codegen** (`@riverpod`, ADR-0004). Run
  `dart run build_runner build` after editing providers/drift tables.
- **Theming**: inline "Clean Dev-Tool" tokens (dark, cyan accent) — not yet in
  `ui/core/theme` (still TODO per #7).

**182 tests** green (`flutter test`); `flutter analyze` clean.

## Deferred / known gaps

- **NavigationView rail + grid keyboard cell nav** — #21 remainder. Menu bar +
  global shortcuts landed; the NavigationView rail and pluto_grid arrow-key cell
  nav (+ returning caret focus to the editor after a run) are still open.
- **Tables/Views folders + sibling render-cap/filter** — the lazy tree flattens
  objects (icon-distinguished) rather than foldering; large-schema cap (#13 §Very
  large) deferred.
- **True per-statement Cancel + timeouts** (#12 tail) — Cancel stops the rest of
  a script and abandons+closes the Session (aborts in-flight *server* queries);
  a single running **SQLite** statement can't be interrupted (sync FFI on the
  main isolate) and per-statement **timeout** is not wired — both wait on the
  background-isolate slice. Run / Run-at-cursor / Run-selection, continue-on-error,
  and manual-commit are all done.
- **TLS certificate verification on MySQL** — `mysql_client` hardcodes
  `SecureSocket.secure(onBadCertificate: (_) => true)`, so MySQL TLS is
  encrypted but never authenticated. The driver refuses `verifyFull` rather
  than downgrade silently; fixing it properly needs a different MySQL package.
- **No client-side FK validation *yet*.** The target is now introspected
  (`ColumnInfo.references`, all three engines) and shown in the tree, but
  nothing consumes it: checking a value before sending it, a parent-row picker,
  and FK navigation (P2 in `docs/research/feature-gaps.md`) all remain to build.
  The metadata that blocked them is in place.
- mac/win **keychain** adapter for the SecretStore (ADR-0006).
- `ui/core/theme` (mix tokens) not built; tokens are inlined per widget.

## Next candidates (pick one)

1. NavigationView rail + grid keyboard cell nav (#21 remainder).
2. Background isolate for the SQLite driver — unblocks true Cancel + timeouts.
3. **Grid write-path** *(inline editing landed)* — domain layer, typed editors,
   staged buffer and SQL review panel shipped in #63/#64, hardened in #66.
   Remaining: **row insert/delete/clone**, **"Copy as SQL"**, an explicit
   **Set NULL** action (empty input on a nullable column currently means NULL,
   so a deliberate `''` is unreachable), and a **JSON** editor.
4. **Result grid engine** (#67) — pluto_grid is unmaintained; migrate to the
   active `trina_grid` fork, then measure. A custom `VoltGrid` on
   `two_dimensional_scrollables` is the agreed long-term destination but is
   **deferred**. Both pluto and trina build every body column for every visible
   row, so a wide `SELECT *` is the failure mode — `wide_metrics` (5k × 26) is
   seeded for that test. See `docs/research/data-grid-options.md`.
5. **Connectivity** — **TLS landed**; SSH tunnel and keep-alive/auto-reconnect
   remain. Without a tunnel, databases behind a bastion are still unreachable.
   The connection dialog already has an (inert) SSH tab waiting for it.
7. Tables/Views folders + large-schema render-cap (#13 tail).
8. `ui/core/theme` via mix.

See `docs/research/feature-gaps.md` (parity) and `docs/research/differentiators.md`
(offense) for the surveyed backlog these were picked from.

## Run it

```
flutter run -d linux    # full rebuild after pulling; not hot reload for new plugins
```
Linux prereq: `keybinder-3.0` (hotkey_manager) — see README. After a `git pull`
that changed providers/drift: `dart run build_runner build --delete-conflicting-outputs`.

Codegen works normally again — both of the walls that briefly blocked it after
base_menu landed are cleared (kept here because the *causes* still bite anyone
on an older lockfile):

1. **base_menu pubspec** — 0.1.5 (and repo `main`) declare `workspace: [gallery]`
   but the pub.dev tarball omits `gallery/`, aborting pub's package-graph load
   (*"No workspace packages matching `gallery`"*). Fixed by pinning base_menu to
   a **git ref** in `pubspec.yaml` — a git clone includes `gallery/`, so the
   workspace resolves. Revisit if upstream publishes a fixed release.
2. **analyzer 7.6.0** couldn't serialize Dart **dot-shorthand** (which
   base_menu's source uses), throwing `Missing implementation of
   visitDotShorthandPropertyAccess`. Fixed by the **Riverpod 2→3 / analyzer 12**
   bump — see *Toolchain* below.

### Toolchain

Dart **3.12.2** / Flutter **3.44.8**. Codegen stack after the Riverpod 3 bump:
`analyzer` 12, `riverpod` + `flutter_riverpod` 3.3, `riverpod_generator` 4,
`source_gen` 4, `drift`/`drift_dev` 2.34, `build_runner` 2.15, `sqlite3` 3.5.
`freezed` was **dropped** — it was in the pubspec but never used (no `@freezed`,
no `*.freezed.dart`); re-add it if the `TODO(build)` model comments are taken up.

Riverpod 3 migration notes (for anyone touching providers):
- `AsyncValue.valueOrNull` → **`.value`** (nullable accessor).
- `.select()` is gone on functional async providers; use `ref.listen(p, (_, _) {})`
  to depend-without-rebuilding (that's the worksheet-session keep-alive).
- `Override` now comes from `package:flutter_riverpod/misc.dart`.
- A one-off `container.read(p.future)` on an **autoDispose** provider disposes it
  as the read returns — for a stream provider that lands mid-loading and throws.
  Hold a `container.listen(...)` subscription across the await (tests only; the
  app watches these providers).

### Live test connections (local Docker)

- **Postgres**: host `localhost`, port `5432`, user/pass per your container env
  (`docker exec <pg> env | grep POSTGRES`), a database name from that server.
- **MySQL/MariaDB**: host `localhost`, port `3306`, user `root` (or yours),
  password + database per your container.

First save of a server connection prompts to **create a master password** (vault);
relaunch → vault locked → click the padlock to unlock, or it prompts on reopen.

## Workflow conventions (how this was built)

- One vertical slice per branch → PR → squash-merge → `master`. Test-first where a
  seam is server-free; server drivers verified live.
- Commit generated files (`*.g.dart`, plugin registrants) with the slice.
- Keep third-party packages behind our own widgets/ports so they're swappable.
