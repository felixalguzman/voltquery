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
  Future<List<IndexInfo>> indexes(TableInfo table) async => const [];
}

const _pgCaps = Capabilities(
  hasServer: true,
  hasSchemas: true,
  supportsTls: true,
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
}
