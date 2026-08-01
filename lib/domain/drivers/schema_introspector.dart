import '../models/schema.dart';

/// The **one place** engine-specific catalog queries live (`pg_catalog` /
/// `information_schema` / `sqlite_master`+PRAGMA), returning **canonical**
/// hierarchy nodes so the schema tree consumes one shape (ADR-0001).
///
/// Provided by a [Driver]'s introspection [Session]. The schema browser runs it
/// on a dedicated **per-Connection** Session, not a per-Worksheet one (ADR-0008),
/// so catalog reads never ride a user's transaction.
abstract interface class SchemaIntrospector {
  Future<List<DatabaseInfo>> databases();

  /// Empty / single-element where `Capabilities.hasSchemas` is false.
  Future<List<SchemaInfo>> schemas(DatabaseInfo database);

  /// Tables **and** views, distinguished by `TableInfo.kind`.
  Future<List<TableInfo>> tables(SchemaInfo schema);

  Future<List<ColumnInfo>> columns(TableInfo table);

  Future<List<IndexInfo>> indexes(TableInfo table);

  /// The `CREATE` statement for [table] (a table or a view), for the node
  /// context menu's "Copy CREATE" (#53). Best-effort per engine: SQLite/MySQL
  /// return the engine's own DDL; Postgres reconstructs tables from the catalog
  /// (its columns/types/PK) since it exposes no `pg_get_tabledef`, and uses
  /// `pg_get_viewdef` for views. Never throws for a missing definition — returns
  /// a `--`-commented note instead so the clipboard is always meaningful.
  Future<String> tableDdl(TableInfo table);

  /// Cheap statistics for [table] — estimated rows, on-disk size, comment.
  ///
  /// Must stay **catalog-only**: this runs when a user opens an info dialog, so
  /// it may not scan the table. Engines that keep no estimate return the fields
  /// they can and leave the rest null rather than counting rows.
  Future<TableStats> tableStats(TableInfo table);

  /// An exact `count(*)`. Separate from [tableStats] because on a large table
  /// this is a full scan, and the caller should be the one deciding to pay for
  /// it.
  Future<int> rowCount(TableInfo table);

  /// The `CREATE INDEX` statement for [index] on [table] ("Copy CREATE" on an
  /// index node, #53). Postgres uses `pg_get_indexdef`; SQLite reads
  /// `sqlite_master` (auto-indexes have no stored SQL → reconstructed);
  /// MySQL reconstructs from the index's columns.
  Future<String> indexDdl(TableInfo table, IndexInfo index);
}
