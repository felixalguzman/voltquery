# VoltQuery — Domain Glossary (CONTEXT.md)

Ubiquitous language for VoltQuery, a cross-platform desktop SQL database manager
(DBeaver alternative) supporting PostgreSQL, MySQL/MariaDB, and SQLite. The model
is **driver-agnostic**: one vocabulary spans all three engines; per-engine
differences are expressed as *capabilities*, never as separate concepts.

> Glossary only — no implementation details. See `docs/adr/` for decisions with
> trade-offs, and issue **VoltQuery — build-ready architecture spec** for the map.

## Hierarchy

The browsable object tree is one **canonical, uniform hierarchy** with optional
levels. A driver's **Capabilities** declare which levels it populates; consumers
(the schema tree, etc.) render against the canonical shape, not per-engine shapes.

```
Server → Database → Schema → Object ({Table, View, Index, …})
```

- **Postgres** populates every level (a connection binds to one Database; Schemas are namespaces within it).
- **MySQL/MariaDB** skips **Schema** (Database and Schema are synonyms in MySQL).
- **SQLite** skips **Server** and **Schema** (a file *is* the Database).

### Server
Top level of the hierarchy — a database server reachable over the network.
Absent for SQLite (`Capabilities.hasServer = false`).

### Database
A named database hosted on a Server (or, for SQLite, the file itself). Always present.

### Schema
A namespace *within* a Database that groups objects. Present only when
`Capabilities.hasSchemas = true` (Postgres). For MySQL, Database = Schema.

### Object
A leaf-ish schema object living under a Schema (or Database, where Schemas are
absent). Concrete object terms:

- **Table** — a base relation. Has ordered **Column**s, plus indexes/keys.
- **View** — a named query presented as a relation. Same Column shape as a Table for browsing.
- **Index** — an access structure over Table columns.

### Column
**Schema metadata** for a Table/View column — durable, introspected from the
engine: name, data type, nullable, primary-key flag, foreign-key flag, default
value, ordinal. **Distinct from `ResultField`** (see below): a Column describes
stored schema; a ResultField describes one projection of one query result.

## Query results

### ResultSet
The outcome of **one** Execution that returned rows: an ordered list of
**ResultField**s (the columns) plus a sequence of **ResultRow**s. A ResultSet may
be **partial** — a window/page over a larger result — since drivers stream
unevenly and the grid pages lazily (mechanism is out of this ticket; see the
fog item *Query editor ↔ result grid wiring*). Ephemeral; never persisted.

### ResultField
One column of a ResultSet — a query **projection**: name, inferred data type,
ordinal. Carries **no** PK/FK/nullable metadata (it may be `count(*)`, an
expression, or a join). Not a `Column`.

### ResultRow
One row of a ResultSet — an ordered tuple of cell values aligned to the
ResultFields.

## Authoring & running

Parallels the Connection/Session split: a **volatile in-flight** concept
(Execution) and a **durable record** (HistoryEntry) are kept distinct.

### Query
The **authored SQL text** a user writes in an editor buffer. May contain
multiple **Statement**s. Not persisted unless explicitly saved (a saved Query is
a later concern; unsaved authoring is the default).

### Statement
A single, parseable SQL command — one `;`-delimited unit of a Query. Running a
Query may execute one Statement or a batch of them.

### Execution
**One live run** of a Statement (or batch) against a **Session**: in-flight and
**cancellable**, yielding a **ResultSet** or an error, plus metrics — `startedAt`,
`duration`, `rowsAffected`/`rowsReturned`, `status`. Volatile; not persisted.

### HistoryEntry
A **durable record** of a past Execution: SQL text, Database, timestamp,
duration, status, row count. Does **not** store the ResultSet (re-running
re-executes). The collection of these is the **QueryHistory**.

## Workspace

### Worksheet
The unit of work, presented in the UI as a **Tab**. Holds a **Query** (editor
buffer), the current **Execution** and its **ResultSet** (if any), and a bound
**Session**. Each Worksheet opens its **own** Session, so transactions,
current-database, temp tables, and session variables are **isolated per
Worksheet** — a `BEGIN` or `USE db` in one Tab never affects another.

Cardinality: `Connection 1..* Session`, `Session 1..1 Worksheet`.

## Driver-agnosticism

### Engine
The database engine kind: **Postgres**, **MySQL/MariaDB**, or **SQLite**. Every
Connection has one Engine.

### Driver
The adapter that speaks one Engine's protocol behind a single uniform interface,
so the rest of the app never branches on Engine directly. Its interface is
defined by issue **Driver abstraction — unified interface across the 3
databases** (not this ticket). A Driver declares its **Capabilities**.

### Capabilities
Per-Engine feature flags the model branches on instead of hard-coding Engine
checks. Finalized set (see `docs/design/driver-abstraction.md`): `hasServer`,
`hasSchemas` (drive the hierarchy), `supportsTls`, `supportsQueryCancel`
(Postgres only), `supportsSavepoints`, `supportsNestedTransactions` (none of the
three at API level), `paramStyle`. Consumers read flags — never `switch(engine)`.

### ResultCursor
A **pull-based** reader over a row-returning result: its `ResultField`s plus
`fetch(n)` (pull the next batch of `ResultRow`s), `hasMore`, and `close()`.
Holds its Worksheet's **Session** open until closed. One open ResultCursor per
open result view; the grid pulls batches on scroll.

### ExecutionResult
The tagged outcome of one `execute(sql, params)` on a Session — either a
**RowsResult** (carries a `ResultCursor`, for SELECT-like statements) or a
**CommandResult** (carries `affectedRows` + optional `lastInsertId`, for
DML/DDL). The caller switches on the tag; a manager can't know the kind before
running arbitrary user SQL.

### DriverError
An engine exception **normalized** to a uniform shape so the UI reacts the same
across engines: a `DriverErrorKind` (e.g. `authFailed`, `syntaxError`, `timeout`,
`canceled`, `constraintViolation`, `permissionDenied`, `unsupported`, …), a
human message, the native code (SQLSTATE/errno), and the original cause. Each
Driver maps its native errors into this taxonomy.

## Connection & runtime

### Connection
A **saved, cold** profile for reaching a Server: host, port, user, a *reference*
to stored credentials (never the secret itself — see issue **Credentials & secret
handling**), optional default Database, TLS settings. Targets a **Server** (you
browse all its Databases). For SQLite, a Connection is a file path (no server).
A Connection holds **no runtime state**.

### Session
The **live, hot** runtime you get by opening a Connection: open socket(s),
current Database, transaction state, an outstanding-query cancel handle. One
open Connection = one Session. For Postgres (one physical connection per
Database), the Session manages per-Database physical connections beneath a
single logical Session. Sessions are never persisted.
