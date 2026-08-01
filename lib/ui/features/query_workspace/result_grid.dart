import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as m;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pluto_grid/pluto_grid.dart';

import '../../../domain/models/column_editor.dart';
import '../../../domain/sql/sql_statement_splitter.dart';
import 'grid_edit_buffer.dart';
import 'grid_editability.dart';
import 'worksheet_providers.dart';
import 'worksheet_state.dart';

// TODO(theming #7): unify tokens into ui/core/theme.
const _bg = Color(0xFF0D0E11);
const _panel = Color(0xFF16181D);
const _hair = Color(0xFF262A31);
const _accent = Color(0xFF2FE6FF);
const _text = Color(0xFFE6E8EC);
const _textMid = Color(0xFF9BA1AD);
const _textLo = Color(0xFF5A6069);
const _dirty = Color(0xFFE8B84B);

/// The result grid. Read-only unless the result maps 1:1 onto one table's rows
/// ([WorksheetRows.editability]), in which case cells become editable and edits
/// are **staged** — nothing reaches the database until the user reviews the
/// generated SQL and commits it.
class ResultGrid extends ConsumerStatefulWidget {
  const ResultGrid({
    super.key,
    required this.rows,
    required this.worksheetId,
    required this.gridId,
  });

  final WorksheetRows rows;
  final String worksheetId;

  /// Identifies this grid's staged-edit buffer (one per result sub-tab).
  final String gridId;

  @override
  ConsumerState<ResultGrid> createState() => _ResultGridState();
}

class _ResultGridState extends ConsumerState<ResultGrid> {
  GridEditability? get _edit => widget.rows.editability;
  bool get _editable => _edit != null;

  /// Field key for column [i] — pluto needs a stable string key per column,
  /// and result columns can repeat names (`SELECT id, id`).
  static String _fieldKey(int i) => 'c$i';

  /// The value a cell currently shows: the staged edit if dirty, else what was
  /// read from the database.
  Object? _effective(GridEditBuffer buf, int rowIndex, int colIndex) {
    final name = widget.rows.fields[colIndex].name;
    final staged = buf.at(rowIndex, name);
    if (staged != null) return staged.newValue;
    return widget.rows.rows[rowIndex].values[colIndex];
  }

  /// A row's primary-key values **as originally read** — never the staged ones,
  /// or an edit would address the row by a value that isn't in the table yet.
  Map<String, Object?>? _pkValues(int rowIndex) {
    final e = _edit;
    if (e == null || rowIndex >= widget.rows.rows.length) return null;
    final keys = <String, Object?>{};
    for (final pkName in e.primaryKey) {
      final col = widget.rows.fields.indexWhere(
        (f) => f.name.toLowerCase() == pkName.toLowerCase(),
      );
      // The PK wasn't selected (e.g. `SELECT name FROM t`) → can't address it.
      if (col < 0) return null;
      keys[pkName] = widget.rows.rows[rowIndex].values[col];
    }
    return keys;
  }

  /// pluto's column type for an editor kind. `text` is the deliberate fallback:
  /// where pluto has no native editor (boolean, dateTime, json) we keep a text
  /// cell for now and render the value ourselves — swapping in custom/fluent
  /// cells is a UI change only, the domain already names the editor it wants.
  PlutoColumnType _plutoType(ColumnEditor? editor) => switch (editor?.kind) {
        ColumnEditorKind.integer ||
        ColumnEditorKind.decimal =>
          PlutoColumnType.number(),
        ColumnEditorKind.date => PlutoColumnType.date(),
        ColumnEditorKind.time => PlutoColumnType.time(),
        ColumnEditorKind.enumeration when editor!.options.isNotEmpty =>
          PlutoColumnType.select(editor.options),
        _ => PlutoColumnType.text(),
      };

  void _onChanged(PlutoGridOnChangedEvent e, GridEditBuffer buf) {
    final colIndex = int.tryParse(e.column.field.substring(1));
    if (colIndex == null) return;
    final field = widget.rows.fields[colIndex];
    final editor = _edit?.editorFor(field.name);
    if (editor == null) return;

    final original = widget.rows.rows[e.rowIdx].values[colIndex];
    ref.read(gridEditsProvider(widget.gridId).notifier).stage(
          StagedEdit(
            rowIndex: e.rowIdx,
            column: field.name,
            oldValue: original,
            newValue: _coerce(e.value, editor),
          ),
        );
  }

  /// Turn pluto's edited value into what we'll send.
  ///
  /// Empty input on a **nullable** column means NULL — the common convention
  /// (DBeaver, TablePlus). On a NOT NULL column it stays an empty string, so the
  /// engine rejects it rather than us guessing.
  /// TODO(grid): an explicit "Set NULL" action would remove this ambiguity for
  /// nullable text columns where the user genuinely wants ''.
  Object? _coerce(Object? raw, ColumnEditor editor) {
    if (raw == null) return null;
    final text = '$raw';
    if (text.isEmpty) return editor.nullable ? null : '';
    return text;
  }

  Future<void> _review(GridEditBuffer buf) async {
    final e = _edit;
    if (e == null || buf.isEmpty) return;
    final dialect = SqlDialect.of(
      ref.read(currentConnectionProvider).engine,
    );
    final statements = buf.toSql(
      editability: e,
      dialect: dialect,
      pkValuesFor: _pkValues,
    );
    if (statements.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _ReviewDialog(statements: statements),
    );
    if (confirmed != true || !mounted) return;

    final result = await ref
        .read(worksheetProvider(widget.worksheetId).notifier)
        .applyGridEdits(statements);
    if (!mounted) return;

    if (result.ok) {
      ref.read(gridEditsProvider(widget.gridId).notifier).clear();
      await displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: Text('${result.applied} row(s) updated'),
          severity: InfoBarSeverity.success,
          onClose: close,
        ),
      );
    } else {
      await displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('Update failed'),
          content: Text(result.error!.message),
          severity: InfoBarSeverity.error,
          onClose: close,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final buf = _editable
        ? ref.watch(gridEditsProvider(widget.gridId))
        : const GridEditBuffer();
    final r = widget.rows;

    final columns = [
      for (var i = 0; i < r.fields.length; i++)
        _column(i, r.fields[i].name, buf),
    ];
    final rows = [
      for (var rowIndex = 0; rowIndex < r.rows.length; rowIndex++)
        PlutoRow(
          cells: {
            for (var i = 0; i < r.fields.length; i++)
              _fieldKey(i): PlutoCell(
                // pluto dislikes null cell values; NULL is rendered by the
                // cell renderer from the underlying data, not from this text.
                value: r.rows[rowIndex].values[i] ?? '',
              ),
          },
        ),
    ];

    // pluto_grid needs a Material ancestor (absent under FluentApp).
    return m.Material(
      color: _panel,
      child: Column(
        children: [
          Expanded(
            child: PlutoGrid(
              key: ValueKey(identityHashCode(r)),
              columns: columns,
              rows: rows,
              mode: _editable
                  ? PlutoGridMode.normal
                  : PlutoGridMode.readOnly,
              onChanged: (e) => _onChanged(e, buf),
              configuration: _config,
              onLoaded: (e) {
                e.stateManager.setShowColumnFilter(false);
                // Cell selection + arrow-key / Tab navigation + Ctrl+C copy
                // (built into pluto_grid). setKeepFocus keeps the grid's focus
                // node active so key events register after a cell is selected.
                e.stateManager.setSelectingMode(PlutoGridSelectingMode.cell);
                e.stateManager.setKeepFocus(true);
              },
            ),
          ),
          _statusBar(buf),
        ],
      ),
    );
  }

  PlutoColumn _column(int i, String name, GridEditBuffer buf) {
    final editor = _edit?.editorFor(name);
    // PK columns stay read-only: the staged UPDATE addresses the row *by* that
    // value, so editing it in place would change the row's identity.
    final isPk = _edit?.isPrimaryKey(name) ?? false;
    final canEdit =
        _editable && editor != null && !editor.isReadOnly && !isPk;

    return PlutoColumn(
      title: name,
      field: _fieldKey(i),
      type: _plutoType(editor),
      enableEditingMode: canEdit,
      readOnly: !canEdit,
      renderer: (ctx) => _cell(ctx, i, name, buf),
    );
  }

  /// Renders a cell: NULL as a dim placeholder (never the string "NULL"), and a
  /// dirty cell with an accent bar plus its staged value.
  Widget _cell(
    PlutoColumnRendererContext ctx,
    int colIndex,
    String name,
    GridEditBuffer buf,
  ) {
    final rowIndex = ctx.rowIdx;
    final value = _effective(buf, rowIndex, colIndex);
    final isDirty = buf.isDirty(rowIndex, name);

    final Widget label = value == null
        ? const Text(
            'NULL',
            style: TextStyle(
              color: _textLo,
              fontSize: 11.5,
              fontFamily: 'monospace',
              fontStyle: FontStyle.italic,
            ),
          )
        : Text(
            '$value',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isDirty ? _dirty : _text,
              fontSize: 12.5,
              fontFamily: 'monospace',
            ),
          );

    if (!isDirty) return label;
    return Row(
      children: [
        Container(width: 2, height: 16, color: _dirty),
        const SizedBox(width: 6),
        Flexible(child: label),
      ],
    );
  }

  Widget _statusBar(GridEditBuffer buf) {
    final r = widget.rows;
    final pending = buf.count;
    return Container(
      height: 28,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(left: 12, right: 6),
      color: _bg,
      child: Row(
        children: [
          Text(
            '${r.rows.length} row(s) · ${r.durationMs} ms'
            '${r.capped ? ' · capped' : ''}',
            style: const TextStyle(color: _textMid, fontSize: 11),
          ),
          if (_editable && pending == 0) ...[
            const SizedBox(width: 10),
            const Icon(FluentIcons.edit, size: 10, color: _textLo),
            const SizedBox(width: 4),
            Text(
              'editable · ${_edit!.target.table}',
              style: const TextStyle(color: _textLo, fontSize: 11),
            ),
          ],
          const Spacer(),
          if (pending > 0) ...[
            Text(
              '$pending pending change${pending == 1 ? '' : 's'}',
              style: const TextStyle(color: _dirty, fontSize: 11),
            ),
            const SizedBox(width: 10),
            _barButton(
              'Discard',
              FluentIcons.cancel,
              _textMid,
              () => ref
                  .read(gridEditsProvider(widget.gridId).notifier)
                  .clear(),
            ),
            const SizedBox(width: 4),
            _barButton(
              'Review & Apply',
              FluentIcons.check_mark,
              _accent,
              () => _review(buf),
            ),
          ],
        ],
      ),
    );
  }

  Widget _barButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) =>
      HoverButton(
        onPressed: onPressed,
        builder: (context, states) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: states.isHovered ? const Color(0x14FFFFFF) : null,
            borderRadius: BorderRadius.circular(3),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 10, color: color),
              const SizedBox(width: 5),
              Text(label, style: TextStyle(color: color, fontSize: 11)),
            ],
          ),
        ),
      );

  static const _config = PlutoGridConfiguration.dark(
    style: PlutoGridStyleConfig.dark(
      rowHeight: 28,
      columnHeight: 32,
      columnFilterHeight: 32,
      enableCellBorderHorizontal: false,
      defaultCellPadding: EdgeInsets.symmetric(horizontal: 10),
      defaultColumnTitlePadding: EdgeInsets.symmetric(horizontal: 10),
      cellTextStyle: TextStyle(
        fontFamily: 'monospace',
        fontSize: 12.5,
        color: _text,
      ),
      columnTextStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: _textMid,
      ),
      gridBackgroundColor: _panel,
      rowColor: _panel,
      activatedColor: Color(0xFF1E2A30),
      borderColor: _hair,
    ),
  );
}

/// Shows the exact statements before they run — the safety payoff of staging
/// edits instead of writing on blur.
class _ReviewDialog extends StatelessWidget {
  const _ReviewDialog({required this.statements});

  final List<String> statements;

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 620, maxHeight: 520),
      title: Text(
        'Review ${statements.length} statement'
        '${statements.length == 1 ? '' : 's'}',
        style: const TextStyle(fontSize: 16),
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'These run on this worksheet\'s session, in order. With '
            'manual-commit on they stay in the open transaction until you '
            'press Commit.',
            style: TextStyle(color: _textMid, fontSize: 11.5),
          ),
          const SizedBox(height: 10),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _bg,
                border: Border.all(color: _hair),
                borderRadius: BorderRadius.circular(4),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  statements.join('\n'),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: _text,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

/// Shown instead of the grid when a result can't be written back — kept as a
/// distinct widget so the reason can grow (no PK, join, aggregate…).
const readOnlyGridHint = Tooltip(
  message: 'Read-only: results are editable only for a single-table '
      'SELECT on a table with a primary key.',
  child: Icon(FluentIcons.lock, size: 10, color: _textLo),
);
