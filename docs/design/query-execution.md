# Query execution & cancellation model

Design output of issue **Query execution & cancellation model** (#12). Plan-only.
Builds on the Driver abstraction (`execute → ExecutionResult`, `ResultCursor`,
`Capabilities`; `docs/design/driver-abstraction.md`) and the domain model
(`CONTEXT.md`: Query/Statement/Execution/HistoryEntry/Worksheet). Recorded in
**ADR-0007**. Orchestration lives in the `query_workspace` feature's view-model
(architecture: `docs/design/architecture.md`).

## Run model

A **dialect-aware `SqlStatementSplitter`** (pure, in `domain`) splits the Query
buffer into ordered **Statement**s — handling `;` inside string/identifier
literals, line/block comments, Postgres dollar-quoting (`$tag$…$tag$`), and MySQL
`DELIMITER`. Splitting is best-effort; unparseable edge cases fall back to
whole-buffer as one Statement.

| Action | Runs |
|--------|------|
| **Run** (default) | the whole script — every Statement, in order |
| **Run at cursor** | just the Statement under the caret |
| **Run selection** | just the highlighted SQL |

Each Statement is executed **individually** via `session.execute(sql, params)` —
giving per-statement result, error attribution, and progress. **Stop-on-error by
default** (a setting flips to continue-on-error).

Only **one run is in flight per Worksheet** (it has one Session); while running,
Run is replaced by Cancel. Different Worksheets run concurrently (own Sessions).

## Execution lifecycle

Each Statement run is one **Execution** with state:

```
pending → running → (succeeded | failed | canceled)
```

Fields: `startedAt`, `durationMs`, `status`, and from the `ExecutionResult`:
- `RowsResult` → drives the Statement's `ResultCursor` into the grid; `rowCount`
  is **unknown until fully fetched** (lazy cursor) — reported as rows-fetched-so-far.
- `CommandResult` → `affectedRows` (+ `lastInsertId`) shown in the messages log.

## Results model

A script can yield several row-returning Statements. Each produces a **Result**,
shown as a **result sub-tab** within the Worksheet; non-row Statements and
errors post to an **execution messages/log** panel (status, affected rows,
duration, errors). Detailed grid rendering + paging is the *Query editor ↔ result
grid wiring* ticket; this model just defines "one Result per row-returning
Statement + a messages log".

## Transactions

**Autocommit ON by default** — each Statement commits immediately. A
per-Worksheet **manual-commit toggle** switches to: app issues `begin()` on first
Statement, exposes **Commit** / **Rollback**, with optional **auto-rollback on
error**. Driver nested-tx is unsupported (Capabilities); a user's own `BEGIN` in
autocommit mode passes through and is tracked via `Session.inTransaction`.

## Cancellation (per-engine strength)

Cancel is always offered; strength varies by `Capabilities.supportsQueryCancel`,
tooltip states what it does:

| Engine | Cancel |
|--------|--------|
| Postgres | true cancel — `Session.cancelActive()` (CancelRequest) |
| MySQL | **abandon-and-close** the Session — closing the socket aborts the running query server-side; the Worksheet reconnects lazily (its `autoDispose.family` session) |
| SQLite | best-effort/none — interrupt isn't exposed and queries are local; "stop waiting" only |

A canceled run sets `Execution.status = canceled`.

## Timeouts

Optional per-statement timeout (a setting, default off). On expiry the app
triggers the **same path as Cancel** for the engine (Postgres internal timer +
cancel; MySQL abandon-and-close; SQLite best-effort).

## History mapping

Every Statement Execution writes **one `HistoryEntry`** on completion (success /
failure / cancel): Statement SQL, connectionId (+ denormalized name/engine),
database, startedAt, durationMs, status, rowCount (nullable), errorKind +
message. A multi-statement script produces N HistoryEntries. The ResultSet is
**not** stored (domain model).

## Threading

Driver adapters keep DB I/O off the UI isolate. `sqlite3` is synchronous FFI, so
its adapter runs on a **background isolate** (this is also why SQLite cancel is
best-effort — no cross-isolate interrupt handle is exposed).

## Graduates from fog (now sharp)

- **Query editor ↔ result grid wiring & result pagination** — filed.
- **Feedback & async-state UX** — filed.
