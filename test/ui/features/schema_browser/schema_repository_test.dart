import 'package:flutter_test/flutter_test.dart';
import 'package:voltquery/domain/drivers/driver_error.dart';
import 'package:voltquery/domain/drivers/schema_introspector.dart';
import 'package:voltquery/domain/models/capabilities.dart';
import 'package:voltquery/domain/models/schema.dart';
import 'package:voltquery/ui/features/schema_browser/schema_repository.dart';

/// Counts every call so we can prove the repository memoizes (one round-trip per
/// parent-ref) and re-fetches after invalidation / failure.
class _FakeIntrospector implements SchemaIntrospector {
  int schemaCalls = 0;
  int tableCalls = 0;
  int columnCalls = 0;
  int indexCalls = 0;
  int tableDdlCalls = 0;
  int statsCalls = 0;
  int rowCountCalls = 0;
  int indexDdlCalls = 0;
  bool failColumns = false;

  @override
  Future<List<DatabaseInfo>> databases() async => const [DatabaseInfo('db')];

  @override
  Future<List<SchemaInfo>> schemas(DatabaseInfo database) async {
    schemaCalls++;
    return const [SchemaInfo('public'), SchemaInfo('audit')];
  }

  @override
  Future<List<TableInfo>> tables(SchemaInfo schema) async {
    tableCalls++;
    return [
      TableInfo(name: 'orders', kind: ObjectKind.table, schema: schema.name),
      TableInfo(name: 'order_view', kind: ObjectKind.view, schema: schema.name),
    ];
  }

  @override
  Future<List<ColumnInfo>> columns(TableInfo table) async {
    columnCalls++;
    if (failColumns) {
      throw DriverError(DriverErrorKind.connectionFailed, 'boom');
    }
    return const [
      ColumnInfo(
          name: 'id',
          dataType: 'int',
          nullable: false,
          isPrimaryKey: true,
          isForeignKey: false,
          ordinal: 0),
    ];
  }

  @override
  Future<List<IndexInfo>> indexes(TableInfo table) async {
    indexCalls++;
    return const [
      IndexInfo(name: 'ix_a', columns: ['a'], unique: false),
    ];
  }

  @override
  Future<String> tableDdl(TableInfo table) async {
    tableDdlCalls++;
    return 'CREATE TABLE ${table.name} ()';
  }

  @override
  Future<List<ColumnRef>> referencedBy(TableInfo table) async =>
      const [ColumnRef(table: 'orders', column: 'customer_id')];

  @override
  Future<TableStats> tableStats(TableInfo table) async {
    statsCalls++;
    return const TableStats(estimatedRows: 42);
  }

  @override
  Future<int> rowCount(TableInfo table) async {
    rowCountCalls++;
    return 42;
  }

  @override
  Future<String> indexDdl(TableInfo table, IndexInfo index) async {
    indexDdlCalls++;
    return 'CREATE INDEX ${index.name} ON ${table.name} ()';
  }
}

const _pgCaps = Capabilities(
  hasServer: true,
  hasSchemas: true,
  supportsTls: true,
  verifiesTlsCertificates: true,
  supportsQueryCancel: false,
  supportsSavepoints: true,
  supportsNestedTransactions: false,
  paramStyle: ParamStyle.dollar,
);

void main() {
  late _FakeIntrospector fake;
  late SchemaRepository repo;

  setUp(() {
    fake = _FakeIntrospector();
    repo = SchemaRepository(introspector: fake, capabilities: _pgCaps);
  });

  test('memoizes each parent-ref — one introspector call per key', () async {
    await repo.schemas();
    await repo.schemas();
    expect(fake.schemaCalls, 1);

    await repo.tables(const SchemaInfo('public'));
    await repo.tables(const SchemaInfo('public'));
    expect(fake.tableCalls, 1);

    // A different schema is a different key → its own fetch.
    await repo.tables(const SchemaInfo('audit'));
    expect(fake.tableCalls, 2);
  });

  test('columns cache is keyed by schema + table, not table alone', () async {
    const pub = TableInfo(name: 'orders', kind: ObjectKind.table, schema: 'public');
    const aud = TableInfo(name: 'orders', kind: ObjectKind.table, schema: 'audit');
    await repo.columns(pub);
    await repo.columns(pub);
    expect(fake.columnCalls, 1);
    await repo.columns(aud); // same name, other schema → distinct entry
    expect(fake.columnCalls, 2);
  });

  test('indexes are memoized per table and cleared by invalidate', () async {
    const t = TableInfo(name: 'orders', kind: ObjectKind.table, schema: 'public');
    await repo.indexes(t);
    await repo.indexes(t);
    expect(fake.indexCalls, 1);
    repo.invalidate();
    await repo.indexes(t);
    expect(fake.indexCalls, 2);
  });

  test('DDL is memoized (table + index keyed apart) and cleared by invalidate',
      () async {
    const t = TableInfo(name: 'orders', kind: ObjectKind.table, schema: 'public');
    const ix = IndexInfo(name: 'ix_a', columns: ['a'], unique: false);

    await repo.tableDdl(t);
    await repo.tableDdl(t);
    expect(fake.tableDdlCalls, 1); // memoized

    await repo.indexDdl(t, ix);
    await repo.indexDdl(t, ix);
    expect(fake.indexDdlCalls, 1); // distinct key, also memoized

    repo.invalidate();
    await repo.tableDdl(t);
    await repo.indexDdl(t, ix);
    expect(fake.tableDdlCalls, 2);
    expect(fake.indexDdlCalls, 2);
  });

  test('tables() returns both kinds for the caller to partition', () async {
    final all = await repo.tables(const SchemaInfo('public'));
    expect(all.where((t) => t.kind == ObjectKind.table).map((t) => t.name),
        ['orders']);
    expect(all.where((t) => t.kind == ObjectKind.view).map((t) => t.name),
        ['order_view']);
  });

  test('invalidate() clears every level → next read re-fetches', () async {
    await repo.schemas();
    await repo.tables(const SchemaInfo('public'));
    repo.invalidate();
    await repo.schemas();
    await repo.tables(const SchemaInfo('public'));
    expect(fake.schemaCalls, 2);
    expect(fake.tableCalls, 2);
  });

  test('a failed fetch is not cached — a retry re-fetches', () async {
    fake.failColumns = true;
    const t = TableInfo(name: 'orders', kind: ObjectKind.table, schema: 'public');
    await expectLater(repo.columns(t), throwsA(isA<DriverError>()));

    fake.failColumns = false;
    final cols = await repo.columns(t); // retry succeeds, not the poisoned entry
    expect(cols.single.name, 'id');
    expect(fake.columnCalls, 2);
  });

  test('stats are memoized, but an exact row count never is', () async {
    const t = TableInfo(name: 'orders', kind: ObjectKind.table, schema: 'public');

    await repo.stats(t);
    await repo.stats(t);
    expect(fake.statsCalls, 1);

    // Asking for an exact count means asking *now* — serving a cached number
    // would defeat the point of the button that triggers it.
    await repo.rowCount(t);
    await repo.rowCount(t);
    expect(fake.rowCountCalls, 2);

    repo.invalidate();
    await repo.stats(t);
    expect(fake.statsCalls, 2);
  });
}
