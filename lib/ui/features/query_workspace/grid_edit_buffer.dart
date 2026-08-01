import '../../../domain/sql/dml_builder.dart';
import '../../../domain/sql/sql_statement_splitter.dart';
import 'grid_editability.dart';

/// One staged cell change, before it becomes SQL.
class StagedEdit {
  const StagedEdit({
    required this.rowIndex,
    required this.column,
    required this.oldValue,
    required this.newValue,
  });

  /// Index into the rendered result rows — identifies which row's PK to use.
  final int rowIndex;
  final String column;
  final Object? oldValue;
  final Object? newValue;
}

/// The pending edits for one result grid: nothing touches the database until
/// [toSql] is reviewed and committed.
///
/// Staging rather than write-on-blur is the whole safety model — it's what lets
/// the user see the exact statements first (TablePlus's "Code Review", the most
/// praised feature of that tool) and what makes a mistaken keystroke free to
/// undo.
class GridEditBuffer {
  const GridEditBuffer({this.edits = const {}});

  /// Keyed `rowIndex:column` so re-editing the same cell replaces rather than
  /// stacks, and so per-row grouping is cheap.
  final Map<String, StagedEdit> edits;

  bool get isEmpty => edits.isEmpty;
  bool get isNotEmpty => edits.isNotEmpty;
  int get count => edits.length;

  static String keyOf(int rowIndex, String column) => '$rowIndex:$column';

  StagedEdit? at(int rowIndex, String column) =>
      edits[keyOf(rowIndex, column)];

  bool isDirty(int rowIndex, String column) =>
      edits.containsKey(keyOf(rowIndex, column));

  /// Stage a change. Setting a cell back to the value it was read with **drops**
  /// the entry — editing A→B→A leaves nothing pending, so the review panel never
  /// shows a no-op UPDATE.
  GridEditBuffer stage(StagedEdit edit) {
    final next = Map<String, StagedEdit>.from(edits);
    final key = keyOf(edit.rowIndex, edit.column);
    // Compare against the *original* value, which is the one already staged if
    // this cell has been edited before.
    final original = next[key]?.oldValue ?? edit.oldValue;
    if (_same(original, edit.newValue)) {
      next.remove(key);
    } else {
      next[key] = StagedEdit(
        rowIndex: edit.rowIndex,
        column: edit.column,
        oldValue: original,
        newValue: edit.newValue,
      );
    }
    return GridEditBuffer(edits: next);
  }

  GridEditBuffer discardCell(int rowIndex, String column) =>
      GridEditBuffer(edits: {...edits}..remove(keyOf(rowIndex, column)));

  GridEditBuffer clear() => const GridEditBuffer();

  /// NULL and the empty string are deliberately distinct here.
  static bool _same(Object? a, Object? b) {
    if (a == null || b == null) return a == null && b == null;
    return '$a' == '$b';
  }

  /// The statements these edits become — one `UPDATE` per touched row, in row
  /// order, each PK-qualified.
  ///
  /// [pkValuesFor] supplies a row's primary-key values **as they were read**;
  /// returning null for a row skips it (it can't be addressed safely).
  List<String> toSql({
    required GridEditability editability,
    required SqlDialect dialect,
    required Map<String, Object?>? Function(int rowIndex) pkValuesFor,
  }) {
    final builder = DmlBuilder(dialect);
    final byRow = <int, List<StagedEdit>>{};
    for (final e in edits.values) {
      byRow.putIfAbsent(e.rowIndex, () => []).add(e);
    }

    final statements = <String>[];
    for (final rowIndex in byRow.keys.toList()..sort()) {
      final keys = pkValuesFor(rowIndex);
      if (keys == null || keys.isEmpty) continue;
      final cells = [
        for (final e in byRow[rowIndex]!)
          if (editability.editorFor(e.column) case final editor?)
            CellEdit(e.column, e.newValue, editor),
      ];
      final sql = builder.update(
        editability.target,
        cells,
        RowIdentity(keys),
      );
      if (sql != null) statements.add(sql);
    }
    return statements;
  }
}
