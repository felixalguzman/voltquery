# Query execution: client-side statement splitting, autocommit default, per-engine cancel

**Status:** accepted

Running a Worksheet's Query is orchestrated by splitting the buffer into
**Statements client-side** (a dialect-aware splitter) and executing them one at a
time via `Session.execute`, rather than sending the whole buffer to the driver as
one multi-statement call. Two points carry trade-offs worth recording:

1. **Client-side statement splitting.** Re-implementing SQL statement boundaries
   (semicolons in literals, Postgres dollar-quoting, MySQL `DELIMITER`) is work,
   but the alternative — a single multi-statement driver call — breaks across
   engines (the prepared/extended protocols are single-statement) and loses
   per-statement error attribution, results, and progress. The splitter is
   best-effort with a whole-buffer fallback.
2. **Cancellation is per-engine and sometimes destructive.** Only Postgres can
   truly cancel (`cancelActive`). For **MySQL** the app cancels by
   **closing the Session's socket** to abort the running query server-side, then
   reconnecting lazily; **SQLite** is best-effort (no exposed interrupt). The
   cancel affordance is always shown with a tooltip explaining the per-engine
   behavior — a future reader must not "simplify" this to a single uniform
   cancel, because the engines genuinely differ.

Transactions default to **autocommit ON** with a per-Worksheet manual-commit
toggle (Commit/Rollback), matching DBeaver. Full design:
`docs/design/query-execution.md`.

**Consequence to honor:** one in-flight run per Worksheet (single Session); each
Statement Execution writes one HistoryEntry; the ResultSet is never persisted.
