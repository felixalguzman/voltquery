import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/drivers/sqlite/sqlite_driver.dart';
import '../../../domain/drivers/driver.dart';
import '../../../domain/models/connection.dart';
import '../../../domain/models/engine.dart';
import 'worksheet_runner.dart';
import 'worksheet_state.dart';

// TODO(ADR-0004): migrate to @riverpod codegen; replace demoSessionProvider with
// sessionProvider.autoDispose.family<Session, WorksheetId> resolving a real
// Connection + SecretStore. This slice uses a seeded in-memory demo session so
// connect → query → grid is visible on launch.

/// A seeded in-memory SQLite session — the app's first end-to-end path.
final demoSessionProvider = FutureProvider<Session>((ref) async {
  final session = await SqliteDriver().connect(
    const Connection(
      id: 'demo',
      name: 'demo',
      engine: Engine.sqlite,
      sqlitePath: ':memory:',
    ),
  );
  await session.execute(
    'CREATE TABLE customers ('
    'id INTEGER PRIMARY KEY, name TEXT, email TEXT, total REAL)',
  );
  await session.execute(
    "INSERT INTO customers (name, email, total) VALUES "
    "('Ada Lovelace','ada@analytical.io',2940.0),"
    "('Grace Hopper',NULL,2731.5),"
    "('Alan Turing','a.turing@bletchley.example',1998.99),"
    "('Katherine Johnson','kj@nasa.gov',1640.0)",
  );
  ref.onDispose(session.close);
  return session;
});

final worksheetRunnerProvider =
    Provider<WorksheetRunner>((ref) => const WorksheetRunner());

/// Holds the current result for the (single, this-slice) worksheet.
class WorksheetNotifier extends Notifier<WorksheetResult> {
  @override
  WorksheetResult build() => const WorksheetIdle();

  Future<void> run(String sql) async {
    final session = ref.read(demoSessionProvider).valueOrNull;
    if (session == null || sql.trim().isEmpty) return;
    state = const WorksheetRunning();
    state = await ref.read(worksheetRunnerProvider).run(session, sql.trim());
  }
}

final worksheetProvider =
    NotifierProvider<WorksheetNotifier, WorksheetResult>(WorksheetNotifier.new);
