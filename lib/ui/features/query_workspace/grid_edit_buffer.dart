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

/// A row the user is adding.
///
/// Tracked apart from [StagedEdit] rather than as "edits to row N": a new row
/// has no primary key and no place in the result, so none of the machinery that
/// addresses an existing row applies to it.
class PendingRow {
  const PendingRow({required this.id, this.values = const {}});

  /// Stable for the life of the buffer, and never reused. Rows are addressed by
  /// id rather than list position because discarding one shifts every later
  /// position — and the grid stores these ids in its own row keys.
  final int id;

  /// column -> value. A column **absent** here is omitted from the `INSERT`, so
  /// the engine's default or sequence still applies; a column present with a
  /// null value is a deliberate SQL NULL. That distinction is the whole reason
  /// this is a map with explicit membership rather than a full row of nulls.
  final Map<String, Object?> values;

  bool has(String column) => values.containsKey(column);

  PendingRow set(String column, Object? value) =>
      PendingRow(id: id, values: {...values, column: value});

  /// Back to "not specified" — which is different from setting it to NULL.
  PendingRow unset(String column) =>
      PendingRow(id: id, values: {...values}..remove(column));
}

/// The pending changes for one result grid: nothing touches the database until
/// [toSql] is reviewed and committed.
///
/// Staging rather than write-on-blur is the whole safety model — it's what lets
/// the user see the exact statements first (TablePlus's "Code Review", the most
/// praised feature of that tool) and what makes a mistaken keystroke free to
/// undo.
class GridEditBuffer {
  const GridEditBuffer({
    this.edits = const {},
    this.deletes = const {},
    this.inserts = const [],
    this.nextRowId = 1,
  });

  /// Keyed `rowIndex:column` so re-editing the same cell replaces rather than
  /// stacks, and so per-row grouping is cheap.
  final Map<String, StagedEdit> edits;

  /// Result-row indices staged for `DELETE`.
  final Set<int> deletes;

  /// New rows, in the order they were added.
  final List<PendingRow> inserts;

  /// Next id to hand a new row. Monotonic, so a discarded row's id can never be
  /// confused with a later row that took its slot in the list.
  final int nextRowId;

  bool get isEmpty => edits.isEmpty && deletes.isEmpty && inserts.isEmpty;
  bool get isNotEmpty => !isEmpty;

  /// What the status bar counts: every staged change, of any kind.
  int get count => edits.length + deletes.length + inserts.length;

  static String keyOf(int rowIndex, String column) => '$rowIndex:$column';

  StagedEdit? at(int rowIndex, String column) => edits[keyOf(rowIndex, column)];

  bool isDirty(int rowIndex, String column) =>
      edits.containsKey(keyOf(rowIndex, column));

  bool isDeleted(int rowIndex) => deletes.contains(rowIndex);

  PendingRow? pending(int id) {
    for (final r in inserts) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// A new row's cell as `(specified, value)`. The flag is what tells "the user
  /// set this to NULL" apart from "never touched" — only the former reaches the
  /// `INSERT`.
  (bool, Object?) pendingCell(int id, String column) {
    final row = pending(id);
    if (row == null || !row.has(column)) return (false, null);
    return (true, row.values[column]);
  }

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
    return _copy(edits: next);
  }

  GridEditBuffer discardCell(int rowIndex, String column) =>
      _copy(edits: {...edits}..remove(keyOf(rowIndex, column)));

  /// Mark a result row for deletion, or take the mark back.
  ///
  /// Staging a delete **drops that row's cell edits**: [toSql] emits the DELETE
  /// first, so a surviving UPDATE would match zero rows and quietly do nothing
  /// while still claiming a line in the review panel.
  GridEditBuffer toggleDelete(int rowIndex) {
    if (deletes.contains(rowIndex)) {
      return _copy(deletes: {...deletes}..remove(rowIndex));
    }
    return _copy(
      edits: {
        for (final e in edits.entries)
          if (e.value.rowIndex != rowIndex) e.key: e.value,
      },
      deletes: {...deletes, rowIndex},
    );
  }

  /// Append a new row, optionally pre-filled (that's how "duplicate row" works).
  GridEditBuffer addRow([Map<String, Object?> seed = const {}]) => _copy(
    inserts: [
      ...inserts,
      PendingRow(id: nextRowId, values: seed),
    ],
    nextRowId: nextRowId + 1,
  );

  GridEditBuffer setPendingValue(int id, String column, Object? value) => _copy(
    inserts: [for (final r in inserts) r.id == id ? r.set(column, value) : r],
  );

  /// Back to unspecified, so the column drops out of the `INSERT` again.
  GridEditBuffer clearPendingValue(int id, String column) => _copy(
    inserts: [for (final r in inserts) r.id == id ? r.unset(column) : r],
  );

  GridEditBuffer removePendingRow(int id) => _copy(
    inserts: [
      for (final r in inserts)
        if (r.id != id) r,
    ],
  );

  /// Everything discarded. [nextRowId] deliberately carries over so ids stay
  /// unique for the life of the buffer even across a discard.
  GridEditBuffer clear() => GridEditBuffer(nextRowId: nextRowId);

  GridEditBuffer _copy({
    Map<String, StagedEdit>? edits,
    Set<int>? deletes,
    List<PendingRow>? inserts,
    int? nextRowId,
  }) => GridEditBuffer(
    edits: edits ?? this.edits,
    deletes: deletes ?? this.deletes,
    inserts: inserts ?? this.inserts,
    nextRowId: nextRowId ?? this.nextRowId,
  );

  /// NULL and the empty string are deliberately distinct here.
  static bool _same(Object? a, Object? b) {
    if (a == null || b == null) return a == null && b == null;
    return '$a' == '$b';
  }

  /// The statements these changes become, in the order they must run:
  /// **DELETE, then UPDATE, then INSERT** — each single-row and PK-qualified.
  ///
  /// That order is the one that survives a unique index. Deleting a row and
  /// adding a replacement with the same natural key is an ordinary edit, and
  /// running the INSERT first would collide with the row that is still there;
  /// likewise an UPDATE that frees a value a new row then claims. Reversing any
  /// pair breaks a case that reversing the other does not.
  ///
  /// [pkValuesFor] supplies a row's primary-key values **as they were read**;
  /// returning null for a row skips it (it can't be addressed safely).
  List<String> toSql({
    required GridEditability editability,
    required SqlDialect dialect,
    required Map<String, Object?>? Function(int rowIndex) pkValuesFor,
  }) {
    final builder = DmlBuilder(dialect);
    final statements = <String>[];

    for (final rowIndex in deletes.toList()..sort()) {
      final keys = pkValuesFor(rowIndex);
      if (keys == null || keys.isEmpty) continue;
      statements.add(builder.delete(editability.target, RowIdentity(keys)));
    }

    final byRow = <int, List<StagedEdit>>{};
    for (final e in edits.values) {
      byRow.putIfAbsent(e.rowIndex, () => []).add(e);
    }
    for (final rowIndex in byRow.keys.toList()..sort()) {
      final keys = pkValuesFor(rowIndex);
      if (keys == null || keys.isEmpty) continue;
      final cells = [
        for (final e in byRow[rowIndex]!)
          if (editability.editorFor(e.column) case final editor?)
            CellEdit(e.column, e.newValue, editor),
      ];
      final sql = builder.update(editability.target, cells, RowIdentity(keys));
      if (sql != null) statements.add(sql);
    }

    for (final row in inserts) {
      final cells = [
        for (final entry in row.values.entries)
          if (editability.editorFor(entry.key) case final editor?)
            CellEdit(entry.key, entry.value, editor),
      ];
      // A row the user added but never typed into yields nothing: `INSERT …
      // DEFAULT VALUES` is spelled differently on all three engines, and a row
      // of nothing is far more likely to be an accidental click than a request
      // for one. The caller says so rather than silently applying zero rows.
      final sql = builder.insert(editability.target, cells);
      if (sql != null) statements.add(sql);
    }

    return statements;
  }
}
