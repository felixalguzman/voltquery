# Driver abstraction: uniform pull-cursor interface, `sqlite3` for SQLite

**Status:** accepted

The app codes against a single `Driver`/`Session` interface for Postgres, MySQL,
and SQLite and never branches on engine; each engine's differences are hidden in
its driver or surfaced as `Capabilities` flags. Three shape decisions carry
trade-offs worth recording:

1. **SQLite uses raw `sqlite3`, not `drift`** — reversing the driver research's
   default. drift is a Flutter-Favorite ORM built for *compile-time-known*
   schemas with full-buffer reactive streams; VoltQuery runs *arbitrary* user
   SQL against *runtime-introspected* schemas and needs a row cursor. `sqlite3`'s
   `selectCursor()` makes SQLite's result path identical to Postgres/MySQL. A
   future reader will wonder why the "recommended" package was passed over —
   this is why.
2. **Results are delivered via a pull-based `ResultCursor`** (`fetch(n)`), not a
   push `Stream` or app-level `LIMIT/OFFSET` paging — so pluto_grid's lazy
   pagination pulls batches on scroll with natural backpressure and no
   re-execution, at the cost of holding a Session open per result view.
3. **One `execute()` returns a discriminated `ExecutionResult`**
   (`RowsResult | CommandResult`) rather than split `query()`/`execute()`,
   because a manager can't pre-classify arbitrary user SQL as row-returning.

Full interface: `docs/design/driver-abstraction.md`. Enforces ADR-0001 (schema
introspection is the only place `switch(engine)` is allowed, hidden inside
drivers, returning canonical hierarchy objects).

**Consequence to honor:** query cancellation is Postgres-only
(`capabilities.supportsQueryCancel`); the UI must gate its cancel affordance on
the flag, not assume all engines can interrupt a running statement.
