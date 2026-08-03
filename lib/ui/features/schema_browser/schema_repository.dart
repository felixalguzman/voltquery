import '../../../domain/drivers/schema_introspector.dart';
import '../../../domain/models/capabilities.dart';
import '../../../domain/models/schema.dart';

/// The **single per-Connection cache** behind the lazy schema tree (ADR-0008).
///
/// One entry per parent-ref (`schemas`, `tables:<schema>`, `cols:<schema>.<table>`);
/// each miss delegates to the connection's [SchemaIntrospector] and the result is
/// memoized for the connection's lifetime. Nothing is fetched until asked — the
/// tree drives every call from an `onExpandToggle`, so a connect never walks the
/// whole catalog. Not persisted (a stored catalog goes stale between runs).
///
/// The cached value is the **Future**, so concurrent expands of the same node
/// share one round-trip. A failed fetch evicts its key so a retry re-fetches.
class SchemaRepository {
  SchemaRepository({required this.introspector, required this.capabilities});

  final SchemaIntrospector introspector;
  final Capabilities capabilities;

  final Map<String, Future<List<SchemaInfo>>> _schemas = {};
  final Map<String, Future<List<TableInfo>>> _tables = {};
  final Map<String, Future<List<ColumnInfo>>> _columns = {};
  final Map<String, Future<List<IndexInfo>>> _indexes = {};
  final Map<String, Future<String>> _ddl = {};
  final Map<String, Future<TableStats>> _stats = {};
  final Map<String, Future<List<ColumnRef>>> _inbound = {};

  /// Top-level schemas (Postgres). Empty where `!capabilities.hasSchemas`.
  Future<List<SchemaInfo>> schemas() => _memo(
    _schemas,
    'schemas',
    () => introspector.schemas(const DatabaseInfo('')),
  );

  /// Tables **and** views of [schema] in one call; the caller partitions on
  /// [TableInfo.kind]. Keyed by schema name (empty for SQLite/MySQL).
  Future<List<TableInfo>> tables(SchemaInfo schema) =>
      _memo(_tables, schema.name, () => introspector.tables(schema));

  Future<List<ColumnInfo>> columns(TableInfo table) => _memo(
    _columns,
    '${table.schema} ${table.name}',
    () => introspector.columns(table),
  );

  Future<List<IndexInfo>> indexes(TableInfo table) => _memo(
    _indexes,
    '${table.schema} ${table.name}',
    () => introspector.indexes(table),
  );

  /// The `CREATE` DDL for a table/view — backs "Copy CREATE" (#53). Cached like
  /// the rest; keyed apart from the index DDL by a `t:` prefix.
  Future<String> tableDdl(TableInfo table) => _memo(
    _ddl,
    't:${table.schema} ${table.name}',
    () => introspector.tableDdl(table),
  );

  /// The `CREATE INDEX` DDL for an index — "Copy CREATE" on an index node (#53).
  Future<String> indexDdl(TableInfo table, IndexInfo index) => _memo(
    _ddl,
    'i:${table.schema} ${table.name} ${index.name}',
    () => introspector.indexDdl(table, index),
  );

  /// Cheap catalog statistics for the table-info dialog. Cached like the rest —
  /// reopening the dialog shouldn't re-query.
  Future<TableStats> stats(TableInfo table) => _memo(
    _stats,
    '${table.schema} ${table.name}',
    () => introspector.tableStats(table),
  );

  /// Columns elsewhere whose FKs point at this table — what depends on it.
  Future<List<ColumnRef>> referencedBy(TableInfo table) => _memo(
    _inbound,
    '${table.schema} ${table.name}',
    () => introspector.referencedBy(table),
  );

  /// An exact `count(*)`. **Not** memoized: the caller asked for a fresh count,
  /// and a cached one would defeat the point of asking.
  Future<int> rowCount(TableInfo table) => introspector.rowCount(table);

  /// Catalog search for the global dialog. **Not memoized** — the cache here is
  /// keyed by parent node, and a search is keyed by a string the user is still
  /// typing; caching it would only grow an unbounded map of dead queries.
  Future<List<SchemaSearchHit>> search(
    String pattern, {
    int limit = 200,
    SearchScope scope = SearchScope.all,
  }) => introspector.search(pattern, limit: limit, scope: scope);

  /// Whole-connection evict — the "Refresh connection" action. Coarse by design
  /// (see `docs/design/schema-tree.md`); lazy re-fetch pays the cost per expand.
  void invalidate() {
    _schemas.clear();
    _tables.clear();
    _columns.clear();
    _indexes.clear();
    _ddl.clear();
    _stats.clear();
    _inbound.clear();
  }

  /// Memoize the *future*; evict the key if it rejects so a retry re-fetches.
  /// [T] is the future's value type (a `List<…>` for catalog reads, a `String`
  /// for DDL).
  Future<T> _memo<T>(
    Map<String, Future<T>> cache,
    String key,
    Future<T> Function() fetch,
  ) {
    return cache.putIfAbsent(key, () {
      final future = fetch();
      // Side-branch: drop the poisoned entry. The awaiter still sees the error.
      // Block body (not `=>`) so we don't return the removed rejected future.
      future.then<void>(
        (_) {},
        onError: (Object _) {
          cache.remove(key);
        },
      );
      return future;
    });
  }
}
