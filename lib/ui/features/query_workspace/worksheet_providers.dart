import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/drivers/sqlite/sqlite_driver.dart';
import '../../../domain/drivers/driver.dart';
import '../../../domain/models/connection.dart';
import '../../../domain/models/engine.dart';
import '../../../domain/models/schema.dart';
import 'worksheet_runner.dart';
import 'worksheet_state.dart';

// TODO(ADR-0004): migrate to @riverpod codegen; generalize to a
// sessionProvider.autoDispose.family<Session, WorksheetId> resolving a real
// Connection + SecretStore once Postgres/MySQL land.

/// The seeded in-memory demo connection — the default until a file is opened.
const demoConnection = Connection(
  id: 'demo',
  name: 'demo',
  engine: Engine.sqlite,
  sqlitePath: ':memory:',
);

/// The connection the workspace currently targets. Opening a `.sqlite` file
/// swaps this, which rebuilds [sessionProvider].
final currentConnectionProvider =
    StateProvider<Connection>((ref) => demoConnection);

/// The live [Session] for [currentConnectionProvider]. In-memory demo gets
/// seeded; a file connection opens that database directly.
final sessionProvider = FutureProvider<Session>((ref) async {
  final connection = ref.watch(currentConnectionProvider);
  final session = await SqliteDriver().connect(connection);
  if (connection.sqlitePath == ':memory:') {
    await _seedDemo(session);
  }
  ref.onDispose(session.close);
  return session;
});

Future<void> _seedDemo(Session s) async {
  await s.execute('CREATE TABLE customers ('
      'id INTEGER PRIMARY KEY, name TEXT, email TEXT, total REAL)');
  await s.execute("INSERT INTO customers (name, email, total) VALUES "
      "('Ada Lovelace','ada@analytical.io',2940.0),"
      "('Grace Hopper',NULL,2731.5),"
      "('Alan Turing','a.turing@bletchley.example',1998.99),"
      "('Katherine Johnson','kj@nasa.gov',1640.0)");
}

/// Tables + views of the active session, for the schema sidebar. Rebuilds when
/// the connection changes. SQLite has no schema level, so `SchemaInfo('')`.
final schemaTablesProvider = FutureProvider<List<TableInfo>>((ref) async {
  final session = await ref.watch(sessionProvider.future);
  return session.schema.tables(const SchemaInfo(''));
});

/// A query the sidebar asks the worksheet to load + run (e.g. click a table).
/// The worksheet listens, applies it to the editor, then clears this.
final requestedQueryProvider = StateProvider<String?>((ref) => null);

/// Opens a SQLite file as the active connection (name = its file name).
void openSqliteFile(WidgetRef ref, String path) {
  ref.read(currentConnectionProvider.notifier).state = Connection(
    id: path,
    name: path.split(RegExp(r'[/\\]')).last,
    engine: Engine.sqlite,
    sqlitePath: path,
  );
  ref.read(worksheetProvider.notifier).reset();
}

final worksheetRunnerProvider =
    Provider<WorksheetRunner>((ref) => const WorksheetRunner());

/// Holds the current result for the (single, this-slice) worksheet.
class WorksheetNotifier extends Notifier<WorksheetResult> {
  @override
  WorksheetResult build() => const WorksheetIdle();

  void reset() => state = const WorksheetIdle();

  Future<void> run(String sql) async {
    final session = ref.read(sessionProvider).valueOrNull;
    if (session == null || sql.trim().isEmpty) return;
    state = const WorksheetRunning();
    state = await ref.read(worksheetRunnerProvider).run(session, sql.trim());
  }
}

final worksheetProvider =
    NotifierProvider<WorksheetNotifier, WorksheetResult>(WorksheetNotifier.new);
