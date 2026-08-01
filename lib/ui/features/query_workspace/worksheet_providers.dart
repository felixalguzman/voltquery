import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/drivers/driver_factory.dart';
import '../../../domain/drivers/driver.dart';
import '../../../domain/drivers/driver_error.dart';
import '../../../domain/drivers/result.dart';
import '../../../domain/models/connection.dart';
import '../../../domain/models/engine.dart';
import '../../../domain/models/history_entry.dart';
import '../../../domain/models/schema.dart';
import '../../../domain/sql/sql_statement_splitter.dart';
import '../connections/connection_providers.dart';
import '../history/history_providers.dart';
import '../schema_browser/schema_providers.dart';
import 'grid_edit_buffer.dart';
import 'grid_editability.dart';
import 'worksheet_runner.dart';
import 'worksheet_state.dart';

part 'worksheet_providers.g.dart';

/// The seeded demo — a **temp-file** SQLite DB (unique per app run) so the
/// introspection Session and every Worksheet Session share ONE real database.
///
/// It used to be a `cache=shared` in-memory DB, but that cache is *not* shared
/// across connections on the bundled desktop sqlite — each session got its own
/// private DB (masked because each self-seeds `customers`), so DDL run in a
/// worksheet stayed invisible to the schema tree. A real file always shares. A
/// fresh path per run keeps the demo pristine each launch; [sweepDemoDbs] (from
/// `main`) removes leftovers.
final Connection demoConnection = Connection(
  id: 'demo',
  name: 'demo',
  engine: Engine.sqlite,
  sqlitePath: _demoDbPath(),
);

String _demoDbPath() =>
    '${Directory.systemTemp.path}/voltquery_demo_'
    '${DateTime.now().microsecondsSinceEpoch}.db';

/// Best-effort delete of demo temp DBs left by earlier runs. Called from `main`
/// at startup (no session is open yet, so nothing is in use).
void sweepDemoDbs() {
  try {
    for (final e in Directory.systemTemp.listSync()) {
      if (e is File && e.path.contains('voltquery_demo_')) e.deleteSync();
    }
  } catch (_) {
    // Sweep is a courtesy — never let it block startup.
  }
}

/// The connection the workspace currently targets.
@riverpod
class CurrentConnection extends _$CurrentConnection {
  @override
  Connection build() => demoConnection;

  void set(Connection connection) => state = connection;

  /// Opens a SQLite file as the active connection (name = its file name).
  void openFile(String path) => state = Connection(
    id: path,
    name: path.split(RegExp(r'[/\\]')).last,
    engine: Engine.sqlite,
    sqlitePath: path,
  );
}

/// Dedicated **per-Connection introspection Session** (ADR-0008), distinct from
/// the per-Worksheet sessions. Kept alive so it seeds + holds the shared demo.
@Riverpod(keepAlive: true)
Future<Session> introspectionSession(Ref ref) async {
  final conn = ref.watch(currentConnectionProvider);
  final session = await _openSession(ref, conn);
  if (conn.id == 'demo') await _seedDemoIfEmpty(session);
  return session;
}

/// The live Session for one Worksheet (ADR-0002/0004): each owns its own,
/// tx-isolated. autoDispose (default) — closing a tab closes the Session.
@riverpod
Future<Session> worksheetSession(Ref ref, String worksheetId) async {
  final conn = ref.watch(currentConnectionProvider);
  final session = await _openSession(ref, conn);
  if (conn.id == 'demo') await _seedDemoIfEmpty(session);
  return session;
}

/// Opens a Session, resolving the secret from the vault. Disposal-safe: if the
/// provider is disposed while `connect` is in flight (connection switched, tab
/// closed, slow network), the session is closed instead of leaking / throwing
/// `onDispose after dispose`.
Future<Session> _openSession(Ref ref, Connection conn) async {
  var disposed = false;
  ref.onDispose(() => disposed = true);
  final secret = conn.credentialRef == null
      ? null
      : await (await ref.read(
          secretStoreProvider.future,
        )).read(conn.credentialRef!);
  final session = await driverFor(conn.engine).connect(conn, secret: secret);
  if (disposed) {
    await session.close();
    throw StateError('session disposed before connect completed');
  }
  ref.onDispose(session.close);
  return session;
}

/// Seeds the demo database — a small but *representative* schema, not just one
/// table.
///
/// It's deliberately shaped to exercise the app's own features, because the
/// demo is what you reach for when checking whether something works:
/// - every [ColumnEditorKind] the grid can render — boolean, date, datetime,
///   decimal, integer, text, json — so the typed cell editors have something to
///   edit;
/// - foreign keys (`orders`→`customers`, `order_items`→both) so the tree's FK
///   glyphs and, later, FK navigation have real relationships;
/// - indexes, including a composite and a unique one, for the Indexes group;
/// - a **view** and a **primary-key-less table**, which are exactly the two
///   cases the grid must refuse to make editable;
/// - a NULL in a nullable column, so NULL rendering is visible on first run.
Future<void> _seedDemoIfEmpty(Session s) async {
  final probe = await s.execute(
    "SELECT count(*) FROM sqlite_master WHERE type='table' AND name='customers'",
  );
  final rows = await (probe as RowsResult).cursor.fetch(1);
  await probe.cursor.close();
  if ((rows.first.values.first as int) > 0) return;

  for (final ddl in _demoSchema) {
    await s.execute(ddl);
  }
  for (final dml in _demoRows) {
    await s.execute(dml);
  }
}

/// Declared SQLite types are chosen for their *affinity* so
/// `ColumnEditorResolver` picks a real editor: BOOLEAN → toggle, DATE → date
/// picker, DATETIME → date+time, REAL/NUMERIC → decimal.
const _demoSchema = <String>[
  'CREATE TABLE IF NOT EXISTS customers ('
      'id INTEGER PRIMARY KEY, '
      'name TEXT NOT NULL, '
      'email TEXT, '
      'total REAL, '
      'active BOOLEAN NOT NULL DEFAULT 1, '
      'signed_up DATE, '
      'notes TEXT)',
  'CREATE TABLE IF NOT EXISTS products ('
      'id INTEGER PRIMARY KEY, '
      'sku TEXT NOT NULL, '
      'name TEXT NOT NULL, '
      'price NUMERIC(10,2) NOT NULL, '
      'in_stock INTEGER NOT NULL DEFAULT 0, '
      'discontinued BOOLEAN NOT NULL DEFAULT 0)',
  'CREATE TABLE IF NOT EXISTS orders ('
      'id INTEGER PRIMARY KEY, '
      'customer_id INTEGER NOT NULL REFERENCES customers(id), '
      'placed_at DATETIME NOT NULL, '
      'status TEXT NOT NULL DEFAULT \'pending\', '
      'shipped BOOLEAN NOT NULL DEFAULT 0, '
      'amount REAL NOT NULL)',
  // Composite primary key — proves multi-column row identity in the grid.
  'CREATE TABLE IF NOT EXISTS order_items ('
      'order_id INTEGER NOT NULL REFERENCES orders(id), '
      'product_id INTEGER NOT NULL REFERENCES products(id), '
      'quantity INTEGER NOT NULL DEFAULT 1, '
      'unit_price REAL NOT NULL, '
      'PRIMARY KEY (order_id, product_id))',
  // No primary key: the grid must refuse to edit this one.
  'CREATE TABLE IF NOT EXISTS audit_log ('
      'at DATETIME NOT NULL, '
      'action TEXT NOT NULL, '
      'detail TEXT)',
  'CREATE INDEX IF NOT EXISTS ix_orders_customer ON orders (customer_id)',
  'CREATE INDEX IF NOT EXISTS ix_orders_status_placed '
      'ON orders (status, placed_at)',
  'CREATE UNIQUE INDEX IF NOT EXISTS ux_products_sku ON products (sku)',
  // A view: read-only, and gives the tree a second object kind to show.
  'CREATE VIEW IF NOT EXISTS customer_orders AS '
      'SELECT c.name AS customer, o.id AS order_id, o.placed_at, o.amount '
      'FROM orders o JOIN customers c ON c.id = o.customer_id',
];

const _demoRows = <String>[
  // `email` NULL on one row so NULL rendering shows up immediately.
  "INSERT INTO customers (name, email, total, active, signed_up, notes) VALUES "
      "('Ada Lovelace','ada@analytical.io',2940.0,1,'2024-01-15','First "
      "programmer'),"
      "('Grace Hopper',NULL,2731.5,1,'2024-02-02','Coined \"debugging\"'),"
      "('Alan Turing','a.turing@bletchley.example',1998.99,0,'2024-03-21',NULL),"
      "('Katherine Johnson','kj@nasa.gov',1640.0,1,'2024-05-09','Orbital "
      "mechanics')",
  "INSERT INTO products (sku, name, price, in_stock, discontinued) VALUES "
      "('KB-01','Mechanical Keyboard',129.99,42,0),"
      "('MS-02','Trackball Mouse',79.50,17,0),"
      "('MN-03','27\" Monitor',349.00,8,0),"
      "('CB-04','USB-C Cable',12.25,0,1)",
  "INSERT INTO orders (customer_id, placed_at, status, shipped, amount) VALUES "
      "(1,'2024-06-01 09:15:00','shipped',1,209.49),"
      "(1,'2024-06-18 14:02:00','pending',0,349.00),"
      "(2,'2024-06-20 11:30:00','shipped',1,129.99),"
      "(3,'2024-07-02 16:45:00','cancelled',0,91.75),"
      "(4,'2024-07-11 08:05:00','pending',0,428.50)",
  "INSERT INTO order_items (order_id, product_id, quantity, unit_price) VALUES "
      "(1,1,1,129.99),(1,2,1,79.50),"
      "(2,3,1,349.00),"
      "(3,1,1,129.99),"
      "(4,2,1,79.50),(4,4,1,12.25),"
      "(5,3,1,349.00),(5,1,1,79.50)",
  "INSERT INTO audit_log (at, action, detail) VALUES "
      "('2024-07-11 08:05:12','order.created','order 5'),"
      "('2024-07-11 08:05:13','payment.authorized','428.50')",
];

/// Tables + views of the active connection (via the introspection session).
@riverpod
Future<List<TableInfo>> schemaTables(Ref ref) async {
  final session = await ref.watch(introspectionSessionProvider.future);
  return session.schema.tables(const SchemaInfo(''));
}

/// A query the sidebar asks the *active* worksheet to load + run.
@riverpod
class RequestedQuery extends _$RequestedQuery {
  @override
  String? build() => null;

  void request(String sql) => state = sql;
  void clear() => state = null;
}

/// The one-shot SQL a freshly opened Worksheet loads into its editor, plus
/// whether it should run itself on open. "Preview data" seeds with
/// [autoRun] = true; "Open in editor" seeds with false (load, don't run).
class WorksheetSeed {
  const WorksheetSeed(this.sql, {this.autoRun = true});
  final String sql;
  final bool autoRun;
}

/// One-shot initial SQL for a **freshly opened** Worksheet — the sidebar's
/// "open table" opens a *new* tab (never clobbering the current editor) and
/// seeds it here. The Worksheet consumes + clears its seed on first build.
///
/// **keepAlive**: nobody *watches* this (only `put`/`take`), so an autoDispose
/// provider would reset to `{}` in the microtask between opening the tab and the
/// new Worksheet's `initState` reading the seed — losing it.
@Riverpod(keepAlive: true)
class WorksheetSeeds extends _$WorksheetSeeds {
  @override
  Map<String, WorksheetSeed> build() => const {};

  void put(String worksheetId, String sql, {bool autoRun = true}) =>
      state = {...state, worksheetId: WorksheetSeed(sql, autoRun: autoRun)};

  WorksheetSeed? take(String worksheetId) {
    final seed = state[worksheetId];
    if (seed != null) state = {...state}..remove(worksheetId);
    return seed;
  }
}

@riverpod
WorksheetRunner worksheetRunner(Ref ref) => const WorksheetRunner();

/// Pending cell edits for one result grid, keyed `<worksheetId>:<resultIndex>`
/// so each result sub-tab stages independently.
///
/// **keepAlive**: the grid rebuilds as the user types elsewhere; an autoDispose
/// buffer would silently drop staged edits.
@Riverpod(keepAlive: true)
class GridEdits extends _$GridEdits {
  @override
  GridEditBuffer build(String gridId) => const GridEditBuffer();

  void stage(StagedEdit edit) => state = state.stage(edit);
  void discardCell(int rowIndex, String column) =>
      state = state.discardCell(rowIndex, column);
  void clear() => state = state.clear();
}

/// Applies a grid's staged edits: runs each generated statement in order on the
/// worksheet's own Session, then clears the buffer.
///
/// Runs on the *worksheet's* session so it honours the manual-commit toggle —
/// with manual commit on, the UPDATEs land inside the open transaction and the
/// user still has to press Commit. Stops at the first failure and reports it.
class GridEditApplyResult {
  const GridEditApplyResult({
    required this.applied,
    this.rowsAffected = 0,
    this.error,
  });

  /// Statements that ran successfully. Zero on failure — the whole batch is
  /// rolled back, so nothing was applied.
  final int applied;

  /// Rows the engine actually changed, summed across the statements. Can differ
  /// from [applied]: a row deleted by someone else since the result was read
  /// matches nothing and reports 0.
  final int rowsAffected;

  final DriverError? error;
  bool get ok => error == null;
}

/// Commands issued from the app shell (menu bar / global shortcuts) that the
/// **active** Worksheet executes against its own editor + Session. `runSmart` =
/// selection-else-cursor (the worksheet decides, since only it knows the caret).
enum WorksheetCommand { runSmart, runWhole, runAtCursor, runSelection, cancel }

/// One dispatched command; [seq] makes repeated same-command dispatches distinct
/// so `ref.listen` fires every time (e.g. Ctrl+Enter twice).
class WorksheetCommandEvent {
  const WorksheetCommandEvent(this.seq, this.command);
  final int seq;
  final WorksheetCommand command;
}

@Riverpod(keepAlive: true)
class WorksheetCommands extends _$WorksheetCommands {
  int _seq = 0;

  @override
  WorksheetCommandEvent? build() => null;

  void dispatch(WorksheetCommand command) =>
      state = WorksheetCommandEvent(_seq++, command);
}

/// Run-loop error policy (ADR-0007). Default **stop-on-error**; toggled to
/// continue-on-error from the worksheet toolbar. Global (kept alive) so it
/// persists across worksheet rebuilds.
@Riverpod(keepAlive: true)
class ContinueOnError extends _$ContinueOnError {
  @override
  bool build() => false;

  void toggle() => state = !state;
  // ignore: avoid_positional_boolean_parameters
  void set(bool value) => state = value;
}

/// Per-Worksheet transaction mode (ADR-0007). Off = autocommit (each statement
/// commits immediately). On = manual: the app issues `begin()` before the first
/// run and holds the tx open until the user Commits/Rolls back.
@riverpod
class ManualCommit extends _$ManualCommit {
  @override
  bool build(String worksheetId) => false;

  void toggle() => state = !state;
}

/// Whether a manual transaction is currently open for a Worksheet — the single
/// source of truth for the Commit/Rollback affordances (drivers don't reliably
/// report `inTransaction` for pg/mysql, so we track it app-side).
@riverpod
class WorksheetTx extends _$WorksheetTx {
  @override
  bool build(String worksheetId) => false;

  // ignore: avoid_positional_boolean_parameters
  void set(bool open) => state = open;
}

/// Per-Worksheet result state (family keyed by WorksheetId).
@riverpod
class Worksheet extends _$Worksheet {
  @override
  WorksheetResult build(String worksheetId) {
    // Keep this worksheet's Session alive for the worksheet's lifetime
    // (ADR-0004). Without this, a one-off `read` on the autoDispose session
    // provider disposes it mid-connect — fine for instant SQLite, but it races
    // slow (network) connects. `listen` (not `watch`) subscribes — which holds
    // the dependency alive — without rebuilding this notifier when the
    // session's AsyncValue changes. Riverpod 3 dropped `.select` on functional
    // async providers, which is how this used to be expressed.
    ref.listen(worksheetSessionProvider(worksheetId), (_, _) {});
    return const WorksheetIdle();
  }

  /// Set by [cancel]; the run loop stops at the next boundary.
  bool _cancelRequested = false;

  void reset() => state = const WorksheetIdle();

  /// Stop the in-flight run. Abandons + closes the Session so an in-flight
  /// *server* query aborts (the autoDispose family re-creates it on the next
  /// run); the loop then stops before the next statement. SQLite runs
  /// synchronously on the main isolate, so a single running statement can't be
  /// interrupted — Cancel stops the *remaining* statements of a script.
  void cancel() {
    if (state is! WorksheetRunning) return;
    _cancelRequested = true;
    ref.invalidate(worksheetSessionProvider(worksheetId));
  }

  /// Splits [sql] into statements (dialect-aware) and runs them **in order** on
  /// this Worksheet's one Session, **stop-on-error** (ADR-0007). Each statement
  /// records its own HistoryEntry; a successful DDL evicts the schema-tree cache
  /// (ADR-0008 / #13) so the sidebar reflects the new shape.
  Future<void> run(String sql) async {
    final conn = ref.read(currentConnectionProvider);
    final statements = SqlStatementSplitter(
      SqlDialect.of(conn.engine),
    ).split(sql);
    if (statements.isEmpty) return;
    _cancelRequested = false;
    state = const WorksheetRunning();

    // One session for the whole script. Opening it can fail (auth, vault
    // locked, unreachable) — surface that as a single failed outcome.
    final Session session;
    try {
      session = await ref.read(worksheetSessionProvider(worksheetId).future);
    } catch (e) {
      final err = e is DriverError
          ? e
          : DriverError(DriverErrorKind.connectionFailed, e.toString());
      state = WorksheetScript([
        StatementOutcome(
          index: 1,
          sql: statements.first.sql,
          kind: statements.first.kind,
          result: WorksheetFailure(err),
        ),
      ]);
      return;
    }

    // Manual-commit mode: open a transaction before the first statement and
    // leave it open (autocommit mode does nothing here — each statement commits).
    if (ref.read(manualCommitProvider(worksheetId)) &&
        !ref.read(worksheetTxProvider(worksheetId))) {
      try {
        await session.begin();
        ref.read(worksheetTxProvider(worksheetId).notifier).set(true);
      } catch (_) {
        // If BEGIN fails, fall through and run in autocommit — never brick Run.
      }
    }

    final runner = ref.read(worksheetRunnerProvider);
    final continueOnError = ref.read(continueOnErrorProvider);
    final outcomes = <StatementOutcome>[];
    var ranDdl = false;
    for (var k = 0; k < statements.length; k++) {
      if (_cancelRequested) break;
      final st = statements[k];
      final started = DateTime.now();
      final sw = Stopwatch()..start();
      WorksheetResult result;
      try {
        result = await runner.run(session, st.sql);
      } on DriverError catch (e) {
        result = WorksheetFailure(e);
      } catch (e) {
        result = WorksheetFailure(
          DriverError(DriverErrorKind.connectionFailed, e.toString()),
        );
      }
      sw.stop();
      // A row result that maps 1:1 onto one table's rows becomes an *editable*
      // grid. Resolved per statement because it depends on that statement's SQL.
      if (result is WorksheetRows) {
        result = result.withEditability(await _editabilityOf(st.sql));
      }
      outcomes.add(
        StatementOutcome(
          index: k + 1,
          sql: st.sql,
          kind: st.kind,
          result: result,
        ),
      );
      await _record(st.sql, started, sw.elapsedMilliseconds, result);
      if (result is WorksheetFailure) {
        if (!continueOnError) break; // stop-on-error (default)
        continue; // continue-on-error: a failed statement never counts as DDL
      }
      if (st.kind == StatementKind.ddl) ranDdl = true;
    }
    state = WorksheetScript(outcomes, canceled: _cancelRequested);
    // Any successful DDL may have changed the catalog — drop the tree cache.
    if (ranDdl) ref.invalidate(schemaRepositoryProvider);
  }

  /// Run the grid's staged edits against this worksheet's Session, in order.
  ///
  /// Deliberately on the worksheet's own session, so the manual-commit toggle
  /// applies: with it on, these land in the open transaction and still need an
  /// explicit Commit. Stops at the first failure — the remaining statements are
  /// left staged so the user can fix and retry.
  Future<GridEditApplyResult> applyGridEdits(List<String> statements) async {
    if (statements.isEmpty) return const GridEditApplyResult(applied: 0);
    final session = await ref.read(
      worksheetSessionProvider(worksheetId).future,
    );
    // One statement per edited row, so each stays readable in the review panel
    // — but they must land together. Without a transaction, a failure partway
    // through leaves the earlier rows already committed and the rest not.
    // Skipped when a manual-commit transaction is already open: the edits join
    // that one, and the user's own Commit/Rollback governs.
    final ownTx = !ref.read(worksheetTxProvider(worksheetId));
    if (ownTx) await session.begin();

    var applied = 0;
    var rowsAffected = 0;
    for (final sql in statements) {
      // Grid edits are real statements the user ran — they belong in history
      // exactly like a typed UPDATE, so they're auditable and re-runnable.
      final started = DateTime.now();
      final sw = Stopwatch()..start();
      try {
        final result = await session.execute(sql);
        sw.stop();
        applied++;
        final affected = result is CommandResult ? result.affectedRows : null;
        rowsAffected += affected ?? 0;
        await _record(
          sql,
          started,
          sw.elapsedMilliseconds,
          WorksheetMessage('${affected ?? 0} row(s) affected'),
          affectedRows: affected,
        );
      } on DriverError catch (e) {
        sw.stop();
        await _record(sql, started, sw.elapsedMilliseconds,
            WorksheetFailure(e));
        if (ownTx) await _rollbackQuietly(session);
        return GridEditApplyResult(applied: 0, error: e);
      } catch (e) {
        sw.stop();
        final err = DriverError(DriverErrorKind.unknown, e.toString());
        await _record(sql, started, sw.elapsedMilliseconds,
            WorksheetFailure(err));
        if (ownTx) await _rollbackQuietly(session);
        return GridEditApplyResult(applied: 0, error: err);
      }
    }
    if (ownTx) {
      try {
        await session.commit();
      } on DriverError catch (e) {
        return GridEditApplyResult(applied: 0, error: e);
      }
    }
    return GridEditApplyResult(applied: applied, rowsAffected: rowsAffected);
  }

  /// Best-effort rollback — the caller is already reporting the real failure,
  /// and a rollback error would only mask it.
  Future<void> _rollbackQuietly(Session session) async {
    try {
      await session.rollback();
    } catch (_) {
      // Nothing useful to do; the original error is what the user needs.
    }
  }

  /// Whether the grid for [sql] can write back, and how. Best-effort: any
  /// failure leaves the grid read-only rather than failing the run.
  Future<GridEditability?> _editabilityOf(String sql) async {
    try {
      final repo = await ref.read(schemaRepositoryProvider.future);
      return GridEditabilityResolver(
        engine: ref.read(currentConnectionProvider).engine,
        repo: repo,
      ).resolve(sql);
    } catch (_) {
      return null;
    }
  }

  /// Commit the open manual transaction (no-op if none). See [ManualCommit].
  Future<void> commit() => _endTx((s) => s.commit());

  /// Roll back the open manual transaction (no-op if none).
  Future<void> rollback() => _endTx((s) => s.rollback());

  Future<void> _endTx(Future<void> Function(Session) op) async {
    if (!ref.read(worksheetTxProvider(worksheetId))) return;
    try {
      final session = await ref.read(worksheetSessionProvider(worksheetId).future);
      await op(session);
    } finally {
      // Whether or not it threw, the app no longer considers a tx open — a stuck
      // "open" flag is worse than a redundant BEGIN on the next run.
      ref.read(worksheetTxProvider(worksheetId).notifier).set(false);
      // Committed/rolled-back DDL may have changed the catalog.
      ref.invalidate(schemaRepositoryProvider);
    }
  }

  Future<void> _record(
    String sql,
    DateTime started,
    int ms,
    WorksheetResult result, {
    /// Row count for results that aren't [WorksheetRows] — a DML statement's
    /// affected-row count, which the switch below can't recover from a
    /// [WorksheetMessage].
    int? affectedRows,
  }) async {
    final conn = ref.read(currentConnectionProvider);
    final (
      HistoryStatus status,
      int? rowCount,
      String? errKind,
      String? errMsg,
    ) = switch (result) {
      WorksheetRows(:final rows) => (HistoryStatus.ok, rows.length, null, null),
      WorksheetFailure(:final error) => (
        HistoryStatus.error,
        null,
        error.kind.name,
        error.message,
      ),
      _ => (HistoryStatus.ok, affectedRows, null, null),
    };
    await ref
        .read(historyRepositoryProvider)
        .record(
          HistoryEntry(
            connectionName: conn.name,
            engine: conn.engine.name,
            databaseName: conn.defaultDatabase,
            sql: sql,
            startedAt: started,
            durationMs: ms,
            status: status,
            rowCount: rowCount,
            errorKind: errKind,
            errorMessage: errMsg,
          ),
        );
  }
}

/// Open Worksheet tabs + the active one.
class WorksheetTabsState {
  const WorksheetTabsState({required this.ids, required this.activeId});
  final List<String> ids;
  final String activeId;
}

@riverpod
class WorksheetTabs extends _$WorksheetTabs {
  int _counter = 0;
  String _next() => 'ws-${_counter++}';

  @override
  WorksheetTabsState build() {
    final id = _next();
    return WorksheetTabsState(ids: [id], activeId: id);
  }

  /// Adds a new tab, makes it active, and returns its id (so a caller can seed
  /// its editor — see [WorksheetSeeds]).
  String add() {
    final id = _next();
    state = WorksheetTabsState(ids: [...state.ids, id], activeId: id);
    return id;
  }

  void select(String id) =>
      state = WorksheetTabsState(ids: state.ids, activeId: id);

  void close(String id) {
    if (state.ids.length == 1) return;
    final ids = state.ids.where((i) => i != id).toList();
    final active = state.activeId == id ? ids.last : state.activeId;
    state = WorksheetTabsState(ids: ids, activeId: active);
  }
}
