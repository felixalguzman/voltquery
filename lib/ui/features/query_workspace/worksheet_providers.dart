import 'dart:io';

import 'package:riverpod/riverpod.dart' show Ref;
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

Future<void> _seedDemoIfEmpty(Session s) async {
  final probe = await s.execute(
    "SELECT count(*) FROM sqlite_master WHERE type='table' AND name='customers'",
  );
  final rows = await (probe as RowsResult).cursor.fetch(1);
  await probe.cursor.close();
  if ((rows.first.values.first as int) > 0) return;
  await s.execute(
    'CREATE TABLE IF NOT EXISTS customers ('
    'id INTEGER PRIMARY KEY, name TEXT, email TEXT, total REAL)',
  );
  await s.execute(
    "INSERT INTO customers (name, email, total) VALUES "
    "('Ada Lovelace','ada@analytical.io',2940.0),"
    "('Grace Hopper',NULL,2731.5),"
    "('Alan Turing','a.turing@bletchley.example',1998.99),"
    "('Katherine Johnson','kj@nasa.gov',1640.0)",
  );
}

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
  Map<String, String> build() => const {};

  void put(String worksheetId, String sql) =>
      state = {...state, worksheetId: sql};

  String? take(String worksheetId) {
    final sql = state[worksheetId];
    if (sql != null) state = {...state}..remove(worksheetId);
    return sql;
  }
}

@riverpod
WorksheetRunner worksheetRunner(Ref ref) => const WorksheetRunner();

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
    // slow (network) connects. `.select((_) => null)` keeps it alive without
    // rebuilding this notifier when the session's AsyncValue changes.
    ref.watch(worksheetSessionProvider(worksheetId).select((_) => null));
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
    WorksheetResult result,
  ) async {
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
      _ => (HistoryStatus.ok, null, null, null),
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
