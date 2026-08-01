import '../../../domain/models/column_editor.dart';
import '../../../domain/models/engine.dart';
import '../../../domain/models/schema.dart';
import '../../../domain/sql/editable_result.dart';
import '../../../domain/sql/sql_statement_splitter.dart';
import '../schema_browser/schema_repository.dart';

/// Everything the result grid needs to write a row back: which table, how to
/// address a row (PK), and how to edit each column.
///
/// Absent (null) means the grid stays read-only — the SQL wasn't a plain
/// single-table SELECT, the table has no primary key, or its columns couldn't
/// be introspected.
class GridEditability {
  const GridEditability({
    required this.target,
    required this.primaryKey,
    required this.editors,
  });

  final EditableTarget target;

  /// PK column names, in schema order. Never empty — a table without one can't
  /// be addressed a row at a time, so it isn't editable at all.
  final List<String> primaryKey;

  /// Editor per **column name**, matched case-insensitively to result fields.
  /// A result field with no entry here (an expression, a renamed projection) is
  /// read-only.
  final Map<String, ColumnEditor> editors;

  /// The editor for a result field, or null when that field isn't a plain
  /// column of [target] and so can't be written back.
  ColumnEditor? editorFor(String fieldName) =>
      editors[fieldName.toLowerCase()];

  /// True when [fieldName] is part of the primary key. The UI marks these
  /// read-only: editing a PK in place would change the row's identity, and the
  /// staged UPDATE addresses the row *by* that value.
  bool isPrimaryKey(String fieldName) =>
      primaryKey.any((k) => k.toLowerCase() == fieldName.toLowerCase());
}

/// Resolves [GridEditability] for one result, pairing the SQL analysis with the
/// connection's schema cache.
///
/// The two halves are complementary: the analyzer says *which table* a result
/// came from, and that table's [ColumnInfo] supplies the PK and the real column
/// types — which the result's own [ResultField]s can't (SQLite and MySQL report
/// an empty projection type).
class GridEditabilityResolver {
  const GridEditabilityResolver({required this.engine, required this.repo});

  final Engine engine;
  final SchemaRepository repo;

  /// Best-effort: any failure (unknown table, introspection error) degrades to
  /// a read-only grid rather than surfacing an error — the user still has their
  /// results.
  Future<GridEditability?> resolve(String sql) async {
    final target = EditableResultAnalyzer(SqlDialect.of(engine)).analyze(sql);
    if (target == null) return null;

    final List<ColumnInfo> columns;
    try {
      columns = await repo.columns(TableInfo(
        name: target.table,
        kind: ObjectKind.table,
        schema: target.schema,
      ));
    } catch (_) {
      return null; // not introspectable → stay read-only
    }
    if (columns.isEmpty) return null;

    final pk = [for (final c in columns) if (c.isPrimaryKey) c.name];
    // No PK → no way to address a single row safely.
    if (pk.isEmpty) return null;

    final resolver = ColumnEditorResolver(engine);
    return GridEditability(
      target: target,
      primaryKey: pk,
      editors: {
        for (final c in columns)
          c.name.toLowerCase(): resolver.resolve(
            c.dataType,
            nullable: c.nullable,
            enumOptions: c.enumOptions,
          ),
      },
    );
  }
}
