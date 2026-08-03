import '../models/column_editor.dart';
import 'editable_result.dart';
import 'sql_statement_splitter.dart';

/// A single staged cell edit: [column] gets [value] (null = SQL NULL).
class CellEdit {
  const CellEdit(this.column, this.value, this.editor);

  final String column;
  final Object? value;

  /// Drives literal encoding — a boolean is `TRUE` on Postgres but `1` on
  /// MySQL/SQLite, and a JSON value must not be double-escaped.
  final ColumnEditor editor;
}

/// How to address exactly one existing row: the primary-key columns and the
/// values they had **when the row was read**.
///
/// Keyed on the PK rather than on all columns — the latter would fail on any
/// row containing a float or a value the driver round-trips imperfectly. A
/// table with no PK is not editable at all (the caller checks [isEmpty]).
class RowIdentity {
  const RowIdentity(this.keys);

  /// PK column name -> original value. Ordered for stable SQL output.
  final Map<String, Object?> keys;

  bool get isEmpty => keys.isEmpty;
}

/// Builds the `UPDATE` / `INSERT` / `DELETE` a staged grid edit turns into.
///
/// Every statement is **single-row and PK-qualified** — that's the safety
/// contract behind showing the user generated SQL and letting them commit it.
/// Values are inlined as literals (not bound parameters) because the whole
/// point of the review panel is that the user sees the exact statement that
/// will run; the encoders below are therefore the security boundary.
class DmlBuilder {
  const DmlBuilder(this.dialect);

  final SqlDialect dialect;

  /// `UPDATE t SET a = 1 WHERE pk = 2` for one row. Returns null when [edits]
  /// is empty (nothing staged) — callers skip those rows.
  String? update(
    EditableTarget target,
    List<CellEdit> edits,
    RowIdentity identity,
  ) {
    if (edits.isEmpty) return null;
    _requireIdentity(identity);
    final sets = edits
        .map((e) => '${_ident(e.column)} = ${_literal(e.value, e.editor)}')
        .join(', ');
    return 'UPDATE ${_table(target)} SET $sets WHERE ${_where(identity)};';
  }

  /// `INSERT INTO t (a, b) VALUES (1, 'x')` for one new row. Columns the user
  /// left untouched are omitted so engine defaults / sequences still apply.
  String? insert(EditableTarget target, List<CellEdit> values) {
    if (values.isEmpty) return null;
    final cols = values.map((e) => _ident(e.column)).join(', ');
    final vals = values.map((e) => _literal(e.value, e.editor)).join(', ');
    return 'INSERT INTO ${_table(target)} ($cols) VALUES ($vals);';
  }

  /// `DELETE FROM t WHERE pk = 1` for one row.
  String delete(EditableTarget target, RowIdentity identity) {
    _requireIdentity(identity);
    return 'DELETE FROM ${_table(target)} WHERE ${_where(identity)};';
  }

  void _requireIdentity(RowIdentity identity) {
    if (identity.isEmpty) {
      // Guards the one mistake that silently rewrites a whole table.
      throw ArgumentError(
        'Refusing to build DML without a primary key — an unqualified '
        'UPDATE/DELETE would affect every row.',
      );
    }
  }

  /// PK predicate. Original values are encoded with a plain-text editor: PKs
  /// are ints/uuids/strings in practice, and we want the value exactly as read.
  String _where(RowIdentity identity) => identity.keys.entries
      .map(
        (e) => e.value == null
            ? '${_ident(e.key)} IS NULL'
            : '${_ident(e.key)} = ${_rawLiteral(e.value)}',
      )
      .join(' AND ');

  String _table(EditableTarget t) => dialect.qualify(t.table, schema: t.schema);

  /// Quote an identifier for the dialect. Shared with the schema tree's
  /// generated SELECTs so the two can't drift apart.
  String _ident(String name) => dialect.quoteIdentifier(name);

  /// Encode a staged value per its editor kind.
  String _literal(Object? value, ColumnEditor editor) {
    if (value == null) return 'NULL';
    return switch (editor.kind) {
      ColumnEditorKind.boolean => _boolLiteral(value),
      ColumnEditorKind.integer ||
      ColumnEditorKind.decimal => _numberLiteral(value),
      // JSON, dates and enums all travel as quoted strings; the engine casts.
      _ => _quote('$value'),
    };
  }

  /// Original PK values, encoded by runtime type (we have no editor for them).
  String _rawLiteral(Object? value) => switch (value) {
    null => 'NULL',
    bool b => _boolLiteral(b),
    num n => '$n',
    _ => _quote('$value'),
  };

  String _boolLiteral(Object value) {
    final truthy = switch (value) {
      bool b => b,
      num n => n != 0,
      _ => const {
        'true',
        't',
        '1',
        'yes',
        'y',
      }.contains('$value'.toLowerCase()),
    };
    // Postgres has real booleans; MySQL/SQLite store 0/1.
    if (dialect == SqlDialect.postgres) return truthy ? 'TRUE' : 'FALSE';
    return truthy ? '1' : '0';
  }

  /// Numbers are emitted bare — but only after proving the text really is a
  /// number, so a crafted cell value can't inject SQL through the "unquoted"
  /// path. Anything else falls back to a quoted literal and lets the engine
  /// reject it.
  String _numberLiteral(Object value) {
    if (value is num) return '$value';
    final text = '$value'.trim();
    if (text.isEmpty) return 'NULL';
    return num.tryParse(text) != null ? text : _quote(text);
  }

  /// Single-quoted string literal. Doubling the quote is the SQL-standard
  /// escape and is correct on all three engines; backslashes are additionally
  /// escaped on MySQL, which treats them specially by default.
  String _quote(String value) {
    final escaped = dialect == SqlDialect.mysql
        ? value.replaceAll(r'\', r'\\').replaceAll("'", "''")
        : value.replaceAll("'", "''");
    return "'$escaped'";
  }
}
