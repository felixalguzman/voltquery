# Persistence store — connections, history, settings

Design output of issue **Persistence store — connections, history, settings**
(#10). Plan-only. Fills `data/services` (`LocalStore`) + `data/repositories` from
the architecture (`docs/design/architecture.md`). Domain terms: `CONTEXT.md`.
Recorded in **ADR-0005**.

## Store

A single **drift** (SQLite) database, `voltquery.db`, in the per-OS app-support
directory (`path_provider` `getApplicationSupportDirectory()/VoltQuery/`).

> **Why drift here when ADR-0003 rejected drift for user DBs?** Different job.
> User DBs have *arbitrary runtime* schemas (drift can't model them). VoltQuery's
> *own* store has a *fixed compile-time* schema — drift's sweet spot: type-safe
> queries, first-class migrations, reactive `.watch()`.

**The DB is non-sensitive** — it holds **no secrets, ever** (ref-only, see
below), so it is not encrypted by default. (SQLCipher/SQLite3MultipleCiphers is a
later option, out of scope.)

## Secret boundary (ref-only)

The `connections` table stores a `credentialRef` — an opaque key — and **never**
the secret. The secret (and, on Linux's master-password path, its encrypted
blob) lives entirely in the credentials layer's own store (issue #11). Deleting a
connection makes `ConnectionRepository` also purge the secret by `credentialRef`
via the credentials layer — a coordination point with #11.

## Tables

### connections
`id` (uuid, pk) · `name` · `engine` (enum: postgres|mysql|sqlite) · `host` ·
`port` · `username` · `credentialRef` (nullable — SQLite has none) ·
`sqlitePath` (nullable — SQLite only) · `defaultDatabase` (nullable) ·
`tlsMode` + `tlsCertRef` (nullable) · `groupId` (nullable → flat when null) ·
`color` (nullable, ties to theme accent) · `sortOrder` · `createdAt` ·
`updatedAt` · `lastConnectedAt` (nullable).

### connection_groups  *(optional folders; nesting via parentId)*
`id` (pk) · `name` · `parentId` (nullable) · `sortOrder`. A connection with
`groupId = null` shows at the root. Folder **UI** may be deferred; the schema
supports it from day one so no migration is needed to add it later.

### worksheets  *(open-tab drafts — the folded "tab/session" residual)*
Persists open **Worksheet** drafts so relaunch restores the workspace:
`id` (WorksheetId) · `connectionId` (nullable) · `activeDatabase` (nullable) ·
`sql` (the unsaved Query buffer) · `caretOffset` · `tabOrder` · `updatedAt`.
**Sessions are not persisted** — a restored Worksheet reconnects lazily on first
action (per the `autoDispose.family` session model, ADR-0004).

### history
`id` (pk) · `connectionId` (FK → connections, `ON DELETE SET NULL`) ·
`connectionName` + `engine` (**denormalized** so history stays readable after a
connection is deleted) · `databaseName` · `sql` · `startedAt` · `durationMs` ·
`status` (enum: ok|error|canceled) · `rowCount` (nullable) · `errorKind`
(nullable, from `DriverErrorKind`) · `errorMessage` (nullable). Indexes on
`(connectionId)` and `(startedAt)`. Stores a `HistoryEntry`, **not** the
ResultSet (per domain model).

### settings
Typed key-value: `key` (pk) · `value` (JSON text). Kept in the **same** drift DB
(single store — no separate `shared_preferences`), so all app state shares one
migration lineage and transactional boundary.

## Migrations

drift `schemaVersion` (starts at **1**) + a `MigrationStrategy`
(`onCreate`/`onUpgrade`). Generated schema snapshots (`drift_dev schema dump`)
back migration tests so upgrades are verified across versions.

## History retention

History grows unbounded otherwise. A pruning policy driven by `settings`:
default **keep 90 days OR 2000 rows per connection** (whichever is larger),
pruned on startup; fully configurable, and disable-able.

## Reactive reads

Repositories expose drift `.watch()` streams surfaced as Riverpod
`StreamProvider`s: the connection sidebar and history pane update live as rows
change — no manual refresh.

## Repository mapping (from architecture)

| Repository | Tables |
|------------|--------|
| `ConnectionRepository` | `connections`, `connection_groups` (+ purges secrets via #11 on delete) |
| `HistoryRepository` | `history` |
| `SettingsRepository` | `settings` |
| `WorksheetRepository` | `worksheets` (draft persistence / restore) |

## Hand-off

- **Credentials (#11)** owns what `credentialRef` points to (keychain vs
  encrypted file, per platform) and the purge-on-delete call.
