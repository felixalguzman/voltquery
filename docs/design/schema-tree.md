# Schema tree lazy-load model

Design output of issue **Schema tree lazy-load model** (#13). Plan-only. Builds on
the Driver abstraction (`SchemaIntrospector` returning canonical hierarchy
objects; `docs/design/driver-abstraction.md`), the domain model (`CONTEXT.md`:
`Server→Database→Schema→Object`, `Capabilities`), the layering ADR
(`docs/design/architecture.md`, ADR-0004 — with the per-Connection refinement in
§ Introspection session below), and the fluent-shell research (#5: native
`TreeViewItem(lazy:true)` + `onExpandToggle`, `loading:bool`, no native
error/retry). Recorded in **ADR-0008**. Governs the `schema_browser` feature and
`SchemaRepository`.

## Loading posture — lazy everywhere

On connect, only the **connection root** appears; nothing below is introspected
until expanded. Every level loads on the fluent `TreeViewItem`'s async
`onExpandToggle`, which fires one `SchemaIntrospector` call and appends the
children. This is the only posture that survives a Postgres server with dozens of
databases or a schema with thousands of tables — an eager crawl would turn a
connect into a multi-second, hang-prone catalog walk.

## Tree shape

Full hierarchy is navigable in the tree (not split into a detail panel):

```
Connection                         (forest root — see § Scope)
└─ Database            [lazy]       (single/implicit where !hasServer: SQLite)
   └─ Schema           [lazy]       (present only where hasSchemas: Postgres)
      ├─ Tables        [lazy folder]
      │  └─ Table       → ├─ Columns  [lazy group]
      │                   └─ Indexes  [lazy group]
      └─ Views         [lazy folder]
         └─ View        → (Columns / Indexes, same)
```

Optional levels collapse per `Capabilities` (`hasServer`, `hasSchemas`) exactly as
the domain model prescribes — MySQL skips Schema, SQLite skips Server and Schema.

**Tables vs Views** are separate folders. Rather than add a `views()` method to
the port, the introspector's `tables()` result carries a **`kind` flag** on the
canonical object; `SchemaRepository` partitions the one list into the two folders.
Keeps the `SchemaIntrospector` interface lean.

## Introspection session — per-Connection (refines ADR-0004)

The schema tree is a property of the **Connection**, not any Worksheet. It uses a
**dedicated per-Connection introspection `Session`**, distinct from the
per-Worksheet Sessions of ADR-0004:

- Catalog reads never ride a user's open transaction (introspecting inside an
  uncommitted tx risks dirty reads / lock contention / deadlock).
- The tree stays alive with **zero** worksheets open.
- The connect cost is amortized across all expands and refreshes.

The session is **lazy per connection**: established when the connection's root is
first expanded, and it may be torn down when the connection is collapsed or
disconnected. Many roots therefore does **not** mean many live connections — you
pay only for expanded ones.

> **Correction to ADR-0004 wiring:** `SchemaRepository` and its introspection
> Session are keyed by **`ConnectionId`**, not `WorksheetId`. ADR-0004's
> `autoDispose.family<Session, WorksheetId>` stands for *Worksheet* Sessions
> (query execution); it is not the schema tree's session. See ADR-0008.

## Riverpod binding

- **`FutureProvider.family` per parent-ref** — `childrenProvider(parentRef)`
  returns `AsyncValue<List<Node>>`. `onExpandToggle` reads the provider; its
  loading/error/data states map 1:1 onto fluent's `loading:bool` and the inline
  retry node (§ Node UX).
- **`SchemaRepository` is the single cache** (keyed by `ConnectionId`); providers
  are `autoDispose` **views that delegate** to it — no double-caching, no drift
  between two caches.
- **Invalidation = `ref.invalidate(childrenProvider(ref))`**, which also evicts
  the repo entry for that key.

## Cache

- **Shape:** in-memory map, one entry per **parent-ref** —
  `ConnectionId→databases`, `DatabaseRef→schemas`, `SchemaRef+kind→tables|views`,
  `TableRef→columns`, `TableRef→indexes`. Each entry is one introspector result.
- **Lifetime:** connection-lifetime, held inside the `family<_, ConnectionId>`
  `SchemaRepository`; gone when that provider disposes.
- **Not persisted** to `voltquery.db` — a stored catalog goes stale between runs
  (other clients' DDL) and would show phantom objects; re-fetch on reconnect is
  cheap.
- **No TTL** — invalidation is explicit (manual + post-DDL), never time-based. A
  background timer re-fetching the catalog would surprise the user.
- **No expansion-state persistence** — restoring which nodes were open across
  reconnect is deferred to workspace-restore, out of this ticket.

## Refresh & invalidation

- **Manual refresh (per node):** *subtree evict* — evict the node's children entry
  and all descendants, collapse to the node, lazy-refetch on next expand. A
  top-level **"Refresh connection"** evicts the whole connection cache.
- **Post-DDL auto-invalidation:** *coarse* — any detected DDL evicts the whole
  connection cache (lazy re-fetch means the cost is paid only on next expand).
  Targeted subtree-eviction by parsing the statement's target is deliberately
  **not** done: reliable target parsing across three dialects (CTEs, `DO` blocks,
  procedures that DDL internally) is a tar pit, and coarse evict is always correct.
  - Detection reuses the query-execution model's statement classification (**soft
    dependency on #12**). Until that lands, an interim classifier flags a statement
    as DDL when it begins with `CREATE`/`ALTER`/`DROP`/`TRUNCATE`/`COMMENT`/
    `RENAME`.
- **Affordances:** right-click **Refresh** on any node + a toolbar Refresh button
  on the schema panel; **evict-all** on manual reconnect.

## Very large schemas

- **Fetch side:** one full `SchemaIntrospector` call per level — no server-side
  paging on the introspector (catalog rows are tiny; even tens of thousands of
  names are a small single round-trip). The port signature stays paging-free.
- **Render side:** cap rendered siblings at a threshold (**default ~500**) with a
  synthetic **"… N more (show all / filter)"** node, plus a **per-folder filter
  box**. The cap is a safe upper bound whether or not fluent's `TreeView`
  virtualizes its child list (unverified — a build-time detail, not a blocker).
- **Counts:** folder labels show child counts **after** the list is cached
  (`Tables (10,342)`); no separate pre-expand `COUNT(*)` probe.

## Node UX

- **Loading:** native `loading:bool` `ProgressRing` per node during
  `onExpandToggle`. No custom widget.
- **Error** (introspection throws `DriverError`): an **inline, non-selectable
  retry node** — `⚠ <DriverError.message> — Retry`. The node stays expandable;
  Retry is **resilient** — on `connectionFailed`/`timeout` it re-establishes the
  per-Connection introspection session before re-fetching. No global toast (toasts
  are for worksheet-level actions). Broad "connection lost" banners are
  Connection-management (#14) territory.
- **Empty** (loaded, zero children): an inline muted **"(empty)"** child —
  distinguishes "loaded, nothing here" from "not yet expanded."

## Scope & ordering

- **Forest:** every connection is a **root node** in one tree (DBeaver/DataGrip
  model), each with its own lazy per-Connection introspection session.
- **Ordering:** nodes **alphabetical** (case-insensitive) within a level; the
  `Tables`/`Views` and `Columns`/`Indexes` grouping folders in fixed conventional
  order. **Columns are ordered by ordinal** (schema definition order) — position is
  semantically meaningful, not alphabetical.

## Out of this ticket

- **Node interactions** (double-click → open `SELECT`, data preview, generate DDL,
  drag name into editor) — belong to the **query-workspace** feature, not the
  loading model.
- **Global tree search** (schema-wide find vs the per-folder filter above) — a
  genuine future decision; left as fog on the map, not yet a ticket.
