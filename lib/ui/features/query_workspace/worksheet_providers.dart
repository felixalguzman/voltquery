import 'package:riverpod/riverpod.dart' show Ref;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/drivers/sqlite/sqlite_driver.dart';
import '../../../domain/drivers/driver.dart';
import '../../../domain/drivers/result.dart';
import '../../../domain/models/connection.dart';
import '../../../domain/models/engine.dart';
import '../../../domain/models/schema.dart';
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
  final session = await SqliteDriver().connect(conn);
  if (conn.id == 'demo') await _seedDemoIfEmpty(session);
  ref.onDispose(session.close);
  return session;
}

/// The live Session for one Worksheet (ADR-0002/0004): each owns its own,
/// tx-isolated. autoDispose (default) — closing a tab closes the Session.
@riverpod
Future<Session> worksheetSession(Ref ref, String worksheetId) async {
  final conn = ref.watch(currentConnectionProvider);
  final session = await SqliteDriver().connect(conn);
  if (conn.id == 'demo') await _seedDemoIfEmpty(session);
  ref.onDispose(session.close);
  return session;
}

Future<void> _seedDemoIfEmpty(Session s) async {
  final probe = await s.execute(
      "SELECT count(*) FROM sqlite_master WHERE type='table' AND name='customers'");
  final rows = await (probe as RowsResult).cursor.fetch(1);
  await probe.cursor.close();
  if ((rows.first.values.first as int) > 0) return;
  await s.execute('CREATE TABLE IF NOT EXISTS customers ('
      'id INTEGER PRIMARY KEY, name TEXT, email TEXT, total REAL)');
  await s.execute("INSERT INTO customers (name, email, total) VALUES "
      "('Ada Lovelace','ada@analytical.io',2940.0),"
      "('Grace Hopper',NULL,2731.5),"
      "('Alan Turing','a.turing@bletchley.example',1998.99),"
      "('Katherine Johnson','kj@nasa.gov',1640.0)");
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
  WorksheetResult build(String worksheetId) => const WorksheetIdle();

  void reset() => state = const WorksheetIdle();

  Future<void> run(String sql) async {
    if (sql.trim().isEmpty) return;
    state = const WorksheetRunning();
    final session = await ref.read(worksheetSessionProvider(worksheetId).future);
    state = await ref.read(worksheetRunnerProvider).run(session, sql.trim());
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
