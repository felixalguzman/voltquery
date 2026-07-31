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

/// The seeded demo — a **shared-cache in-memory** SQLite DB so every
/// per-Worksheet session (and the introspection session) sees the same data.
const demoConnection = Connection(
  id: 'demo',
  name: 'demo',
  engine: Engine.sqlite,
  sqlitePath: 'file:vqdemo?mode=memory&cache=shared',
);

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

@riverpod
WorksheetRunner worksheetRunner(Ref ref) => const WorksheetRunner();

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

  void reset() => state = const WorksheetIdle();

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

    final runner = ref.read(worksheetRunnerProvider);
    final outcomes = <StatementOutcome>[];
    var ranDdl = false;
    for (var k = 0; k < statements.length; k++) {
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
      if (result is WorksheetFailure) break; // stop-on-error
      if (st.kind == StatementKind.ddl) ranDdl = true;
    }
    state = WorksheetScript(outcomes);
    // Any successful DDL may have changed the catalog — drop the tree cache.
    if (ranDdl) ref.invalidate(schemaRepositoryProvider);
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

  void add() {
    final id = _next();
    state = WorksheetTabsState(ids: [...state.ids, id], activeId: id);
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
