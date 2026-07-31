import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/drivers/sqlite/sqlite_driver.dart';
import '../../../domain/drivers/driver.dart';
import '../../../domain/drivers/result.dart';
import '../../../domain/models/connection.dart';
import '../../../domain/models/engine.dart';
import '../../../domain/models/schema.dart';
import 'worksheet_runner.dart';
import 'worksheet_state.dart';

// TODO(ADR-0004): migrate to @riverpod codegen.

/// The seeded demo — a **shared-cache in-memory** SQLite DB so every
/// per-Worksheet session (and the introspection session) sees the same data,
/// like a real shared store. Default until a file is opened.
const demoConnection = Connection(
  id: 'demo',
  name: 'demo',
  engine: Engine.sqlite,
  sqlitePath: 'file:vqdemo?mode=memory&cache=shared',
);

/// The connection the workspace currently targets. Swapped by opening a file.
final currentConnectionProvider =
    StateProvider<Connection>((ref) => demoConnection);

/// Dedicated **per-Connection introspection Session** (ADR-0008) — distinct
/// from the per-Worksheet sessions so catalog reads never ride a user's
/// transaction. Also keeps the shared in-memory demo alive + seeds it.
final introspectionSessionProvider = FutureProvider<Session>((ref) async {
  final conn = ref.watch(currentConnectionProvider);
  final session = await SqliteDriver().connect(conn);
  if (conn.id == 'demo') await _seedDemoIfEmpty(session);
  ref.onDispose(session.close);
  return session;
});

/// The live Session for one Worksheet (ADR-0002/0004): each Worksheet owns its
/// own, tx-isolated. `autoDispose.family` — closing a tab disposes the provider
/// → `onDispose` closes the Session. Connects to the same connection as the
/// introspection session (shared demo already seeded).
final worksheetSessionProvider =
    FutureProvider.autoDispose.family<Session, String>((ref, worksheetId) async {
  final conn = ref.watch(currentConnectionProvider);
  final session = await SqliteDriver().connect(conn);
  if (conn.id == 'demo') await _seedDemoIfEmpty(session);
  ref.onDispose(session.close);
  return session;
});

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

/// Tables + views of the active connection, for the schema sidebar. Uses the
/// dedicated introspection session (ADR-0008).
final schemaTablesProvider = FutureProvider<List<TableInfo>>((ref) async {
  final session = await ref.watch(introspectionSessionProvider.future);
  return session.schema.tables(const SchemaInfo(''));
});

/// A query the sidebar asks the *active* worksheet to load + run.
final requestedQueryProvider = StateProvider<String?>((ref) => null);

/// Opens a SQLite file as the active connection (name = its file name).
void openSqliteFile(WidgetRef ref, String path) {
  ref.read(currentConnectionProvider.notifier).state = Connection(
    id: path,
    name: path.split(RegExp(r'[/\\]')).last,
    engine: Engine.sqlite,
    sqlitePath: path,
  );
}

final worksheetRunnerProvider =
    Provider<WorksheetRunner>((ref) => const WorksheetRunner());

/// Per-Worksheet result state (family keyed by WorksheetId).
class WorksheetController
    extends AutoDisposeFamilyNotifier<WorksheetResult, String> {
  @override
  WorksheetResult build(String arg) => const WorksheetIdle();

  void reset() => state = const WorksheetIdle();

  Future<void> run(String sql) async {
    if (sql.trim().isEmpty) return;
    state = const WorksheetRunning();
    final session = await ref.read(worksheetSessionProvider(arg).future);
    state = await ref.read(worksheetRunnerProvider).run(session, sql.trim());
  }
}

final worksheetResultProvider = NotifierProvider.autoDispose
    .family<WorksheetController, WorksheetResult, String>(
        WorksheetController.new);

/// Open Worksheet tabs + the active one.
class WorksheetTabsState {
  const WorksheetTabsState({required this.ids, required this.activeId});
  final List<String> ids;
  final String activeId;
}

class WorksheetTabsController extends Notifier<WorksheetTabsState> {
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
    if (state.ids.length == 1) return; // always keep one open
    final ids = state.ids.where((i) => i != id).toList();
    final active = state.activeId == id ? ids.last : state.activeId;
    state = WorksheetTabsState(ids: ids, activeId: active);
  }
}

final worksheetTabsProvider =
    NotifierProvider<WorksheetTabsController, WorksheetTabsState>(
        WorksheetTabsController.new);
