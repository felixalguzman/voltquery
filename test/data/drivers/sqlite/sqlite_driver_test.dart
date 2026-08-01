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

  test('introspection flags foreign-key columns', () async {
    await session.execute('CREATE TABLE parent (id INTEGER PRIMARY KEY)');
    await session.execute('CREATE TABLE child ('
        'id INTEGER PRIMARY KEY, '
        'parent_id INTEGER REFERENCES parent(id))');

    final cols = await session.schema
        .columns(const TableInfo(name: 'child', kind: ObjectKind.table));
    final byName = {for (final c in cols) c.name: c};
    expect(byName['parent_id']!.isForeignKey, isTrue);
    expect(byName['id']!.isForeignKey, isFalse);
    expect(byName['id']!.isPrimaryKey, isTrue);

    // The target, not just the fact of a reference.
    expect(byName['parent_id']!.references?.table, 'parent');
    expect(byName['parent_id']!.references?.column, 'id');
    expect(byName['id']!.references, isNull);
  });

  test('a FK without an explicit parent column targets the primary key',
      () async {
    await session.execute('CREATE TABLE p (id INTEGER PRIMARY KEY)');
    // No "(id)" — SQLite reports `to` as NULL, meaning the parent's PK.
    await session.execute(
        'CREATE TABLE c (id INTEGER PRIMARY KEY, p_id INTEGER REFERENCES p)');

    final cols = await session.schema
        .columns(const TableInfo(name: 'c', kind: ObjectKind.table));
    final ref = cols.firstWhere((c) => c.name == 'p_id').references;
    expect(ref?.table, 'p');
    expect(ref?.column, isNotEmpty);
  });

  test('introspection lists indexes with columns and uniqueness', () async {
    await session.execute(
        'CREATE TABLE t (id INTEGER PRIMARY KEY, a TEXT, b TEXT)');
    await session.execute('CREATE INDEX ix_a ON t (a)');
    await session.execute('CREATE UNIQUE INDEX ux_ab ON t (a, b)');

    final ix = await session.schema
        .indexes(const TableInfo(name: 't', kind: ObjectKind.table));
    final byName = {for (final i in ix) i.name: i};

    expect(byName['ix_a']!.columns, ['a']);
    expect(byName['ix_a']!.unique, isFalse);
    expect(byName['ux_ab']!.columns, ['a', 'b']); // multi-column order preserved
    expect(byName['ux_ab']!.unique, isTrue);
  });

  test('tableDdl returns the stored CREATE for a table and a view', () async {
    await session.execute(
        'CREATE TABLE users (id INTEGER PRIMARY KEY, email TEXT NOT NULL)');
    await session.execute('CREATE VIEW active AS SELECT id FROM users');

    final tableDdl = await session.schema
        .tableDdl(const TableInfo(name: 'users', kind: ObjectKind.table));
    expect(tableDdl, contains('CREATE TABLE users'));
    expect(tableDdl, contains('email TEXT NOT NULL'));
    expect(tableDdl, endsWith(';'));

    final viewDdl = await session.schema
        .tableDdl(const TableInfo(name: 'active', kind: ObjectKind.view));
    expect(viewDdl, contains('CREATE VIEW active'));
  });

  test('indexDdl returns stored SQL, and reconstructs auto-indexes', () async {
    await session.execute(
        'CREATE TABLE t (id INTEGER PRIMARY KEY, a TEXT UNIQUE, b TEXT)');
    await session.execute('CREATE INDEX ix_b ON t (b)');

    final ix = await session.schema
        .indexes(const TableInfo(name: 't', kind: ObjectKind.table));
    final explicit = ix.firstWhere((i) => i.name == 'ix_b');
    final auto = ix.firstWhere((i) => i.name != 'ix_b'); // from UNIQUE(a)

    const t = TableInfo(name: 't', kind: ObjectKind.table);
    expect(await session.schema.indexDdl(t, explicit),
        contains('CREATE INDEX ix_b ON t (b)'));

    // Auto-index has no stored SQL → synthesized with a note.
    final autoDdl = await session.schema.indexDdl(t, auto);
    expect(autoDdl, contains('Auto-created index'));
    expect(autoDdl, contains('UNIQUE INDEX'));
    expect(autoDdl, contains('"a"'));
  });

  test('foreign keys are enforced (the pragma defaults OFF)', () async {
    await session.execute('CREATE TABLE parent (id INTEGER PRIMARY KEY)');
    await session.execute('CREATE TABLE child ('
        'id INTEGER PRIMARY KEY, '
        'parent_id INTEGER REFERENCES parent(id))');
    await session.execute('INSERT INTO parent (id) VALUES (1)');

    // A valid reference is fine...
    await session.execute('INSERT INTO child (id, parent_id) VALUES (1, 1)');

    // ...and a dangling one must be refused. Without `PRAGMA foreign_keys=ON`
    // SQLite accepts this silently, so a grid edit pointing at a row that
    // doesn't exist would be written without complaint.
    await expectLater(
      () => session.execute('INSERT INTO child (id, parent_id) VALUES (2, 999)'),
      throwsA(isA<DriverError>()),
    );
  });

  test('tableStats sizes the table but never estimates rows', () async {
    await session.execute('CREATE TABLE t (id INTEGER PRIMARY KEY, a TEXT)');
    await session.execute("INSERT INTO t (a) VALUES ('x'), ('y')");

    final stats = await session.schema
        .tableStats(const TableInfo(name: 't', kind: ObjectKind.table));

    // SQLite keeps no row estimate, and producing one would mean the full scan
    // this method exists to avoid.
    expect(stats.estimatedRows, isNull);
    // Size, though, comes free from the dbstat module (present in the bundled
    // library) — it sums the pages the table actually occupies.
    expect(stats.totalBytes, isNotNull);
    expect(stats.totalBytes, greaterThan(0));
  });

  test('rowCount is exact, and separate from tableStats', () async {
    await session.execute('CREATE TABLE t (id INTEGER PRIMARY KEY)');
    await session.execute('INSERT INTO t (id) VALUES (1), (2), (3)');

    final n = await session.schema
        .rowCount(const TableInfo(name: 't', kind: ObjectKind.table));
    expect(n, 3);
  });

  test('rowCount quotes the table name', () async {
    await session.execute('CREATE TABLE "odd name" (id INTEGER)');
    await session.execute('INSERT INTO "odd name" VALUES (1)');
    expect(
      await session.schema
          .rowCount(const TableInfo(name: 'odd name', kind: ObjectKind.table)),
      1,
    );
  });

  test('referencedBy finds inbound foreign keys', () async {
    await session.execute('CREATE TABLE customers (id INTEGER PRIMARY KEY)');
    await session.execute('CREATE TABLE orders ('
        'id INTEGER PRIMARY KEY, '
        'customer_id INTEGER REFERENCES customers(id))');
    await session.execute('CREATE TABLE notes ('
        'id INTEGER PRIMARY KEY, '
        'about INTEGER REFERENCES customers(id))');

    // The inverse of ColumnInfo.references: what depends on this table. There
    // is no other way to answer that from the UI.
    final inbound = await session.schema
        .referencedBy(const TableInfo(name: 'customers', kind: ObjectKind.table));
    final described = inbound.map((r) => '${r.table}.${r.column}').toSet();
    expect(described, {'orders.customer_id', 'notes.about'});
  });

  test('referencedBy is empty for a table nothing points at', () async {
    await session.execute('CREATE TABLE lonely (id INTEGER PRIMARY KEY)');
    expect(
      await session.schema
          .referencedBy(const TableInfo(name: 'lonely', kind: ObjectKind.table)),
      isEmpty,
    );
  });

  test('a self-referencing table does not report itself', () async {
    // Walking every table would otherwise list the table's own FK as inbound,
    // which is true but useless noise in a "what depends on this" list.
    await session.execute('CREATE TABLE tree ('
        'id INTEGER PRIMARY KEY, parent INTEGER REFERENCES tree(id))');
    expect(
      await session.schema
          .referencedBy(const TableInfo(name: 'tree', kind: ObjectKind.table)),
      isEmpty,
    );
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
