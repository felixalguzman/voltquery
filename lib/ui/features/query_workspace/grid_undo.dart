import '../../../domain/drivers/result.dart';
import '../../../domain/sql/dml_builder.dart';
import '../../../domain/sql/sql_statement_splitter.dart';
import 'grid_edit_buffer.dart';
import 'grid_editability.dart';

/// The inverse of an applied batch of grid edits.
///
/// Review & Apply is a one-way door today, and this session put `DELETE` behind
/// it. Two of the three kinds are exactly reversible from what the buffer
/// already holds — an UPDATE's previous values, and a deleted row as it was
/// read — so the door can swing back.
///
/// A new row is the exception and is **not** recoverable: its primary key was
/// assigned by the engine, we never learned it, and deleting by the values we
/// did supply could match a row somebody else inserted. [complete] says so, and
/// the UI repeats it rather than implying the undo was total.
class GridUndo {
  const GridUndo({
    required this.statements,
    required this.complete,
    required this.insertCount,
  });

  /// Statements that put the table back, in the order they must run.
  final List<String> statements;

  /// False when the applied batch contained rows this cannot bring back.
  final bool complete;

  /// How many new rows were applied and so cannot be undone.
  final int insertCount;

  bool get isEmpty => statements.isEmpty;

  /// What to tell the user before they run it.
  String get summary {
    final n = statements.length;
    final base = '$n statement${n == 1 ? '' : 's'}';
    if (complete) return '$base — restores the rows exactly as they were read.';
    return '$base. The $insertCount row${insertCount == 1 ? '' : 's'} you '
        'added cannot be removed this way: the database assigned their keys '
        'and we never saw them. Delete them by hand if you meant to.';
  }

  /// Builds the inverse of [buffer] — call **before** applying it, while the
  /// old values are still the ones on screen.
  ///
  /// Order mirrors the forward pass in reverse intent: re-insert what was
  /// deleted first (so a unique key it held is free again only after), then put
  /// updated values back. [pkValuesFor] and [rows] are the same ones the
  /// forward statements were built from, so the two describe the same rows.
  static GridUndo of({
    required GridEditBuffer buffer,
    required GridEditability editability,
    required SqlDialect dialect,
    required List<ResultField> fields,
    required List<ResultRow> rows,
    required Map<String, Object?>? Function(int rowIndex) pkValuesFor,
  }) {
    final builder = DmlBuilder(dialect);
    final statements = <String>[];

    // A deleted row comes back whole, values exactly as read. Its own primary
    // key is included: putting it back under a different one would be a
    // different row.
    for (final rowIndex in buffer.deletes.toList()..sort()) {
      if (rowIndex < 0 || rowIndex >= rows.length) continue;
      final cells = <CellEdit>[];
      for (var i = 0; i < fields.length; i++) {
        final editor = editability.editorFor(fields[i].name);
        if (editor == null) continue; // an expression, not a column
        cells.add(CellEdit(fields[i].name, rows[rowIndex].values[i], editor));
      }
      final sql = builder.insert(editability.target, cells);
      if (sql != null) statements.add(sql);
    }

    // An edited row goes back to the values it was read with — which is what
    // `StagedEdit.oldValue` holds, deliberately kept across re-edits.
    final byRow = <int, List<StagedEdit>>{};
    for (final e in buffer.edits.values) {
      byRow.putIfAbsent(e.rowIndex, () => []).add(e);
    }
    for (final rowIndex in byRow.keys.toList()..sort()) {
      final keys = pkValuesFor(rowIndex);
      if (keys == null || keys.isEmpty) continue;
      final cells = [
        for (final e in byRow[rowIndex]!)
          if (editability.editorFor(e.column) case final editor?)
            CellEdit(e.column, e.oldValue, editor),
      ];
      final sql = builder.update(editability.target, cells, RowIdentity(keys));
      if (sql != null) statements.add(sql);
    }

    // Only rows that actually produced an INSERT are unrecoverable; one the
    // user added and never typed into never reached the database.
    final applied = buffer.inserts.where((r) => r.values.isNotEmpty).length;
    return GridUndo(
      statements: statements,
      complete: applied == 0,
      insertCount: applied,
    );
  }
}
