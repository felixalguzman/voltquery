import 'package:flutter_test/flutter_test.dart';
import 'package:voltquery/data/drivers/sqlite/sqlite_driver.dart';
import 'package:voltquery/domain/drivers/driver.dart';
import 'package:voltquery/domain/drivers/driver_error.dart';
import 'package:voltquery/domain/drivers/result.dart';
import 'package:voltquery/domain/models/connection.dart';
import 'package:voltquery/domain/models/schema.dart';
import 'package:voltquery/domain/models/engine.dart';

/// Tests at the driver-port seam (Driver/Session/ResultCursor/SchemaIntrospector),
/// exercised against a real in-memory sqlite3 — behavior, not internals.
void main() {
  late Driver driver;
  late Session session;

  setUp(() async {
    driver = SqliteDriver();
    session = await driver.connect(
      const Connection(
        id: 't',
        name: 'mem',
        engine: Engine.sqlite,
        sqlitePath: ':memory:',
      ),
    );
  });

  tearDown(() async => session.close());

  test('SELECT returns a RowsResult whose cursor yields fields and rows',
      () async {
    final result = await session.execute("SELECT 1 AS id, 'ada' AS name");

    expect(result, isA<RowsResult>());
    final cursor = (result as RowsResult).cursor;
    expect(cursor.fields.map((f) => f.name).toList(), ['id', 'name']);

    final rows = await cursor.fetch(10);
    expect(rows, hasLength(1));
    expect(rows.first.values, [1, 'ada']);

    await cursor.close();
  });

  test('CREATE + INSERT return CommandResult with affected-row count', () async {
    final create = await session
        .execute('CREATE TABLE t (id INTEGER PRIMARY KEY, name TEXT)');
    expect(create, isA<CommandResult>());

    final insert =
        await session.execute("INSERT INTO t (name) VALUES ('ada'), ('grace')");
    expect(insert, isA<CommandResult>());
    expect((insert as CommandResult).affectedRows, 2);
  });

  test('invalid SQL surfaces as a normalized DriverError(syntaxError)', () async {
    await expectLater(
      () => session.execute('SELCT nope FROM'),
      throwsA(isA<DriverError>()
          .having((e) => e.kind, 'kind', DriverErrorKind.syntaxError)),
    );
  });

  test('introspection lists tables/views and column metadata', () async {
    await session.execute(
        'CREATE TABLE users (id INTEGER PRIMARY KEY, email TEXT NOT NULL)');
    await session.execute('CREATE VIEW active AS SELECT * FROM users');

    final tables = await session.schema.tables(const SchemaInfo(''));
    expect(tables.map((t) => t.name), containsAll(['users', 'active']));
    expect(tables.firstWhere((t) => t.name == 'users').kind, ObjectKind.table);
    expect(tables.firstWhere((t) => t.name == 'active').kind, ObjectKind.view);

    final cols = await session.schema
        .columns(const TableInfo(name: 'users', kind: ObjectKind.table));
    expect(cols.map((c) => c.name).toList(), ['id', 'email']);
    expect(cols.firstWhere((c) => c.name == 'id').isPrimaryKey, isTrue);
    expect(cols.firstWhere((c) => c.name == 'email').nullable, isFalse);
  });

  test('SQLite capabilities: no server, no schemas, no query-cancel', () {
    expect(driver.engine, Engine.sqlite);
    final c = driver.capabilities;
    expect(c.hasServer, isFalse);
    expect(c.hasSchemas, isFalse);
    expect(c.supportsQueryCancel, isFalse);
  });

  test('cancelActive throws DriverError(unsupported) on SQLite', () {
    expect(
      session.cancelActive(),
      throwsA(isA<DriverError>()
          .having((e) => e.kind, 'kind', DriverErrorKind.unsupported)),
    );
  });
}
