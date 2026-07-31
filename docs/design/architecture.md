# Project layering & architecture

Design output of issue **Project layering & folder architecture** (#9). Plan-only.
Follows the `flutter-apply-architecture-best-practices` skill (layered
UI/data/domain + Repository + MVVM), **adapted to Riverpod** (the standing state
choice) in place of the skill's `ChangeNotifier` + provider/get_it. Recorded in
**ADR-0004**. Domain vocabulary: `CONTEXT.md`. Driver interface:
`docs/design/driver-abstraction.md`.

## Layers

| Layer | Holds | Rule |
|-------|-------|------|
| **domain** | Immutable models (`Connection`, `Server`…`Column`, `Query`/`Statement`/`Execution`/`HistoryEntry`, `ResultSet`/`ResultField`/`ResultRow`, `Capabilities`, `Worksheet`) and the **driver ports** (`Driver`, `Session`, `ResultCursor`, `ExecutionResult`, `SchemaIntrospector`, `DriverError`). | No Flutter, no I/O. Pure Dart. |
| **data** | **Driver adapters** (postgres/mysql/sqlite implementing the ports), **services** (secure storage, local persistence), **repositories** (single source of truth, return domain models). | No widgets. Depends on domain. |
| **ui** | `core/` (theme, shell, shared widgets) + `features/*` (each: `view_models/` = Riverpod Notifiers, `views/` = `ConsumerWidget`s). | No direct driver/service calls — go through repositories via providers. |
| **domain/use_cases** *(optional)* | Cross-repository logic (e.g. *open connection* = resolve credential + `Driver.connect` + register session). | Add only when logic spans repositories or clutters a ViewModel. |

## Folder structure

```text
lib/
├── domain/
│   ├── models/            # freezed immutable domain entities (CONTEXT.md terms)
│   └── drivers/           # Driver, Session, ResultCursor, ExecutionResult,
│                          #   SchemaIntrospector, DriverError, Capabilities  (PORTS)
├── data/
│   ├── drivers/
│   │   ├── postgres/      # PostgresDriver/Session/Cursor  (wraps `postgres`)
│   │   ├── mysql/         # wraps `mysql_client`
│   │   └── sqlite/        # wraps `sqlite3` (raw)
│   ├── services/          # SecureStorageService, LocalStore   (persistence store = #10 fills this)
│   └── repositories/      # ConnectionRepository, SchemaRepository,
│                          #   HistoryRepository, SettingsRepository
└── ui/
    ├── core/
    │   ├── theme/         # mix design tokens (theming ticket = #7)
    │   ├── shell/         # fluent NavigationView + CommandBar + base_menu menu bar
    │   └── widgets/       # shared widgets
    └── features/
        ├── connections/       # sidebar list + connection wizard
        ├── schema_browser/    # fluent TreeView  (lazy-load = #13)
        ├── query_workspace/   # TabView of Worksheets: re_editor + pluto_grid
        ├── history/           # QueryHistory list
        └── settings/
test/                          # mirrors lib/
```

## Riverpod conventions

- **Codegen + freezed.** `@riverpod` (riverpod_generator) for providers; `freezed`
  for domain models and each feature's view-model state. `build_runner` in the
  toolchain.
- **ViewModel = a Riverpod `Notifier`/`AsyncNotifier`** exposing an immutable
  state, living in `ui/features/<f>/view_models/`. Replaces the skill's
  `ChangeNotifier` ViewModel.
- **View = `ConsumerWidget`** (dumb): `ref.watch` the view-model provider, render;
  route user intent to view-model methods.
- **DI = the provider graph.** Repositories and services are exposed as root
  providers; ViewModels `ref.watch` them. No `get_it`.

## Per-Worksheet Session lifecycle

Per the domain model each Worksheet owns its own Session (tx-isolated). Expressed
as an **autoDispose family**:

```dart
final sessionProvider = AsyncNotifierProvider
    .autoDispose.family<SessionNotifier, Session, WorksheetId>(...);
// SessionNotifier.build: resolve Connection -> Driver.connect() -> Session
// ref.onDispose(() => session.close());
```

Closing a Worksheet tab disposes its providers → `onDispose` closes the Session.
Session lifetime = tab lifetime, no manual SessionManager to leak. → **ADR-0004**.

## Repository catalog (single sources of truth)

| Repository | Wraps | Returns |
|------------|-------|---------|
| `ConnectionRepository` | `LocalStore` + `SecureStorageService` | saved `Connection`s (secret by ref) |
| `SchemaRepository` | a **per-Connection** introspection `Session`'s `SchemaIntrospector` (+ cache), keyed by `ConnectionId` | canonical hierarchy objects (schema-tree ticket #13, ADR-0008) |
| `HistoryRepository` | `LocalStore` | `HistoryEntry`s |
| `SettingsRepository` | `LocalStore` | app settings |

Running SQL is not a repository: a Worksheet's view-model calls
`session.execute(...)` and drives the `ResultCursor` (query-execution ticket #12).

## Cross-references

- **Persistence store (#10)** decides `LocalStore` (drift/sqlite vs files) and the
  schema behind the repositories — fills `data/services` + `data/repositories`.
- **Credentials (#11)** decides `SecureStorageService`.
- **Theming (#7)** fills `ui/core/theme` (mix tokens).
- **Query execution (#12)** governs `query_workspace` view-models.
- **Schema tree (#13, ADR-0008)** governs `schema_browser` + `SchemaRepository`
  caching. Note: the tree runs on a **dedicated per-Connection introspection
  Session** (keyed by `ConnectionId`), *distinct* from the per-Worksheet Sessions
  below — catalog reads must not ride a user's transaction.
