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

/// What a foreign-key column points at.
class ColumnRef {
  const ColumnRef({required this.table, required this.column, this.schema = ''});

  final String table;
  final String column;

  /// Owning schema/database of [table]; empty when unqualified.
  final String schema;

  @override
  String toString() =>
      '${schema.isEmpty ? '' : '$schema.'}$table.$column';
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
    this.enumOptions = const [],
    this.references,
  });

  final String name;
  final String dataType;
  final bool nullable;
  final bool isPrimaryKey;
  final bool isForeignKey;
  final int ordinal;
  final String? defaultValue;

  /// The permitted values when the column's type is an enumeration — a Postgres
  /// enum type (`pg_enum`) or a MySQL `enum(...)` column. Empty otherwise.
  /// Lets the grid offer a validating dropdown instead of free text.
  final List<String> enumOptions;

  /// The column this one references, when [isForeignKey].
  ///
  /// Knowing the *target* — not just that a FK exists — is what makes
  /// validating a value before sending it, offering a parent-row picker, and
  /// navigating to the referenced row possible.
  final ColumnRef? references;
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
