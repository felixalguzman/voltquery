/// Canonical schema-object nodes returned by [SchemaIntrospector].
///
/// One uniform shape across engines (ADR-0001); absent levels (e.g. Schema on
/// MySQL/SQLite) simply aren't populated. Tables and Views share [TableInfo],
/// distinguished by [ObjectKind] (ADR-0008 — no separate introspector method).
///
/// TODO(build): promote to `freezed` models once codegen is wired.
library;

class DatabaseInfo {
  const DatabaseInfo(this.name);
  final String name;
}

class SchemaInfo {
  const SchemaInfo(this.name);
  final String name;
}

enum ObjectKind { table, view }

class TableInfo {
  const TableInfo({required this.name, required this.kind, this.schema = ''});
  final String name;
  final ObjectKind kind;

  /// The owning schema's name (Postgres). Empty where the engine has no schema
  /// level (SQLite / MySQL). Carried so [SchemaIntrospector.columns] can qualify
  /// the lookup — two schemas may hold same-named tables.
  final String schema;
}

/// Durable schema metadata for a Table/View column — distinct from a
/// query-result `ResultField` (see `result.dart`).
class ColumnInfo {
  const ColumnInfo({
    required this.name,
    required this.dataType,
    required this.nullable,
    required this.isPrimaryKey,
    required this.isForeignKey,
    required this.ordinal,
    this.defaultValue,
  });

  final String name;
  final String dataType;
  final bool nullable;
  final bool isPrimaryKey;
  final bool isForeignKey;
  final int ordinal;
  final String? defaultValue;
}

class IndexInfo {
  const IndexInfo({
    required this.name,
    required this.columns,
    required this.unique,
  });

  final String name;
  final List<String> columns;
  final bool unique;
}
