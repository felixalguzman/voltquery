# Research: Dart/Flutter DB driver packages
Resolves #3

_Researched 2026-07-31 from pub.dev package pages and package GitHub repositories (primary sources only)._

---

## 1. `postgres`

**pub.dev:** https://pub.dev/packages/postgres  
**GitHub:** https://github.com/isoos/postgresql-dart

| Fact | Detail | Source |
|------|--------|--------|
| Latest version | 3.5.12 | https://pub.dev/packages/postgres |
| Last updated | 2026-06-11 (latest commit); pub.dev shows "49 days ago" relative to 2026-07-31 | https://github.com/isoos/postgresql-dart/commits |
| Pub points | 160 | https://pub.dev/packages/postgres |
| Likes | 414 | https://pub.dev/packages/postgres |
| Downloads | 355k total | https://pub.dev/packages/postgres |
| Publisher | agilord.com (verified) | https://pub.dev/packages/postgres |
| Pure Dart vs native | **Pure Dart** — implements the PostgreSQL wire protocol directly over TCP sockets; no FFI | https://pub.dev/packages/postgres (description: "uses the more efficient and secure extended query format of the PostgreSQL protocol") |
| Native lib wrapped | None | — |
| Connection & auth | `Endpoint(host, port, database, username, password)` passed to `Connection.open()` or `Pool.withUrl()`; connection string URL format `postgresql://user:pass@host:port/db?sslmode=require`; multi-host via comma-separated hosts | https://raw.githubusercontent.com/isoos/postgresql-dart/master/README.md |
| SSL/TLS | Supported: `sslMode` enum values `disable`, `require`, `verify-ca`, `verify-full`; `sslcert`, `sslkey`, `sslrootcert` params; SSL handshake negotiated at connect time | https://raw.githubusercontent.com/isoos/postgresql-dart/master/README.md |
| Prepared statements | Yes — via `connection.prepare(Sql(...))` returning a `Statement`; named params with `Sql.named()` and `@paramname` syntax; statement reuse is a documented core feature | https://pub.dev/packages/postgres |
| Streaming results | Yes — `Statement.bind(params)` returns a `ResultStream` (a `Stream<ResultRow>`); rows are streamed as they arrive from the network via `_PgResultStreamSubscription`; `execute()` internally buffers for convenience | https://github.com/isoos/postgresql-dart/blob/master/lib/src/v3/connection.dart (class `_BoundStatement extends Stream<ResultRow>`, class `_PgResultStreamSubscription`) |
| Query cancellation | Yes — `cancelPendingStatement()` sends a PostgreSQL `CancelRequest` message on a new connection; also triggered automatically on timeout via an internal `Timer` | https://github.com/isoos/postgresql-dart/blob/master/lib/src/v3/connection.dart (line 686 `cancelPendingStatement`, line 1048 `cancelTimer`) |
| Transactions | Yes — `connection.runTx((s) async { ... })` issues `BEGIN`/`COMMIT`/`ROLLBACK`; `ROLLBACK TO SAVEPOINT` is used internally for error recovery within a transaction; no first-class savepoint API exposed, but raw SQL `SAVEPOINT` statements work; nested `runTx` is **not** supported — the API throws if `runTx` is called while already inside a transaction | https://github.com/isoos/postgresql-dart/blob/master/lib/src/v3/connection.dart (line 569 `runTx`, line 537 `ROLLBACK TO SAVEPOINT` comment, line 126 nested-tx error) |

---

## 2. `mysql_client`

**pub.dev:** https://pub.dev/packages/mysql_client  
**GitHub:** https://github.com/zim32/mysql.dart

| Fact | Detail | Source |
|------|--------|--------|
| Latest version | 0.0.27 | https://pub.dev/packages/mysql_client |
| Last updated | 2022-12-26 (last commit) | https://github.com/zim32/mysql.dart/commits |
| Pub points | 150 | https://pub.dev/packages/mysql_client |
| Likes | 186 | https://pub.dev/packages/mysql_client |
| Downloads | 19k total | https://pub.dev/packages/mysql_client |
| Publisher | Unverified uploader | https://pub.dev/packages/mysql_client |
| Pure Dart vs native | **Pure Dart** — described as "native MySQL client written in Dart"; implements MySQL wire protocol over TCP sockets | https://pub.dev/packages/mysql_client |
| Native lib wrapped | None | — |
| Connection & auth | `MySQLConnection.createConnection(host, port, userName, password, databaseName)` + `await conn.connect()`; or `MySQLConnectionPool(...)` for pooling | https://raw.githubusercontent.com/zim32/mysql.dart/master/README.md |
| SSL/TLS | Yes — `secure: true` is the **default**; pass `secure: false` to disable. Wraps `dart:io` `SecureSocket` | https://raw.githubusercontent.com/zim32/mysql.dart/master/README.md ("By default connection is secure") |
| Prepared statements | Yes — real binary-protocol prepared statements: `conn.prepare(sql)` → `stmt.execute([params])`; explicit `stmt.deallocate()` required | https://raw.githubusercontent.com/zim32/mysql.dart/master/README.md |
| Streaming results | Yes — pass `iterable: true` to get rows via `result.rowsStream.listen(...)`; without it, all rows are buffered | https://raw.githubusercontent.com/zim32/mysql.dart/master/README.md |
| Query cancellation | Not documented; no cancellation API found in source | https://github.com/zim32/mysql.dart/blob/master/lib/src/mysql_client/connection.dart |
| Transactions | Yes — `conn.transactional((conn) async { ... })` issues `START TRANSACTION`/`COMMIT`/`ROLLBACK`; throws `MySQLClientException` if called while already in a transaction (no nesting); no savepoint API | https://github.com/zim32/mysql.dart/blob/master/lib/src/mysql_client/connection.dart (line 640–663) |

---

## 3. `mysql1`

**pub.dev:** https://pub.dev/packages/mysql1  
**GitHub:** https://github.com/adamlofts/mysql1_dart

| Fact | Detail | Source |
|------|--------|--------|
| Latest version | 0.20.0 | https://pub.dev/packages/mysql1 |
| Last updated | 2022-08-16 (last commit); pub.dev shows "4 years ago" | https://github.com/adamlofts/mysql1_dart/commits |
| Pub points | 140 | https://pub.dev/packages/mysql1 |
| Likes | 493 | https://pub.dev/packages/mysql1 |
| Downloads | ~9k weekly per pub.dev | https://pub.dev/packages/mysql1 |
| Publisher | Unverified uploader | https://pub.dev/packages/mysql1 |
| Pure Dart vs native | **Pure Dart** — opens a `dart:io` `Socket`; does not work on Flutter Web due to no socket support | https://pub.dev/packages/mysql1 |
| Native lib wrapped | None | — |
| Connection & auth | `ConnectionSettings(host, port, user, password, db, useSSL, timeout)` passed to `MySqlConnection.connect(settings)` | https://github.com/adamlofts/mysql1_dart/blob/master/lib/src/single_connection.dart |
| SSL/TLS | Declared as `useSSL: bool` in `ConnectionSettings`, but **not implemented** — source contains `assert(!c.useSSL); // Not implemented` at connect time | https://github.com/adamlofts/mysql1_dart/blob/master/lib/src/single_connection.dart (line 131) |
| Prepared statements | Yes — `PreparedStatement` class via internal `prepare_handler.dart`; `queryMulti()` for batch execution with multiple parameter sets | https://pub.dev/packages/mysql1 (example showing `?` placeholders); https://github.com/adamlofts/mysql1_dart/tree/master/lib/src/prepared_statements |
| Streaming results | Not exposed — `query()` returns a `Results` object; no streaming row API found in README or source | https://pub.dev/packages/mysql1 |
| Query cancellation | Not documented or implemented | https://github.com/adamlofts/mysql1_dart |
| Transactions | Yes — `conn.transaction((ctx) async { ... })` issues `start transaction`/`commit`/`rollback`; `ctx.rollback()` available to abort explicitly; no savepoints, no nesting | https://github.com/adamlofts/mysql1_dart/blob/master/lib/src/single_connection.dart (method `transaction`) |

---

## 4. `sqlite3`

**pub.dev:** https://pub.dev/packages/sqlite3  
**GitHub:** https://github.com/simolus3/sqlite3.dart

| Fact | Detail | Source |
|------|--------|--------|
| Latest version | 3.5.0 | https://pub.dev/packages/sqlite3 |
| Last updated | 2026-07-19 (pub.dev: "12 days ago") | https://pub.dev/packages/sqlite3 |
| Pub points | 150 | https://pub.dev/packages/sqlite3 |
| Likes | 457 | https://pub.dev/packages/sqlite3 |
| Publisher | simonbinder.eu (verified) | https://pub.dev/packages/sqlite3 |
| Pure Dart vs native | **FFI** on native platforms (dart:ffi bindings to the system or bundled `libsqlite3`); **WebAssembly** on web (SQLite compiled to Wasm) | https://pub.dev/packages/sqlite3 ("lightweight yet convenient bindings to SQLite by using dart:ffi") |
| Native lib wrapped | `libsqlite3` (SQLite). Optional substitution with SQLCipher or SQLite3MultipleCiphers for encryption | https://pub.dev/packages/sqlite3 |
| Connection & auth | `sqlite3.open('path/to/db.sqlite')` on native; on web, `WasmSqlite3.loadFromUrlString(url)` then `open()` with a virtual filesystem | https://raw.githubusercontent.com/simolus3/sqlite3.dart/main/sqlite3/README.md |
| SSL/TLS | Not applicable — SQLite is an embedded file-format database, not a network server | — |
| Prepared statements | Yes — `db.prepare(sql)` returns a `CommonPreparedStatement`; reusable with `selectWith` / `executeWith` | https://github.com/simolus3/sqlite3.dart/blob/main/sqlite3/lib/src/statement.dart |
| Streaming results | Yes (row-by-row iterator) — `stmt.iterateWith(params)` / `stmt.selectCursor()` returns an `IteratingCursor`; call `cursor.step()` to advance row-by-row without buffering all rows | https://github.com/simolus3/sqlite3.dart/blob/main/sqlite3/lib/src/statement.dart (line 74–90, `iterateWith`, `selectCursor`) |
| Query cancellation | Not exposed — no cancellation API found; SQLite's `sqlite3_interrupt` is not surfaced in the public Dart API | https://github.com/simolus3/sqlite3.dart/blob/main/sqlite3/lib/src/database.dart |
| Transactions | Yes — via raw SQL (`execute('BEGIN')` / `COMMIT` / `ROLLBACK`); `SAVEPOINT` SQL works directly; `autocommit` property available to inspect state; the library does not wrap transactions in a Dart API, but raw SQL `SAVEPOINT`/`RELEASE`/`ROLLBACK TO` all work | https://github.com/simolus3/sqlite3.dart/blob/main/sqlite3/lib/src/database.dart (line 288 `autocommit`) |

---

## 5. `sqflite_common_ffi`

**pub.dev:** https://pub.dev/packages/sqflite_common_ffi  
**GitHub:** https://github.com/tekartik/sqflite/tree/master/sqflite_common_ffi

| Fact | Detail | Source |
|------|--------|--------|
| Latest version | 2.4.2 | https://pub.dev/packages/sqflite_common_ffi |
| Last updated | 2026-07-22 (last commit) | https://github.com/tekartik/sqflite/commits |
| Pub points | 160 | https://pub.dev/packages/sqflite_common_ffi |
| Likes | 318 | https://pub.dev/packages/sqflite_common_ffi |
| Publisher | tekartik.com (verified) | https://pub.dev/packages/sqflite_common_ffi |
| Pure Dart vs native | **FFI** — built on top of `package:sqlite3` (which uses dart:ffi); database calls are dispatched through an isolate | https://pub.dev/packages/sqflite_common_ffi ("sqflite ffi based implementation"); https://github.com/tekartik/sqflite/blob/master/sqflite_common_ffi/lib/src/sqflite_ffi_impl.dart |
| Native lib wrapped | `libsqlite3` (via `package:sqlite3`) | https://pub.dev/packages/sqflite_common_ffi |
| Connection & auth | `sqfliteDatabase = await databaseFactory.openDatabase(path)` or `inMemoryDatabasePath` for in-memory; API mirrors `sqflite` package | https://pub.dev/packages/sqflite_common_ffi |
| SSL/TLS | Not applicable | — |
| Prepared statements | Not exposed in the sqflite API surface; queries go through `execute()` / `insert()` / `query()` helpers; internally `sqlite3` prepared statements are used | https://github.com/tekartik/sqflite/blob/master/sqflite_common_ffi/lib/src/sqflite_ffi_impl.dart |
| Streaming results | Not exposed — `query()` returns `List<Map<String, Object?>>` (full buffer); internally uses `sqlite3` cursor steps, but the sqflite API does not stream rows to callers | https://github.com/tekartik/sqflite/blob/master/sqflite_common_ffi/lib/src/sqflite_ffi_impl.dart (class `_SqfliteFfiCursorInfo` used internally) |
| Query cancellation | Not documented or exposed | https://github.com/tekartik/sqflite/blob/master/sqflite_common_ffi/lib/src/sqflite_ffi_impl.dart |
| Transactions | Yes — `db.transaction((txn) async { ... })` mirrors sqflite's `transaction` API; operations outside a transaction are queued until it completes; no savepoint or nested transaction API | https://github.com/tekartik/sqflite/blob/master/sqflite_common_ffi/lib/src/sqflite_ffi_impl.dart (line 267–305) |

---

## 6. `drift`

**pub.dev:** https://pub.dev/packages/drift  
**GitHub:** https://github.com/simolus3/drift

| Fact | Detail | Source |
|------|--------|--------|
| Latest version | 2.34.3 | https://pub.dev/packages/drift |
| Last updated | 2026-07-30 (last commit) | https://github.com/simolus3/drift/commits |
| Pub points | 160 | https://pub.dev/packages/drift |
| Likes | 2,440 (Flutter Favorite) | https://pub.dev/packages/drift |
| Downloads | 1.07M total | https://pub.dev/packages/drift |
| Publisher | simonbinder.eu (verified) | https://pub.dev/packages/drift |
| Pure Dart vs native | **FFI** via `package:sqlite3` on native/desktop; also supports WebAssembly (`WasmDatabase`) and sqflite on mobile | https://drift.simonbinder.eu/docs/getting-started/ |
| Native lib wrapped | `libsqlite3` (via `package:sqlite3`) | https://drift.simonbinder.eu/docs/getting-started/ |
| Connection & auth | `NativeDatabase.createInBackground(file)` wrapped in `LazyDatabase`; or `driftDatabase()` helper for Flutter; connection is to a local SQLite file or in-memory database | https://drift.simonbinder.eu/docs/getting-started/ |
| SSL/TLS | Not applicable | — |
| Prepared statements | Yes — all drift-generated queries are compiled to prepared statements internally; the code-generated layer manages statement lifecycle transparently | https://pub.dev/packages/drift |
| Streaming results | **Reactive streams** — `select(...).watch()` returns `Stream<List<T>>` that re-emits whenever relevant tables change; results are **full-buffer** per emission (complete `List<T>`) not row-by-row. Complex queries including multi-table joins are also reactive | https://drift.simonbinder.eu/dart_api/streams/ |
| Query cancellation | Not exposed — no query cancellation API found; drift relies on SQLite's synchronous execution model | https://github.com/simolus3/drift/blob/develop/drift/lib/src/runtime/api/connection_user.dart |
| Transactions | Yes — `db.transaction(() async { ... })`; nested transactions supported since drift 2.0 on `NativeDatabase`, `WasmDatabase`, `WebDatabase`, `SqfliteQueryExecutor`; nested tx uses real SQLite savepoints internally; failed nested tx reverts only the inner scope; `requireNew: true` parameter throws if nested tx is not supported by the backend | https://github.com/simolus3/drift/blob/develop/drift/lib/src/runtime/api/connection_user.dart (line 460–530); https://drift.simonbinder.eu/docs/transactions/ |

---

## Recommendations

| Database | Recommended driver | Reason |
|----------|--------------------|--------|
| PostgreSQL | **`postgres`** (v3.5.12, agilord.com) | Actively maintained, pure Dart, verified publisher, SSL with cert verification, real streaming `ResultStream`, query cancellation via `CancelRequest`, pooling built-in |
| MySQL / MariaDB | **`mysql_client`** (v0.0.27, zim32) | Pure Dart, SSL on by default, real binary prepared statements, streaming row iterator, actively maintained relative to `mysql1` (which has SSL not implemented and is unmaintained since 2022) |
| SQLite | **`drift`** (v2.34.3, simonbinder.eu) | Flutter Favorite, verified publisher, type-safe ORM, reactive streams, nested transactions, 1M+ downloads, cross-platform including web via Wasm; raw `sqlite3` is better if you need row-by-row cursor stepping without the ORM layer |

---

## Cross-DB capability gaps

Features that are **not uniformly available** across the three recommended drivers (`postgres`, `mysql_client`, `drift`):

| Feature | `postgres` | `mysql_client` | `drift` |
|---------|-----------|---------------|---------|
| **Query cancellation** | YES — `cancelPendingStatement()` sends a PostgreSQL CancelRequest | NO — no cancellation API | NO — no cancellation API |
| **Row-by-row cursor streaming** | YES — `ResultStream` is a true `Stream<ResultRow>` | YES — `rowsStream` when `iterable: true` | NO — reactive streams re-emit full `List<T>` per update, not individual rows |
| **Savepoints (named)** | Partially — `ROLLBACK TO SAVEPOINT` used internally for recovery; no first-class Dart API; raw SQL works | NO | NO direct API, but SQLite `SAVEPOINT` SQL works via `customStatement` |
| **Nested transactions** | NO — `runTx` throws if already inside a transaction | NO — `transactional` throws `MySQLClientException` if already in a transaction | YES — supported since drift 2.0 on all major backends |
| **Connection pooling** | YES — `Pool` class built-in | YES — `MySQLConnectionPool` built-in | NO — single connection per `Database` instance; isolate-based concurrency instead |
| **SSL/TLS** | YES — `sslMode` with `require`/`verify-ca`/`verify-full` | YES — secure by default | N/A (embedded local file DB) |
| **No native dependency** | YES — pure Dart | YES — pure Dart | NO — requires `libsqlite3` (FFI) or Wasm runtime |
