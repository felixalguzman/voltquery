# VoltQuery — build status (resume here)

Snapshot of the implementation so a fresh session (or you) can pick up. The
**spec** (what to build) lives in [`docs/README.md`](README.md) → CONTEXT.md,
ADRs 0001–0009, `docs/design/*`. This file tracks **what's built** so far.

## Done (85 PRs merged to `master`)

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
  `indexDdl`, cached in the `SchemaRepository`. **Table Info…** opens a dialog
  with catalog-cheap stats — estimated rows (Postgres `reltuples`, MySQL
  `table_rows`; SQLite keeps none and says so), on-disk size, PK, FKs and
  indexes — plus an opt-in exact `count(*)`, kept separate because on a large
  table that is a full scan.
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
  selectable, copyable error. Saved connections are **editable** — the same
  dialog reopens prefilled, keeping the id so the vault entry and history stay
  attached — with right-click Edit / Duplicate / Copy Name / Delete. Deleting
  removes the stored password too. **SSH tunnelling** (dartssh2) forwards a
  loopback port to the database as seen from the bastion, with password or
  private-key auth; the tunnel's lifetime is tied to the Session, and its
  secrets live in the vault like any other. The bastion's **host key is
  verified** trust-on-first-use against the app's own `known_hosts.json`, with a
  prompt showing the `SHA256:` fingerprint; a *changed* key is surfaced
  distinctly from an unknown one, and an unverified host fails closed. Trusted
  hosts are **listable and revocable** in Settings → Security — TOFU without
  that is only half a trust model. Connection failures are explained
  in plain language with a one-click fix where one exists (`DriverErrorHelper`),
  raw driver text behind a Details toggle.
- **Credentials vault** (`data/services/secret_store.dart`, ADR-0006): Argon2id →
  AES-256-GCM envelope crypto, master password, locked each launch, header padlock.
  **Re-keyable** (`changeMasterPassword`) — envelope crypto means only the
  wrapped DEK is rewritten, so stored secrets are never re-encrypted and an
  unlocked session stays valid; the vault file is now saved write-then-rename so
  a crash mid-rekey can't lose every secret. **Auto-locks** after an idle
  timeout (`VaultAutoLock` wraps the app; 0 = never).
  *Deviation:* vault used on all platforms; mac/win keychain deferred.
- **Persistence** (drift `voltquery.db`, ADR-0005, schema **v6**): query
  **history** panel + saved connections + settings. Secret-free. History rows
  carry a **`HistorySource`** — `editor` (typed and run), `gridEdit` (DML the
  result grid generated), `tool` (app-composed but user-triggered, e.g. Table
  Info's exact `count(*)`). The line is *what the user asked for*, not who typed
  it: introspection the app needs to draw its own tree is deliberately **not**
  recorded, or browsing would bury everything else within a minute. The panel
  shows the **timestamp** (relative under an hour, clock time today, date
  beyond), dims generated rows, tags them, and has a **hide-generated** filter —
  off by default, because a filter you must turn on can't quietly hide a
  destructive UPDATE from you.
- **Search everything** (`ui/features/search/`, **Ctrl+Shift+F** / Edit menu):
  the counterpart to the inline filter — it asks the **catalog**, so it finds a
  column in a table you have never expanded, which on a big schema is nearly
  all of them. `SchemaIntrospector.search()` is implemented across the trio
  (`information_schema` on PG/MySQL — MySQL spans every user database, since
  its schema level *is* the database; `sqlite_master` joined to
  `pragma_table_info` on SQLite, which keeps no column catalog). LIKE wildcards
  are escaped, so `ven_factura` means a literal underscore. Schema and history
  are queried concurrently and a failure in one is reported without taking the
  other down — "no tables matched" and "the server refused" look identical in
  an empty list. Seeds from the editor selection; ↑↓/Enter to open. **Measured**
  (`sqlite_search_perf_test.dart`, printed timings): 15k columns → 6-10ms, 80k
  columns → ~20ms, and a table-name search stays at 1ms at any size because
  object hits fill the limit before the column join runs. Cost tracks the row
  **limit**, not the schema. A `kMinSearchLength` of 2 keeps a stray keystroke
  from becoming a catalog scan; PG/MySQL are a network round-trip and remain
  unmeasured by us. **Scope chips** (All / Tables & views / Columns / History)
  are a query parameter, not a display filter: the row limit is shared and
  objects are collected first, so a pattern matching many table names can spend
  the whole budget before a column is considered.
- **Filter & find** — one `matchesFilter` (substring, case-insensitive, *not*
  prefix: real names are prefix-heavy, `ven_factura` / `secuencia_ncf`) behind a
  shared `ui/core/widgets/filter_field.dart`. Schema and History each get a
  toggle in their section header opening a full-width `FilterRow` beneath it —
  under rather than inside the header because losing the section title also
  loses click-title-to-collapse. The schema filter renders a **separate flat
  list** of hits instead of rebuilding the tree, so every lazy load and
  expansion survives being filtered and comes back untouched; it matches only
  what's **loaded** — and then **escalates to the catalog itself** on a 300ms
  debounce, listing anything else it finds under its own group. Dead-ending at
  "no match in what is loaded" was a dead end precisely when almost nothing is
  loaded. Hits carry their schema (search has no sticky root header to supply
  it) and keep the tree's right-click menu, so a result is never a worse
  version of the row you'd have scrolled to. The editor gets a real find/replace bar (`Ctrl+F`) — re_editor
  had the whole engine (`CodeFindController`: matches, ordering, prev/next,
  regex, replace) and the binding already; it just had no `findBuilder`, so
  nothing appeared.
- **App shell** (`ui/core/shell/app_shell.dart`): a **menu bar** (File / Query /
  View) built on **base_menu** (headless menus, WAI-ARIA keyboard nav; needs
  Flutter ≥3.44.4, repo on 3.44.8) over the sidebar | workspace split. The
  sidebar's three sections (Connections / Schema / History) are their own
  **vertical `MultiPane`**, so they resize against each other and each
  **collapses to its header** in place — collapse swaps that section's
  `PaneEntry` from a fraction to a header-height pixel pane, which is what makes
  the new size stick (`updatePane` only drops a dragged size override when the
  pixel/fraction *type* changes). The header strip is a shared
  `ui/core/widgets/section_header.dart` and the whole strip is the hit target.
  The sidebar itself is an `autoHide` pane: **View → Toggle Sidebar / Ctrl+B**,
  drag the splitter shut, or the **layout buttons at the right of the menu bar**
  (VS Code's placement, and what the `panes` example does with its title-bar
  actions) — tinted when their panel is showing. The menu keeps every entry too:
  it's for discovery and accelerators, the buttons are for the third time in a
  minute. Resizers are themed 1px-drawn / 11px-hit, the same
  split the package's own zero-space example uses. The whole layout
  **persists** (`UiStateRepository`, `ui.*` keys in the settings table): splitter
  sizes via `PaneController.save()/load()` plus which sections are collapsed,
  written on a 600ms trailing debounce because a drag notifies every frame.
  Restore order matters — collapse state first, then sizes, since collapsing
  swaps a pane between fraction and pixel and `load` writes into whichever map
  the entry currently uses. Plus
  **app-wide shortcuts** (⌃⏎ Run,
  F5 Run-script, Ctrl+N new tab, Ctrl+O open) routed to the active Worksheet via a
  `WorksheetCommands` bus — so Run works regardless of focus (⌃⏎ chains after a
  run). NavigationView rail is still TODO (#21). The menu-bar dropdowns and the
  tree context menus share one chrome in **`ui/core/menu/`** (`MenuSurface` /
  `MenuActionRow` / `MenuDivider` + a `ContextMenuRegion` right-click wrapper) so
  base_menu stays behind our own widgets and every menu matches.
- **Settings** (`ui/features/settings/`, File → Settings… / `Ctrl+,`): a
  category-rail dialog over an `AppSettings` model persisted as a drift
  key-value `settings_rows` table (schema v5, `docs/design/persistence.md`).
  One row per key, not one blob, so a key a newer build wrote survives an older
  build saving over it; every value decodes tolerantly (wrong type or
  out-of-range → the default) because a settings row must never brick startup.
  Changes **apply and persist as you make them** — no OK/Cancel. Sections:
  *General* (history retention — `HistoryRepository.prune` runs at startup,
  keeping entries newer than N days **or** the newest M, both rules, never
  either), *Editor* (font family/size, live-previewed), *Results* (row render
  cap, fetch batch, **table preview LIMIT** — the `SELECT * … LIMIT n` a schema
  tree click writes, kept separate from the render cap because one is editable
  query text and the other a client-side budget — and NULL display text),
  *Window* (**title-bar show/hide** — the
  Linux runner's `GtkHeaderBar` hidden at runtime via window_manager, for tiling
  WMs where the compositor already draws the frame; the menu bar is a
  `DragToMoveArea` and File → Quit exists so hiding it isn't a one-way door),
  *Connections* (default TLS mode + connect timeout for **new** connections
  only), *Security* (change master password, auto-lock, trusted SSH hosts).
- **State**: Riverpod **codegen** (`@riverpod`, ADR-0004). Run
  `dart run build_runner build` after editing providers/drift tables.
- **Theming** (`ui/core/theme/`, #7 **done**): the palette lives in one file and
  the app reads it **from the widget tree**, so it can change at runtime.
  Settings → **Appearance** switches Dark/Light and applies immediately.
  - Step 1 killed the duplication: **109** private `const _accent =
    Color(0xFF2FE6FF)` across 19 files, with four colours already drifted (two
    reds, two greens, *three* ambers). `VoltPalette` holds the hexes;
    `SqlTypeColors` / `engineBrand` sit beside it as the other vocabularies. A
    test fails on any `Color(0x…)` outside `ui/core/theme/`.
  - Step 2 moved all 19 files to `VoltTheme.of(context)`. The mechanical part is
    a rename; the parts that aren't: a `static const` holding colours (pluto's
    grid config) has no context and became an instance getter; a constructor
    with a token as a **default value** can't be const at all; and two files
    already used `t` for a `TableInfo`, which the palette's name collided with.
    `prefer_const_constructors` is now enabled so `dart fix --apply` restores
    every `const` a token didn't actually cost — 400+ of them.
  - **The light palette is not the dark one inverted.** An accent tuned to glow
    on near-black is nearly invisible on white, and a hover that lightens has to
    darken. Every value is restated, the SQL syntax theme follows
    (`atom-one-light`), and tests assert WCAG-AA contrast for body text in
    *both* palettes.

- **Narrow-pane behaviour** (#81, found by driving the live app): both the
  worksheet toolbar and the grid status bar overflowed once their pane was
  dragged narrow, which paints the buttons past the edge — **▶ Run and Add Row
  were simply unclickable**. Both now shed content in priority order: the
  identity text ellipsises first, then secondary controls that have another
  home in the menu bar, and the status bar's actions go icon-only rather than
  disappear. Run is the last thing standing.

**397 tests** green (`flutter test`, +16 more with live PG/MySQL); `flutter analyze` clean.

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
- **SSH multi-hop / jump-host chains** are unsupported — one bastion only.
- mac/win **keychain** adapter for the SecretStore (ADR-0006).
- `ui/core/theme` (mix tokens) not built; tokens are inlined per widget. This is
  why Settings has **no Appearance section** — a theme picker needs the token
  layer first (#7).
- **Title-bar toggle is Linux-verified only.** window_manager's
  `setTitleBarStyle` hides the runner's `GtkHeaderBar` there; the macOS/Windows
  paths are the plugin's own and untested by us.
- **No drift migration test for v4→v5.** The step is a bare `createTable`, and
  the repo has no `drift_dev schema dump` snapshots to test against.
- **Font enumeration is Linux-only.** `FontCatalog` shells out to `fc-list
  :spacing=100` (fontconfig's MONO filter); macOS and Windows fall back to a
  curated list of common families. The field stays free text either way, so a
  family the catalog missed can still be typed.
- **A hidden/collapsed pane still builds its subtree** — `panes` clips it to
  zero rather than unmounting it. Harmless today (the panels are cheap), but it
  means a finder can locate a widget the user cannot see, so the shell tests
  assert geometry rather than presence.

## Next candidates (pick one)

1. NavigationView rail + grid keyboard cell nav (#21 remainder).
2. Background isolate for the SQLite driver — unblocks true Cancel + timeouts.
3. **Grid write-path** — domain layer, typed editors, staged buffer and SQL
   review panel shipped in #63/#64, hardened in #66; row insert/delete/clone in
   #79. Remaining: a **JSON** editor, and multi-row select → delete in one go.
   **Import** is the counterpart to #83's export and is not built.
4. **Result grid engine** (#67) — pluto_grid is unmaintained; migrate to the
   active `trina_grid` fork, then measure. A custom `VoltGrid` on
   `two_dimensional_scrollables` is the agreed long-term destination but is
   **deferred**. Both pluto and trina build every body column for every visible
   row, so a wide `SELECT *` is the failure mode — `wide_metrics` (5k × 26) is
   seeded for that test. See `docs/research/data-grid-options.md`.
5. **Connectivity** — **TLS and SSH tunnelling landed**; keep-alive /
   auto-reconnect remains, as does multi-hop (jump-host chains) and known-hosts
   verification.
7. Tables/Views folders + large-schema render-cap (#13 tail).
8. `ui/core/theme` via mix.

See `docs/research/feature-gaps.md` (parity) and `docs/research/differentiators.md`
(offense) for the surveyed backlog these were picked from.

### Agreed but not built

**Settings pane** — *built 2026-08-01*, see the Settings bullet above. Left out
deliberately: Appearance/theme (blocked on #7) and keybinding customization.

**Type-to-filter across the app** (asked for 2026-08-01): start typing to narrow
the schema tree, query history, and the table-info Columns/DDL tabs. Each of
those is already a list the user scans by eye, and the schema tree in particular
is unusable by scrolling once a database has hundreds of tables. Wants one
shared filter widget rather than three, and should match on substring rather
than prefix (column names are prefix-heavy: `secuencia_`, `ven_`).


**Remember expanded schema-tree nodes per connection** (design settled
2026-08-01): persist expanded *paths* (`schema/table`, `schema/table/Indexes`)
rather than node identities, so they survive schema changes; restore on every
connect, **breadth-first and capped** (~50 nodes) so a large saved state
degrades to "most of it" instead of stalling the tree behind a burst of catalog
queries; silently prune paths that no longer resolve. Stored as **UI state in
its own table, not in `ConnectionOptions`** — it's per-machine ephemera, not
something you'd want in an exported or shared connection. Expansion only;
selection and scroll position aren't worth the complexity.

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

### Debug bridge — ask the running app, don't read pixels

`lib/debug/debug_bridge.dart` registers VM-service extensions on a debug build,
and `tool/vq` calls them from the shell. Driving the app through Flutter Driver
means asserting on screenshots; a staged edit is data, so read it back as data.

```bash
flutter run -d linux -t test_driver/app.dart \
  --vmservice-out-file=.dart_tool/vmservice.txt

tool/vq snapshot                   # connection, tabs, staged grid edits + the SQL they'd run
tool/vq errors                     # Flutter errors so far (--clear to reset)
tool/vq run "SELECT * FROM orders" # run in the active worksheet
```

`snapshot` builds each grid's statements through the **same**
`GridEditBuffer.toSql` and `primaryKeyValues` the UI uses, so it can't drift
into describing statements the app would never send. `errors` matters most:
a `RenderFlex` overflow never throws, so `tool/vq errors` is how a layout
regression becomes a one-line check — it reports the summary **and the
`file:line`**, which needs `debugTransformDebugCreator` (the raw diagnostics
carry only a chain of widget types).

Debug-only twice over: `registerDebugExtensions` returns immediately unless
`kDebugMode`, and nothing in `lib/main.dart` references it — only
`test_driver/app.dart` — so a release build never links it in. `main()` takes
an optional `onContainerReady` so the bridge attaches to the app's real
`ProviderContainer` rather than a second one beside it.

### Driving the live app

`test_driver/app.dart` is the normal app plus `enableFlutterDriverExtension()`
— a separate entrypoint on purpose, since that extension opens a control
channel into the isolate and has no business in a shipped build:

```bash
flutter run -d linux -t test_driver/app.dart
```

With it running, the Dart MCP server (`claude mcp add dart -- dart mcp-server`)
can tap, screenshot, hot-reload and read runtime errors against the real app.
Two things it needs from us: **fluent's `Tooltip` is not material's**, so
`find.byTooltip` / driver's `ByTooltipMessage` see nothing — status-bar actions
carry `gridActionKey(label)` and are selected `ByValueKey`. And a
`RenderFlex` overflow **does not throw in release**: the child is still laid
out, just never painted and never hit-testable, so a too-narrow pane silently
eats a button. Both narrow-pane bugs below were found this way, not by tests.

### Cross-engine live tests

`test/ui/features/query_workspace/grid_row_write_live_test.dart` **executes** the
DML the grid generates against a real server, per engine — every other grid test
stops at the string. SQLite runs in-memory always; Postgres and MySQL read a URL
from the environment and **skip** when it's absent, so a missing server can't
look like a pass:

```bash
VOLTQUERY_PG=postgres://postgres:postgres@localhost:5432/voltquery_test \
VOLTQUERY_MYSQL=mysql://root:password@localhost:3306/voltquery_test \
  flutter test test/ui/features/query_workspace/grid_row_write_live_test.dart
```

Two engine quirks the suite pins down: a stock Postgres container speaks **no
TLS** (so the test opts out of the app's secure default rather than the default
being weakened), while MySQL 8's `caching_sha2_password` **refuses** to
authenticate over a plaintext socket — opposite requirements, both real. And
`mysql_client` returns a `TINYINT(1)` as the **string** `'1'`/`'0'`, which is why
the grid's `_truthy` / `_asOriginalShape` accept string spellings.

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
