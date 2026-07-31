# Driver abstraction — unified interface

Design output of issue **Driver abstraction — unified interface across the 3
databases** (#8). Plan-only: this is the interface a build pass implements, not
code. Grounded in `docs/research/db-drivers.md` (#3) and `CONTEXT.md`. Enforces
**ADR-0001** (uniform hierarchy — `switch(engine)` lives *inside* drivers only)
and is recorded in **ADR-0003**.

## Principle

The app codes against `Driver` / `Session` and **never** branches on `Engine`.
Every per-engine difference is either hidden inside a driver or surfaced as a
`Capabilities` flag the app reads. The three concrete drivers wrap:

| Engine | Package (decided) | Notes |
|--------|-------------------|-------|
| PostgreSQL | `postgres` v3 | pure Dart, streaming, cancellation, TLS |
| MySQL/MariaDB | `mysql_client` | pure Dart, TLS default, streaming iterator |
| SQLite | **`sqlite3`** (raw, *not* drift) | FFI; `selectCursor()` row-by-row; arbitrary SQL |

> SQLite uses raw `sqlite3`, revising the research's drift recommendation: a SQL
> *manager* runs arbitrary ad-hoc SQL against runtime-introspected schemas and
> needs a row cursor — drift is an ORM for compile-time schemas with full-buffer
> reactive streams. `sqlite3` makes the result path **identical** across all three.

## Interface (sketch)

```dart
abstract interface class Driver {
  Engine get engine;
  Capabilities get capabilities;
  Future<Session> connect(Connection config);   // -> a live Session
}

abstract interface class Session {
  Connection get connection;
  String? get currentDatabase;
  bool get inTransaction;

  // Single entry point — the app can't pre-classify arbitrary user SQL.
  Future<ExecutionResult> execute(String sql, {List<Object?> params = const []});

  // Transaction primitives — minimal. Higher orchestration (autocommit toggle,
  // multi-statement scripts, per-statement vs batch) is the Query execution
  // model ticket, not here.
  Future<void> begin();
  Future<void> commit();
  Future<void> rollback();
  Future<void> useDatabase(String name);         // where the engine allows it

  // Cancellation — only if capabilities.supportsQueryCancel, else throws
  // DriverError(kind: unsupported). App disables the cancel affordance per flag.
  Future<void> cancelActive();

  SchemaIntrospector get schema;                 // driver-provided (see below)
  Future<void> close();
}

sealed class ExecutionResult {}
class RowsResult   extends ExecutionResult { final ResultCursor cursor; }
class CommandResult extends ExecutionResult { final int affectedRows; final Object? lastInsertId; }

abstract interface class ResultCursor {
  List<ResultField> get fields;
  bool get hasMore;
  Future<List<ResultRow>> fetch(int n);          // pull next batch; feeds grid paging
  Future<void> close();                          // frees the Session
}
```

## Schema introspection

The one place `switch(engine)` is allowed. Each driver issues its own catalog
queries and returns **canonical** domain objects — so the schema tree consumes
one shape (ADR-0001).

```dart
abstract interface class SchemaIntrospector {
  Future<List<Database>> databases();
  Future<List<Schema>>   schemas(DatabaseRef db);   // single/empty where !hasSchemas
  Future<List<Table>>    tables(SchemaRef s);       // + views
  Future<List<Column>>   columns(TableRef t);
  Future<List<Index>>    indexes(TableRef t);
}
```

| Engine | Catalog source |
|--------|----------------|
| Postgres | `pg_catalog` / `information_schema` |
| MySQL | `information_schema` |
| SQLite | `sqlite_master` + `PRAGMA table_info/index_list` |

## Capabilities (final flag set)

```dart
class Capabilities {
  final bool hasServer;                 // false: SQLite
  final bool hasSchemas;                // true:  Postgres
  final bool supportsTls;               // Postgres, MySQL
  final bool supportsQueryCancel;       // Postgres ONLY
  final bool supportsSavepoints;        // via SAVEPOINT SQL: all three
  final bool supportsNestedTransactions;// false at API level for all three
  final ParamStyle paramStyle;          // dollar / question / named — driver translates
}
```

Row-cursor streaming is uniformly available (via the chosen packages), so it is
**not** a flag — it's a guarantee of the interface.

## Error normalization

```dart
enum DriverErrorKind {
  connectionFailed, authFailed, tlsError, timeout, canceled,
  syntaxError, permissionDenied, constraintViolation,
  objectNotFound, serverError, unsupported, unknown,
}
class DriverError implements Exception {
  final DriverErrorKind kind;
  final String message;      // normalized, human-facing
  final String? nativeCode;  // SQLSTATE (pg) / errno (mysql) / result code (sqlite)
  final Object? cause;       // original exception
}
```

Mapping per engine: Postgres `ServerException` SQLSTATE → kind; `mysql_client`
error numbers → kind; `sqlite3` result/extended codes → kind.

## Connection lifecycle & pooling

`Driver.connect(Connection)` yields one `Session`. The app opens **one Session
per Worksheet** (per the domain model — transaction isolation). Any pooling a
driver offers internally (`postgres` `Pool`, `mysql_client` pool) is an
implementation detail *below* this interface; the interface is single-Session.
Managing the set of live Sessions is the concern of the **Project layering**
ticket (a SessionManager/registry), not the driver.

## Explicitly out of this ticket (fog / other tickets)

- **How a Worksheet's Query is orchestrated** (per-statement vs whole script,
  autocommit, timeouts, cancel wiring, mapping to Execution/HistoryEntry) →
  *Query execution & cancellation model* ticket.
- **What schema loads when, caching, refresh** → *Schema tree lazy-load* ticket.
- **Grid paging UX** (batch size, prefetch) → *Query editor ↔ result grid wiring*.
