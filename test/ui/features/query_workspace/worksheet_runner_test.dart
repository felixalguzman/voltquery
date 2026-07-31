import 'package:flutter_test/flutter_test.dart';
import 'package:voltquery/data/drivers/sqlite/sqlite_driver.dart';
import 'package:voltquery/domain/drivers/driver.dart';
import 'package:voltquery/domain/models/connection.dart';
import 'package:voltquery/domain/models/engine.dart';
import 'package:voltquery/ui/features/query_workspace/worksheet_runner.dart';
import 'package:voltquery/ui/features/query_workspace/worksheet_state.dart';

/// Seam: WorksheetRunner.run() over a real SQLite Session — the logic the
/// query_workspace view drives. Widgets are verified separately by running.
void main() {
  late Session session;
  const runner = WorksheetRunner();

  setUp(() async {
    session = await SqliteDriver().connect(
      const Connection(
          id: 't', name: 'mem', engine: Engine.sqlite, sqlitePath: ':memory:'),
    );
    await session.execute('CREATE TABLE t (id INTEGER PRIMARY KEY, name TEXT)');
    await session.execute("INSERT INTO t (name) VALUES ('ada'), ('grace')");
  });
  tearDown(() async => session.close());

  test('SELECT materializes fields + rows for the grid', () async {
    final out = await runner.run(session, 'SELECT id, name FROM t ORDER BY id');

    expect(out, isA<WorksheetRows>());
    final rows = out as WorksheetRows;
    expect(rows.fields.map((f) => f.name).toList(), ['id', 'name']);
    expect(rows.rows.map((r) => r.values).toList(), [
      [1, 'ada'],
      [2, 'grace'],
    ]);
    expect(rows.capped, isFalse);
  });

  test('DML yields a WorksheetMessage with affected count', () async {
    final out = await runner.run(session, "UPDATE t SET name = 'x'");
    expect(out, isA<WorksheetMessage>());
    expect((out as WorksheetMessage).text, contains('2'));
  });

  test('invalid SQL yields a WorksheetFailure', () async {
    final out = await runner.run(session, 'SELCT nope');
    expect(out, isA<WorksheetFailure>());
  });

  test('render cap is reported', () async {
    for (var i = 0; i < 20; i++) {
      await session.execute("INSERT INTO t (name) VALUES ('n$i')");
    }
    final capped = const WorksheetRunner(rowCap: 5, batchSize: 2);
    final out = await capped.run(session, 'SELECT * FROM t');
    expect(out, isA<WorksheetRows>());
    final rows = out as WorksheetRows;
    expect(rows.rows, hasLength(5));
    expect(rows.capped, isTrue);
  });
}
