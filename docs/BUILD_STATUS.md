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
- **Connections** (`connections/`): built-in demo + saved connections (drift),
  switch/add/delete; SQLite file-open; server form (Postgres/MySQL) with an inline
  **Test connection**.
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

**72 tests** green (`flutter test`); `flutter analyze` clean.

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
- **TLS** — Postgres/MySQL connect with SSL disabled (`TODO(tls)` in the drivers).
- mac/win **keychain** adapter for the SecretStore (ADR-0006).
- `ui/core/theme` (mix tokens) not built; tokens are inlined per widget.

## Next candidates (pick one)

1. NavigationView rail + grid keyboard cell nav (#21 remainder).
2. Background isolate for the SQLite driver — unblocks true Cancel + timeouts.
3. Tables/Views folders + large-schema render-cap (#13 tail).
4. Postgres/MySQL TLS.
5. `ui/core/theme` via mix.

## Run it

```
flutter run -d linux    # full rebuild after pulling; not hot reload for new plugins
```
Linux prereq: `keybinder-3.0` (hotkey_manager) — see README. After a `git pull`
that changed providers/drift: `dart run build_runner build --delete-conflicting-outputs`.

> **⚠ codegen blocked by base_menu 0.1.5**: its published `pubspec.yaml` declares
> `workspace: [gallery]` (an example package it doesn't ship), which aborts pub's
> package-graph load — so `dart run build_runner` / `flutter pub run build_runner`
> fail with *"No workspace packages matching `gallery`"*. `flutter pub get`,
> `analyze` and `test` are unaffected. Workaround until upstream fixes it: delete
> the two `workspace:` lines from
> `~/.pub-cache/hosted/pub.dev/base_menu-0.1.5/pubspec.yaml`, then run codegen.
> (For small provider changes the `*.g.dart` delta can be hand-applied instead.)

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
