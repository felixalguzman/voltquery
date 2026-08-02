import 'package:flutter_test/flutter_test.dart';
import 'package:voltquery/data/drivers/sqlite/sqlite_driver.dart';
import 'package:voltquery/domain/drivers/driver.dart';
import 'package:voltquery/domain/drivers/schema_introspector.dart';
import 'package:voltquery/domain/models/connection.dart';
import 'package:voltquery/domain/models/engine.dart';
import 'package:voltquery/domain/models/schema.dart';

/// The catalog search behind the global dialog. Live against a real in-memory
/// SQLite — the point of this method is the SQL, so a fake would test nothing.
void main() {
  late Session session;
  late SchemaIntrospector introspector;

  setUp(() async {
    session = await SqliteDriver().connect(
      const Connection(
        id: 't',
        name: 'mem',
        engine: Engine.sqlite,
        sqlitePath: ':memory:',
      ),
    );
    for (final ddl in [
      'CREATE TABLE ven_factura (id INTEGER PRIMARY KEY, '
          'secuencia_factura TEXT, total REAL)',
      'CREATE TABLE ven_factura_detalle (id INTEGER PRIMARY KEY, '
          'factura_id INTEGER, cantidad INTEGER)',
      'CREATE TABLE customers (id INTEGER PRIMARY KEY, email TEXT)',
      'CREATE VIEW factura_view AS SELECT * FROM ven_factura',
    ]) {
      await session.execute(ddl);
    }
    introspector = session.schema;
  });

  tearDown(() async => session.close());

  test('finds tables by substring, not just prefix', () async {
    final hits = await introspector.search('factura');
    final tables = hits.where((h) => h.kind == SchemaHitKind.table);

    expect(
      tables.map((h) => h.name),
      containsAll(['ven_factura', 'ven_factura_detalle']),
    );
  });

  test('distinguishes views from tables', () async {
    final hits = await introspector.search('factura_view');
    expect(hits.single.kind, SchemaHitKind.view);
    expect(hits.single.table.kind, ObjectKind.view);
  });

  test('finds columns in tables that were never expanded', () async {
    // The whole point: this table has not been introspected, and its column
    // still turns up.
    final hits = await introspector.search('secuencia');

    final columns = hits.where((h) => h.isColumn).toList();
    // Two hits, and both are right: the view selects * from the table, so it
    // exposes the same column and is just as valid a place to find it.
    expect(columns.map((c) => c.table.name),
        containsAll(['ven_factura', 'factura_view']));

    final onTable = columns.firstWhere((c) => c.table.name == 'ven_factura');
    expect(onTable.name, 'secuencia_factura');
    expect(onTable.dataType, 'TEXT');
  });

  test('matches case-insensitively', () async {
    final hits = await introspector.search('CUSTOMERS');
    expect(hits.map((h) => h.name), contains('customers'));
  });

  test('underscores are literal, not LIKE wildcards', () async {
    // `ven_factura` must not also match a hypothetical `venXfactura`. Prove the
    // escaping holds by searching a pattern that would over-match unescaped.
    await session.execute('CREATE TABLE venXfactura (id INTEGER)');

    final hits = await introspector.search('ven_factura');

    expect(hits.map((h) => h.name), isNot(contains('venXfactura')));
    expect(hits.map((h) => h.name), contains('ven_factura'));
  });

  test('percent signs are literal too', () async {
    // An unescaped '%' would match every object in the database.
    final hits = await introspector.search('%');
    expect(hits, isEmpty);
  });

  test('excludes sqlite internal tables', () async {
    await session.execute(
        'CREATE TABLE t (id INTEGER PRIMARY KEY AUTOINCREMENT)');
    final hits = await introspector.search('sqlite');
    expect(hits, isEmpty);
  });

  test('an empty pattern searches for nothing rather than everything',
      () async {
    expect(await introspector.search(''), isEmpty);
    expect(await introspector.search('   '), isEmpty);
  });

  test('the limit caps the whole result, objects first', () async {
    final hits = await introspector.search('a', limit: 2);
    expect(hits, hasLength(lessThanOrEqualTo(2)));
  });

  group('scope', () {
    test('objects skips columns entirely', () async {
      final hits =
          await introspector.search('factura', scope: SearchScope.objects);
      expect(hits.any((h) => h.isColumn), isFalse);
      expect(hits, isNotEmpty);
    });

    test('columns skips tables entirely', () async {
      final hits =
          await introspector.search('factura', scope: SearchScope.columns);
      expect(hits.every((h) => h.isColumn), isTrue);
      expect(hits, isNotEmpty);
    });

    test('columns-only rescues hits the shared limit would have eaten',
        () async {
      // The limit is shared and objects go first, so a pattern matching many
      // table names can spend the whole budget before a column is considered.
      // This is why scope is a query parameter and not a filter on the way out.
      final mixed = await introspector.search('factura', limit: 2);
      expect(mixed.any((h) => h.isColumn), isFalse,
          reason: 'tables filled the budget');

      final scoped = await introspector.search('factura',
          limit: 2, scope: SearchScope.columns);
      expect(scoped.any((h) => h.isColumn), isTrue,
          reason: 'scoping is what makes the column reachable');
    });
  });
}
