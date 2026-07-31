# Persistence: drift for app-state, strictly secret-free (ref-only)

**Status:** accepted

VoltQuery persists its own state (connections, connection groups, open-worksheet
drafts, query history, settings) in a **single drift/SQLite database**
(`voltquery.db`) in the app-support directory. Two points carry trade-offs worth
recording:

1. **drift is used here even though ADR-0003 rejected it for user databases.**
   The two are different problems: user DBs have *arbitrary runtime* schemas
   (drift can't model those — hence raw `sqlite3` there), while VoltQuery's own
   store has a *fixed compile-time* schema, which is exactly what drift is for
   (typed queries, migrations, reactive `.watch()`). A reader seeing both will
   assume a contradiction; this is why there isn't one.
2. **The persistence DB holds no secrets, ever.** `connections` stores only an
   opaque `credentialRef`; the secret — including Linux's encrypted blob — lives
   entirely in the credentials layer (issue #11). This keeps `voltquery.db`
   non-sensitive (safe to back up/sync, no encryption needed) and isolates all
   crypto in one place, at the cost of a cross-layer purge when a connection is
   deleted.

Full schema, migrations, retention: `docs/design/persistence.md`.

**Consequence to honor:** never write a password/secret into `voltquery.db`
"for convenience" — it would make the whole store sensitive and split secret
handling across two layers. Deleting a Connection must purge its secret via the
credentials layer by `credentialRef`.
