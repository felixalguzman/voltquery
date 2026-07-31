# VoltQuery — spec index

Build-ready architecture spec, produced by `/wayfinder` (planning only — no app
code). Everything a build pass needs is below. The wayfinder map (GitHub issue
#1, closed) and its 15 decision tickets hold the per-decision rationale.

## Start here

- [`../CONTEXT.md`](../CONTEXT.md) — **domain glossary** (ubiquitous language; driver-agnostic).

## Design docs (`docs/design/`)

| Doc | Covers |
|-----|--------|
| [architecture.md](design/architecture.md) | Layered `domain/data/ui`, Riverpod, folder tree, per-Worksheet Session |
| [driver-abstraction.md](design/driver-abstraction.md) | `Driver`/`Session` port, `ResultCursor`, `SchemaIntrospector`, `DriverError`, `Capabilities` |
| [persistence.md](design/persistence.md) | drift `voltquery.db` schema, migrations, retention (secret-free) |
| [credentials.md](design/credentials.md) | `SecretStore` (keychain / Linux vault), envelope crypto, unlock model |
| [query-execution.md](design/query-execution.md) | Statement splitting, run model, transactions, per-engine cancel |
| [schema-tree.md](design/schema-tree.md) | Lazy-everywhere tree, per-Connection introspection Session, caching |

## ADRs (`docs/adr/`) — the hard-to-reverse bets

0001 uniform object hierarchy · 0002 session-per-worksheet · 0003 driver
abstraction (`sqlite3` over drift) · 0004 layering + session lifecycle · 0005
persistence (drift, secret-free) · 0006 credential handling · 0007 query
execution · 0008 schema-tree lazy-load.

## Research dossiers (`docs/research/`) — primary-source findings

[db-drivers](research/db-drivers.md) · [secure-storage](research/secure-storage.md) ·
[fluent-shell](research/fluent-shell.md) · [editor-grid](research/editor-grid.md).

## UI prototypes (throwaway `prototype/*` branches)

Validated decisions live in the ADRs; these are visual reference only:
`prototype/theming` (Clean Dev-Tool) · `prototype/connection-ux` ·
`prototype/editor-grid` · `prototype/feedback-ux` — screenshots in
`docs/prototype-assets/`.

## Locked stack & constraints

- UI stack: [`UI_STACK.md`](UI_STACK.md) (fluent_ui, re_editor, pluto_grid, base_menu, mix, …).
- State = **Riverpod**. Launch DBs = **PostgreSQL, MySQL/MariaDB, SQLite**. Desktop-first.
- **Out of scope:** charts, ER diagrams, migrations/DDL tooling, import/export,
  other DB drivers, global schema search.

## Suggested first build slice

`SQLite connect → run SQL → rows in grid` — no network, no credentials/vault;
smallest path exercising the Driver port, `ResultCursor`, editor↔grid, and the
Riverpod session family end-to-end. Then add Postgres/MySQL + the credential vault.
