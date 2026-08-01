# Feature-gap survey — what other SQL clients have that VoltQuery doesn't

**Researched:** 2026-08-01 (post-#53). **Status:** backlog input, nothing committed to.
**Companion:** [`differentiators.md`](differentiators.md) covers *offense* (what could make
VoltQuery better than the incumbents); this file covers *parity* (what users will
notice is missing).

Surveyed: DBeaver, JetBrains DataGrip, TablePlus, Beekeeper Studio, Postico,
Sequel Ace, pgAdmin, Azure Data Studio, Navicat, HeidiSQL, MySQL Workbench,
DbVisualizer, Arctype, Outerbase.

Complexity ratings are for *this* codebase (Flutter desktop, driver port per
ADR-0003) — not generic estimates.

---

## Priority summary

| Priority | Feature | Complexity |
|----------|---------|------------|
| **P0** | SSH tunnel | Medium |
| **P0** | SSL/TLS connections | Medium |
| **P0** | Inline cell editing + row add/delete | Medium |
| **P0** | Data export (CSV/JSON/SQL) | Low–Medium |
| **P1** | Table structure GUI editor | High |
| **P1** | CSV/JSON import | Medium |
| **P1** | Connection color-coding (prod/dev) | Low |
| **P1** | Saved query library | Low |
| **P1** | SQL formatter (configurable) | Low–Medium |
| **P1** | Connection folders / groups | Low |
| **P2** | EXPLAIN plan visualization | High |
| **P2** | Schema-aware autocomplete | High |
| **P2** | Schema comparison + migration script | High |
| **P2** | ER diagram auto-generation | High |
| **P2** | Stored procedure / view editor | Medium |
| **P2** | Aggregate/Calc panel for grid selection | Low |
| **P2** | Generated DML ("Copy as SQL") | Low |
| **P2** | FK navigation in grid | Medium |
| **P2** | Live templates / snippets | Low–Medium |
| **P2** | Parameterized queries | Low–Medium |
| **P3** | AI query assistant (BYOK) | Medium |
| **P3** | Charts from results | Medium |
| **P3** | Grid transpose | Low |
| **P3** | Privacy mode (mask data) | Low |
| **P3** | Staged-changes "Code Review" panel | Medium |
| **P3** | Object search palette (Ctrl+P) | Low–Medium |
| **P3** | BLOB / image viewer | Medium |
| **P3** | Column comments as editor tooltips | Medium |
| **P4** | Stored procedure debugger | Very High |
| **P4** | User/role management GUI | High |
| **P4** | Kerberos / AD / LDAP auth | High |
| **P4** | Server monitoring dashboard | High |
| **P4** | Task scheduler | Medium |
| **P4** | Mock data generator | High |
| **P4** | DB-to-DB transfer wizard | High |
| **P4** | Schema diff + data sync | High |

---

## 1. Table-stakes gaps

Present in virtually every competitor; users notice these missing on day one.

### 1.1 Inline cell editing in the data grid — *Medium*
Click a cell, edit in place, stage changes, commit or discard as a batch — no
hand-written DML. **Everyone** has it (TablePlus is praised for the nicest
implementation). pluto_grid already exposes editing callbacks; the real work is
the change buffer, generating correct UPDATE/INSERT/DELETE per engine, and a
Commit/Discard toolbar. *The single most common non-query data task.*

### 1.2 Table structure / DDL editor GUI — *High*
Form-based create/alter table: columns, types, defaults, PK/FK/UNIQUE/CHECK,
indexes — tool emits the DDL. Beekeeper ("visual table creator"), DBeaver,
DataGrip, HeidiSQL, Workbench, Navicat, pgAdmin. Needs per-engine ALTER
generation and current-vs-desired diffing (rename vs drop-add).

### 1.3 SSH tunnel — *Medium*
Local port forward with password or key-file auth, optional keep-alive; DBeaver
also does multi-hop jump hosts. **Universal.** `dartssh2` exists. *Arguably the
largest single gap — most production DBs sit behind a bastion.*

### 1.4 SSL/TLS connections — *Medium*
Configurable CA cert, client cert/key for mTLS. Currently `TODO(tls)` in our
drivers. *Blocks RDS, Cloud SQL, Supabase, PlanetScale, Neon, Heroku.*

### 1.5 Data export (CSV / JSON / SQL inserts) — *Low–Medium*
Configurable delimiter, headers, encoding. DBeaver adds XML/XLSX/Parquet;
DataGrip adds TSV/Markdown/Excel.

### 1.6 Data import (CSV → table) — *Medium*
Into an existing table or auto-created one, with a column-mapping UI. DBeaver's
transfer wizard, Beekeeper's "create tables from CSV".

### 1.7 Connection color-coding / environment tagging — *Low*
Red = production, green = dev, shown in tree + tab chrome. SSMS, DataGrip,
TablePlus, DBeaver, Navicat, Beekeeper. *Cheap; prevents career-limiting
accidents.*

### 1.8 Saved / pinned query library — *Low*
Curated, foldered, named queries — distinct from our recency-based history.
DataGrip, DBeaver bookmarks, Beekeeper (v5.7 folders), Navicat.

---

## 2. Power-user features (what makes DataGrip/DBeaver sticky)

### 2.1 Schema-aware autocomplete — *High*
Resolves aliases, understands JOIN columns, completes inside CTEs/subqueries,
expands `SELECT *`. DataGrip is best-in-class (indexes the schema on connect,
ML-ranked); DBeaver/Beekeeper/TablePlus only do keyword + object names. Needs a
real SQL parser + schema graph, ideally in a background isolate. *The #1 feature
DataGrip users cite.*

### 2.2 SQL code inspections — *High*
Pre-execution squiggles for unresolved names, type mismatches, deprecated syntax,
with quick-fixes. Essentially DataGrip-only. Shares the parser with 2.1.

### 2.3 EXPLAIN / query-plan visualization — *High*
Interactive tree or flame graph with per-node cost/rows/time, expensive nodes
highlighted. DataGrip (tree + flame graph), DBeaver (Pro), pgAdmin, Workbench.
Per-engine plan parsing (PG JSON is the easy one).

### 2.4 Object-level / metadata search — *Medium*
"Find in database" across tables, columns, views, routines — optionally across
data. DataGrip (Ctrl+Alt+Shift+F), DBeaver full-text search. Mostly
`information_schema`/`pg_catalog` queries + a results navigator.

### 2.5 Rename refactoring across scope — *High*
Rename a table/column and propagate through open SQL files, procedures, views,
FKs, with preview. DataGrip-grade; DBeaver limited.

### 2.6 Schema comparison + migration script — *High*
Diff two schemas (or schema vs DDL file), generate the ALTER script. DataGrip
"Compare Structure With", DBeaver Pro, pgAdmin Schema Diff, Navicat, HeidiSQL.
*Core for managing dev/staging/prod drift.*

### 2.7 Git / VCS integration for scripts — *Medium*
Commit, branch, diff, blame SQL files in-tool. DataGrip native; DBeaver project
scripts.

### 2.8 Task scheduler / automation — *Medium*
Recurring exports/imports/scripts via OS cron or Task Scheduler, with
notification. DBeaver Task Manager, Navicat batch jobs.

### 2.9 Server / session monitoring — *High*
Active connections, running queries, locks, resource usage; kill session / cancel
query. DBeaver, pgAdmin dashboard, Workbench Performance Schema, Navicat.

---

## 3. Data editing & manipulation

- **3.1 Row add / delete / clone in grid** — *Medium.* Same change buffer as 1.1.
  Universal (DataGrip: Alt+Insert / Ctrl+Y / Clone Row).
- **3.2 FK navigation in grid** — *Medium.* Click an FK value → jump to the parent
  row; also navigate children from a PK. DataGrip "Related Rows" (F4), DBeaver.
  *Explore relationships without writing JOINs.* We already introspect FKs.
- **3.3 BLOB / binary viewer** — *Medium.* Image preview, hex dump, CLOB text,
  load/save file. DBeaver, DataGrip, pgAdmin, HeidiSQL.
- **3.4 Generated DML / "Copy as SQL"** — *Low.* Right-click rows → INSERT/UPDATE/
  DELETE to clipboard. DBeaver Advanced Copy, DataGrip, TablePlus, HeidiSQL.
  *Cheapest win here; reuses the export pipeline.*
- **3.5 Aggregate / calc panel** — *Low.* Select numeric cells → SUM/COUNT/AVG/
  MIN/MAX/median in a status bar. DBeaver Calc Panel, DataGrip Aggregate View.
  *Excel-grade expectation.*
- **3.6 Charts from query results** — *Medium.* Bar/line/pie without leaving the
  tool. DBeaver (Lite+), DataGrip, TablePlus (2026), Arctype. `fl_chart` fits.
- **3.7 Grid transpose** — *Low.* Rows↔columns for wide tables. DataGrip
  Transpose, DBeaver Record mode.
- **3.8 Spatial / GeoJSON viewer** — *High.* PostGIS/SpatiaLite geometry on a map.
  DBeaver, DataGrip Geo Viewer. Niche, but a total blocker for GIS users.

---

## 4. Schema & object management

- **4.1 ER diagram (auto-generated)** — *High.* Tables + FK lines, auto-layout,
  zoom, PNG/SVG export. DBeaver (IDEF1X, forward-engineering), DataGrip,
  Workbench EER, pgAdmin, Navicat. Needs a layout engine (Dagre/ELK) + canvas.
  *Cited as a core DBeaver strength.*
- **4.2 Forward engineering from diagram** — *High.* Design visually → emit DDL.
  Workbench is the gold standard; DBeaver ERD edit mode.
- **4.3 Stored procedure / function / trigger / view editor** — *Medium.* Open,
  edit, `CREATE OR REPLACE` on save. Everyone serious has it. *Without it, users
  drop to psql/mysql for routine work.*
- **4.4 Stored procedure debugger** — *Very High.* Breakpoints, watch, step-in.
  DataGrip (PG/Oracle/T-SQL), DBeaver Pro plugin, pgAdmin. Needs `pldbgapi`-style
  engine protocols. *Huge retention lever in PL/pgSQL-heavy shops.*
- **4.5 User / role management UI** — *High.* Create users/roles, assign
  privileges, Grant Wizard. pgAdmin best-in-class; DBeaver has an open gap issue.
  Privilege models differ sharply per engine.
- **4.6 Mock / test data generator** — *High.* Names, addresses, emails, UUIDs,
  regex patterns, row counts. Effectively DBeaver-only.
- **4.7 Table / schema data diff** — *High.* Row-by-row comparison + sync DML.
  DataGrip Diff Viewer, DBeaver Pro, Navicat Data Sync, HeidiSQL.

---

## 5. Productivity / editor intelligence

- **5.1 SQL formatter, configurable** — *Low–Medium.* Keyword case, indentation,
  comma position, JOIN alignment. DataGrip, DBeaver, HeidiSQL, TablePlus.
  *Baseline expectation.*
- **5.2 Live templates / snippets** — *Low–Medium.* `sel`+Tab → `SELECT * FROM |`,
  parameterized, user-defined. DataGrip Live Templates (Ctrl+J), DBeaver, Navicat.
- **5.3 Parameterized queries** — *Low–Medium.* `:name` tokens → input dialog
  before run. DataGrip Parameters, DBeaver, DbVisualizer. *Reusable reports
  without hand-editing literals.*
- **5.4 Multi-cursor / block transform** — *Low.* re_editor may already cover part
  of this; extend where not. Friction point vs VS Code.
- **5.5 Go to definition / find usages** — *High.* Navigate to an object from a
  SQL reference; find references across scripts. DataGrip-grade.
- **5.6 Run configurations** — *Medium.* Named script+connection+schema+pre-run
  profiles, shareable via VCS. DataGrip.
- **5.7 Column comments as editor tooltips** — *Medium.* Surface `COMMENT ON` text
  on hover. DataGrip, DBeaver. *Self-documented schemas are wasted if hidden.*

---

## 6. Nice-to-haves / delighters

- **6.1 Staged-changes "Code Review" panel** — *Medium.* Show the exact DML before
  it hits the server, with Commit/Discard. **TablePlus's signature feature**,
  praised in every review. *Fits our manual-commit model naturally.*
- **6.2 Connection folders / groups** — *Low.* Unusable flat list past ~20
  connections. Beekeeper (v5.7), DBeaver, DataGrip, Navicat, TablePlus.
- **6.3 "Open Anything" palette** — *Low–Medium.* Ctrl+P to any table/view/schema/
  connection/query. TablePlus, DataGrip (Go to Object), DBeaver.
- **6.4 Privacy mode** — *Low.* Mask values in the grid for screen-sharing.
  **Beekeeper-only** (v5.2). Cheap, increasingly requested.
- **6.5 Kerberos / AD / LDAP / OAuth auth** — *High.* DBeaver, Beekeeper (Entra ID),
  pgAdmin (OAuth2/OIDC). *Gate for corporate deployment.*
- **6.6 AI query assistant** — *Medium.* NL→SQL, explain, BYOK. DataGrip AI
  Assistant, DBeaver Pro AI Chat, Beekeeper AI Shell, pgAdmin AI Insights.
  *Fastest-growing category in 2025–26 — see `differentiators.md` for the
  local-first angle, which is the more defensible play.*
- **6.7 Theming / true dark mode** — *Low.* We're dark already; the gap is
  consistency across every surface + optional themes (Dracula/Nord/Solarized).
  Pairs with the open `ui/core/theme` (#7) work.
- **6.9 DB-to-DB transfer wizard** — *High.* Cross-connection, cross-engine copy
  with column mapping and type coercion. DBeaver Data Transfer, Navicat.
- **6.10 Connection keep-alive / auto-reconnect** — *Low–Medium.* Idle ping +
  transparent reconnect. DBeaver and most enterprise clients. *Avoids
  "connection lost" mid-session.*

---

## Reading this against our roadmap

Cross-referencing `docs/BUILD_STATUS.md`, the cheapest high-value cluster is:

1. **Grid write-path** (1.1 + 3.1 + 3.4 + 6.1) — inline editing, row ops, Copy as
   SQL, and a staged-DML review panel. One coherent slice; turns VoltQuery from a
   read-only browser into an actual manager. Our manual-commit/tx work already
   built the safety story this needs.
2. **Connectivity** (1.3 + 1.4 + 6.10) — SSH tunnel, TLS, keep-alive. Without
   these, VoltQuery cannot reach most real production databases. TLS is already
   a known gap (`TODO(tls)`).
3. **Cheap wins** (1.7 + 1.8 + 3.5 + 3.7 + 6.2 + 6.3 + 6.4) — all Low complexity,
   all visible: connection colors and folders, saved queries, calc panel,
   transpose, command palette, privacy mode.
