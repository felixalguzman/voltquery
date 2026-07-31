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
}
