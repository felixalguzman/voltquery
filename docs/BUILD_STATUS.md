# VoltQuery — build status (resume here)

Snapshot of the implementation so a fresh session (or you) can pick up. The
**spec** (what to build) lives in [`docs/README.md`](README.md) → CONTEXT.md,
ADRs 0001–0009, `docs/design/*`. This file tracks **what's built** so far.

## Done (34 PRs merged to `master`)

Multi-engine SQL manager, working live for **SQLite · PostgreSQL · MySQL/MariaDB**
— all interchangeable behind the driver port (ADR-0003).

- **Drivers** (`lib/data/drivers/`): `sqlite/` (raw sqlite3), `postgres/`,
  `mysql/`, chosen by `driver_factory.dart`. Capability-gated (e.g. query-cancel
  is off — not exposed by the postgres/mysql packages in these versions).
- **Query workspace** (`lib/ui/features/query_workspace/`): re_editor + pluto_grid
  in a resizable `panes` split; **Worksheet tabs**, each with its **own** Session
  (`worksheetSessionProvider.autoDispose.family`, ADR-0002/0004). `WorksheetRunner`
  materializes results (render-capped).
- **Schema sidebar** (`schema_browser/`): **lazy tree** (ADR-0008, #13) — Postgres
  nests Schema → objects; SQLite/MySQL show objects at root. Every level loads on
  the fluent `TreeView`'s `onExpandToggle` via a per-Connection `SchemaRepository`
  (one-entry-per-parent-ref cache, evict-on-failure). Row-tap runs `SELECT *`;
  chevron reveals columns. Runs on the per-Connection introspection Session.
- **Connections** (`connections/`): built-in demo + saved connections (drift),
  switch/add/delete; SQLite file-open; server form (Postgres/MySQL) with an inline
  **Test connection**.
- **Credentials vault** (`data/services/secret_store.dart`, ADR-0006): Argon2id →
  AES-256-GCM envelope crypto, master password, locked each launch, header padlock.
  *Deviation:* vault used on all platforms; mac/win keychain deferred.
- **Persistence** (drift `voltquery.db`, ADR-0005): query **history** panel +
  saved connections (schema v2 + migration). Secret-free.
- **State**: Riverpod **codegen** (`@riverpod`, ADR-0004). Run
  `dart run build_runner build` after editing providers/drift tables.
- **Theming**: inline "Clean Dev-Tool" tokens (dark, cyan accent) — not yet in
  `ui/core/theme` (still TODO per #7).

**30 tests** green (`flutter test`); `flutter analyze` clean.

## Deferred / known gaps

- Grid **keyboard cell navigation** — issue #21 (selection works; arrow-nav needs
  focus/shortcuts work, batched with the shell).
- **Index nodes + FK/PK detail** — introspector `indexes()` still
  `UnimplementedError`; the tree stops at columns. PK shown, FK not yet.
- **Tables/Views folders + sibling render-cap/filter** — the lazy tree flattens
  objects (icon-distinguished) rather than foldering; large-schema cap (#13 §Very
  large) deferred.
- **Multi-statement scripts + result sub-tabs** (#12/#15) — one statement per run.
- **TLS** — Postgres/MySQL connect with SSL disabled (`TODO(tls)` in the drivers).
- mac/win **keychain** adapter for the SecretStore (ADR-0006).
- `ui/core/theme` (mix tokens) not built; tokens are inlined per widget.

## Next candidates (pick one)

1. Multi-statement + result sub-tabs (#12/#15).
2. Keyboard nav / shortcuts (#21) + the app shell (NavigationView + menu bar).
3. Index introspection — implement `indexes()` across the driver trio; hang
   Index nodes under each table (schema tree already lazy-loads their level).
4. Postgres/MySQL TLS.
5. `ui/core/theme` via mix.

## Run it

```
flutter run -d linux    # full rebuild after pulling; not hot reload for new plugins
```
Linux prereq: `keybinder-3.0` (hotkey_manager) — see README. After a `git pull`
that changed providers/drift: `dart run build_runner build --delete-conflicting-outputs`.

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
