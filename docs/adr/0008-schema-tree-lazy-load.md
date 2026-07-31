# Schema tree: lazy-everywhere over a dedicated per-Connection introspection Session

**Status:** accepted

The schema browser populates the fluent `TreeView` **lazily at every level** —
on connect only the connection root shows; each deeper level
(`Database→Schema→{Tables,Views}→object→{Columns,Indexes}`) is introspected on the
node's async `onExpandToggle`. Eager population is rejected: a Postgres server with
many databases or a schema with thousands of tables would make connect a slow,
hang-prone catalog crawl. Full design: `docs/design/schema-tree.md`.

Three points carry trade-offs worth recording:

1. **The introspection Session is per-Connection, not per-Worksheet — a
   refinement of ADR-0004.** The tree belongs to the Connection, not any tab, so it
   uses a **dedicated per-Connection `Session`**, established lazily on first
   root-expand. This keeps catalog reads off users' open transactions (introspecting
   inside an uncommitted tx risks dirty reads, lock contention, deadlock), keeps the
   tree alive with zero worksheets open, and amortizes connect cost. ADR-0004's
   `autoDispose.family<Session, WorksheetId>` remains correct **for Worksheet
   (query) Sessions**; it was never the schema tree's session. `SchemaRepository`
   and its Session are keyed by **`ConnectionId`**. A future reader must not collapse
   the two Session kinds into one per-Worksheet family.

2. **Invalidation is coarse, not targeted.** Any detected DDL evicts the whole
   connection cache rather than parsing the statement's target subtree. Reliable
   target parsing across three dialects (CTEs, `DO` blocks, procedures that DDL
   internally) is a tar pit; coarse evict is always correct and, because re-fetch is
   lazy, costs nothing until the next expand. DDL detection reuses #12's statement
   classification (soft dep), with an interim keyword classifier
   (`CREATE`/`ALTER`/`DROP`/`TRUNCATE`/`COMMENT`/`RENAME`). Do not "optimize" this
   into per-statement subtree invalidation.

3. **The catalog cache is in-memory and never persisted.** Per-parent-ref,
   connection-lifetime, no drift persistence, no TTL. A stored catalog goes stale
   between runs (other clients' DDL) and would render phantom objects; re-fetch on
   reconnect is cheap. Explicit invalidation only — no background timer.

Large folders are handled at the **render** layer (cap ~500 siblings + "show more"
+ per-folder filter), leaving the `SchemaIntrospector` port paging-free; the tree
is a **forest** of connection roots, alphabetical within a level, columns by
ordinal.

**Consequence to honor:** node interactions (open `SELECT`, preview, DDL gen) and
global tree search are **out** of this model — the first belongs to query-workspace,
the second is deferred (map fog). This ADR governs *how the tree loads, caches,
refreshes, and scales* only.
