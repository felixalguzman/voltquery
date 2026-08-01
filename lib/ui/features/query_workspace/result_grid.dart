import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart' as m;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/sql.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';

import '../../../domain/models/column_editor.dart';
import '../../../domain/drivers/result.dart';
import '../../../domain/sql/dml_builder.dart';
import '../../../domain/sql/editable_result.dart';
import '../../../domain/sql/sql_statement_splitter.dart';
import '../../core/menu/context_menu.dart';
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
  SqlDialect get _dialect =>
      SqlDialect.of(ref.read(currentConnectionProvider).engine);
  bool get _editable => _edit != null;

  /// Field key for column [i] — pluto needs a stable string key per column,
  /// and result columns can repeat names (`SELECT id, id`).
  static String _fieldKey(int i) => 'c$i';

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
        // pluto's number() defaults to format '#,###', which both drops the
        // fractional part and inserts a thousands separator — so 1234.5 came
        // back as "1,234" and no longer parsed as a number. These formats keep
        // the value exact and ungrouped; applyFormatOnInit off so the *stored*
        // value is never rewritten by display formatting.
        ColumnEditorKind.integer => PlutoColumnType.number(
            format: '#',
            applyFormatOnInit: false,
          ),
        ColumnEditorKind.decimal => PlutoColumnType.number(
            format: '#.##########',
            applyFormatOnInit: false,
          ),
        // Dates stay *text* columns on purpose. pluto's date() validates the
        // cell against its own format, so a value it can't parse (a DATETIME,
        // or any non-`yyyy-MM-dd` shape) silently refuses to enter edit mode.
        // Typing always works here, and [_dateCell] adds a real picker.
        ColumnEditorKind.time => PlutoColumnType.time(),
        ColumnEditorKind.enumeration when editor!.options.isNotEmpty =>
          PlutoColumnType.select(editor.options),
        // Booleans get a real toggle rendered by [_cell]; pluto has no boolean
        // editor, and a text cell showing `true`/`0` was the worst of both.
        _ => PlutoColumnType.text(),
      };

  void _onChanged(PlutoGridOnChangedEvent e, GridEditBuffer buf) {
    final colIndex = int.tryParse(e.column.field.substring(1));
    if (colIndex == null) return;
    final field = widget.rows.fields[colIndex];
    final editor = _edit?.editorFor(field.name);
    if (editor == null) return;

    final original = widget.rows.rows[e.rowIdx].values[colIndex];
    final value = _coerce(e.value, editor);

    // Refuse a value the column can't hold *here*, where the user can still see
    // what they typed — rather than letting it become SQL the engine rejects
    // later with a more cryptic message.
    final problem = editor.validate(value);
    if (problem != null) {
      _invalid(field.name, problem);
      return;
    }
    // pluto commits a cell edit from TextCellState.dispose() — i.e. while the
    // widget tree is being finalized — and Riverpod (rightly) asserts against
    // mutating a provider during a build. Defer to the next microtask so the
    // frame can finish first.
    final edit = StagedEdit(
      rowIndex: e.rowIdx,
      column: field.name,
      oldValue: original,
      newValue: value,
    );
    Future.microtask(() {
      if (!mounted) return;
      ref.read(gridEditsProvider(widget.gridId).notifier).stage(edit);
    });
  }

  void _invalid(String column, String problem) {
    // Same reason as above: this can be reached from a dispose-time commit.
    Future.microtask(() {
      if (mounted) _showInvalid(column, problem);
    });
  }

  void _showInvalid(String column, String problem) {
    displayInfoBar(
      context,
      builder: (context, close) => InfoBar(
        title: Text('$column: $problem'),
        severity: InfoBarSeverity.warning,
        onClose: close,
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
          title: Text('${result.rowsAffected} row(s) updated'),
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
    // Booleans are edited by tapping the toggle in [_boolCell], so pluto's own
    // editor must stay out of the way.
    final isBool = editor?.kind == ColumnEditorKind.boolean;
    final canEdit =
        _editable && editor != null && !editor.isReadOnly && !isPk && !isBool;

    return PlutoColumn(
      title: name,
      field: _fieldKey(i),
      type: _plutoType(editor),
      enableEditingMode: canEdit,
      readOnly: !canEdit,
      // A read-only grid can never have a staged edit, so its cells don't need
      // to subscribe to anything — that's the whole cost avoided on the common
      // browse-a-big-table path.
      renderer: _editable
          ? (ctx) => _CellView(
                gridId: widget.gridId,
                rowIndex: ctx.rowIdx,
                column: name,
                colIndex: i,
                editor: editor,
                editable: !isPk,
                rows: widget.rows,
                onStage: _stage,
                dialect: _dialect,
                editability: _edit,
              )
          : (ctx) => _StaticCell(
                value: ctx.rowIdx < widget.rows.rows.length
                    ? widget.rows.rows[ctx.rowIdx].values[i]
                    : null,
              ),
    );
  }

  /// Stage a value that didn't come from a pluto editor (the boolean toggle,
  /// the date picker).
  void _stage(int rowIndex, String column, Object? newValue) {
    final colIndex = widget.rows.fields.indexWhere((f) => f.name == column);
    if (colIndex < 0) return;
    final editor = _edit?.editorFor(column);
    final problem = editor?.validate(newValue);
    if (problem != null) {
      _invalid(column, problem);
      return;
    }
    ref.read(gridEditsProvider(widget.gridId).notifier).stage(
          StagedEdit(
            rowIndex: rowIndex,
            column: column,
            oldValue: widget.rows.rows[rowIndex].values[colIndex],
            newValue: newValue,
          ),
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
            'One statement per edited row, run in order inside a single '
            'transaction — if any fails, none are applied. With manual-commit '
            'on they join your open transaction instead, and wait for Commit.',
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
              // Read-only CodeEditor rather than plain text: this is SQL the
              // user is being asked to vet, and the same highlighting as the
              // main editor makes it far quicker to scan.
              child: CodeEditor(
                readOnly: true,
                controller: CodeLineEditingController.fromText(
                  statements.join('\n'),
                ),
                style: CodeEditorStyle(
                  fontSize: 12.5,
                  backgroundColor: _bg,
                  codeTheme: CodeHighlightTheme(
                    languages: {'sql': CodeHighlightThemeMode(mode: langSql)},
                    theme: atomOneDarkTheme,
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

/// A cell in a read-only grid: no provider subscription at all, since nothing
/// can ever stage an edit here. Keeps the browse-a-large-table path cheap.
class _StaticCell extends StatelessWidget {
  const _StaticCell({required this.value});

  final Object? value;

  @override
  Widget build(BuildContext context) {
    if (value == null) {
      return const Text(
        'NULL',
        style: TextStyle(
          color: _textLo,
          fontSize: 11.5,
          fontFamily: 'monospace',
          fontStyle: FontStyle.italic,
        ),
      );
    }
    return Text(
      '$value',
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: _text,
        fontSize: 12.5,
        fontFamily: 'monospace',
      ),
    );
  }
}

/// One grid cell.
///
/// It **watches the edit buffer itself**. pluto takes its `columns` list once
/// and keeps those `PlutoColumn` objects, so a renderer that closed over the
/// buffer would keep rendering whatever existed at first build — the edit would
/// stage (the pending count rose) while the cell still painted the old value.
/// Watching per cell also means a staged change repaints exactly that cell,
/// with no dependency on pluto noticing anything.
class _CellView extends ConsumerWidget {
  const _CellView({
    required this.gridId,
    required this.rowIndex,
    required this.column,
    required this.colIndex,
    required this.editor,
    required this.editable,
    required this.rows,
    required this.onStage,
    required this.dialect,
    this.editability,
  });

  final String gridId;
  final int rowIndex;
  final String column;
  final int colIndex;
  final ColumnEditor? editor;
  final bool editable;
  final WorksheetRows rows;
  final void Function(int rowIndex, String column, Object? value) onStage;
  final SqlDialect dialect;
  final GridEditability? editability;

  Object? get _original => rowIndex < rows.rows.length
      ? rows.rows[rowIndex].values[colIndex]
      : null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `select` down to *this* cell's entry. Watching the whole buffer meant a
    // single staged edit rebuilt every visible cell, which is the sort of thing
    // that shows up as scroll jank on a large result.
    final staged = ref.watch(
      gridEditsProvider(gridId).select((b) => b.at(rowIndex, column)),
    );
    final value = staged != null ? staged.newValue : _original;
    final isDirty = staged != null;

    final Widget inner = switch (editor?.kind) {
      ColumnEditorKind.boolean => _boolBody(context, value, isDirty),
      ColumnEditorKind.date ||
      ColumnEditorKind.dateTime =>
        _dateBody(context, value, isDirty),
      _ => _textBody(value, isDirty),
    };
    final body = ContextMenuRegion(actions: _actions(value), child: inner);

    if (!isDirty) return body;
    // Hovering a changed cell shows what it was — the staged value replaced the
    // original on screen, so this is the only way back to it before applying.
    return Tooltip(
      style: const TooltipThemeData(
        textStyle: TextStyle(
          fontSize: 13,
          fontFamily: 'monospace',
          color: _text,
        ),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      message: '${_display(staged.oldValue)}  \u2192  ${_display(staged.newValue)}',
      child: Row(
        children: [
          Container(width: 2, height: 16, color: _dirty),
          const SizedBox(width: 6),
          Flexible(child: body),
        ],
      ),
    );
  }

  /// Cell + row actions. "Copy as SQL" and "Set NULL" live here rather than in
  /// a toolbar because they are per-cell operations — and Set NULL is the only
  /// way to reach a deliberate NULL, since empty text input on a nullable
  /// column is ambiguous.
  List<MenuAction> _actions(Object? value) {
    final row = rowIndex < rows.rows.length ? rows.rows[rowIndex] : null;
    return [
      MenuAction(
        'Copy Cell',
        () => _copy(value == null ? '' : '$value'),
        icon: FluentIcons.copy,
      ),
      MenuAction(
        'Copy Row',
        () => _copy(_rowTsv(row)),
        icon: FluentIcons.table,
      ),
      MenuAction(
        'Copy Column Name',
        () => _copy(column),
        icon: FluentIcons.text_field,
      ),
      MenuAction.divider,
      MenuAction(
        'Copy Row as INSERT',
        () => _copy(_rowInsert(row)),
        icon: FluentIcons.code,
      ),
      if (editable) ...[
        MenuAction.divider,
        MenuAction(
          'Set NULL',
          () => onStage(rowIndex, column, null),
          icon: FluentIcons.circle_ring,
        ),
        MenuAction(
          'Revert Cell',
          () => onStage(rowIndex, column, _original),
          icon: FluentIcons.undo,
        ),
      ],
    ];
  }

  void _copy(String text) => Clipboard.setData(ClipboardData(text: text));

  /// Tab-separated — what spreadsheets expect on paste.
  String _rowTsv(ResultRow? row) {
    if (row == null) return '';
    return row.values.map((v) => v == null ? '' : '$v').join('\t');
  }

  /// A reusable INSERT for this row, quoted for the connection's dialect.
  String _rowInsert(ResultRow? row) {
    if (row == null) return '';
    final target =
        editability?.target ?? const EditableTarget(table: 'table_name');
    final cells = [
      for (var i = 0; i < rows.fields.length; i++)
        CellEdit(
          rows.fields[i].name,
          row.values[i],
          editability?.editorFor(rows.fields[i].name) ??
              const ColumnEditor(kind: ColumnEditorKind.text, nullable: true),
        ),
    ];
    return DmlBuilder(dialect).insert(target, cells) ?? '';
  }

  static String _display(Object? v) => v == null ? 'NULL' : '$v';

  Widget _nullLabel() => const Text(
        'NULL',
        style: TextStyle(
          color: _textLo,
          fontSize: 11.5,
          fontFamily: 'monospace',
          fontStyle: FontStyle.italic,
        ),
      );

  Widget _textBody(Object? value, bool isDirty) {
    if (value == null) return _nullLabel();
    return Text(
      '$value',
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: isDirty ? _dirty : _text,
        fontSize: 12.5,
        fontFamily: 'monospace',
      ),
    );
  }

  /// A clickable toggle. pluto has no boolean editor, and a text cell showing
  /// `true` / `0` (engines disagree) was both ugly and error-prone.
  Widget _boolBody(BuildContext context, Object? value, bool isDirty) {
    final on = _truthy(value);
    final isNull = value == null;
    final color = isNull
        ? _textLo
        : isDirty
            ? _dirty
            : (on ? _accent : _textMid);

    final visual = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isNull
              ? FluentIcons.checkbox_indeterminate
              : on
                  ? FluentIcons.checkbox_composite
                  : FluentIcons.checkbox,
          size: 13,
          color: color,
        ),
        const SizedBox(width: 6),
        Text(
          isNull ? 'NULL' : (on ? 'true' : 'false'),
          style: TextStyle(
            color: isNull ? _textLo : (isDirty ? _dirty : _textMid),
            fontSize: 11.5,
            fontFamily: 'monospace',
            fontStyle: isNull ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      ],
    );
    if (!editable) return visual;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Cycles false -> true -> (NULL where the column allows it) -> false.
      onTap: () => onStage(rowIndex, column, _nextBool(value)),
      child: MouseRegion(cursor: SystemMouseCursors.click, child: visual),
    );
  }

  /// Next value in the toggle cycle, **shaped like what the engine stored**.
  ///
  /// This matters for more than tidiness: the buffer drops an edit when the new
  /// value equals the original, and it compares by string. SQLite and MySQL
  /// hand back a BOOLEAN as int `0`/`1`, so returning a Dart `false` made
  /// `'0' != 'false'` — toggling off and back on left a phantom pending change
  /// that would have written a redundant UPDATE.
  Object? _nextBool(Object? current) {
    final next = switch (current) {
      null => true, // NULL -> true -> false -> NULL (when nullable)
      _ when !_truthy(current) => true,
      _ => (editor?.nullable ?? false) ? null : false,
    };
    if (next == null) return null;
    return _asOriginalShape(next);
  }

  /// Match the original cell's representation so equality against it works.
  Object _asOriginalShape(bool value) {
    final sample = _original;
    if (sample is num) return value ? 1 : 0;
    if (sample is String) {
      // Preserve whatever spelling the engine used ('t'/'f', 'true'/'false').
      final lower = sample.toLowerCase();
      if (lower == 't' || lower == 'f') return value ? 't' : 'f';
      if (lower == '0' || lower == '1') return value ? '1' : '0';
      return value ? 'true' : 'false';
    }
    return value;
  }

  static bool _truthy(Object? v) => switch (v) {
        null => false,
        bool b => b,
        num n => n != 0,
        _ => const {'true', 't', '1', 'yes', 'y'}.contains('$v'.toLowerCase()),
      };

  /// The value as stored, plus a calendar button opening a real picker. The
  /// column is still text underneath, so typing an exact value keeps working.
  Widget _dateBody(BuildContext context, Object? value, bool isDirty) {
    final label = _textBody(value, isDirty);
    if (!editable) return label;
    return Row(
      children: [
        Flexible(child: label),
        const SizedBox(width: 6),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _pickDate(context, value),
          child: const MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Icon(FluentIcons.calendar, size: 11, color: _textLo),
          ),
        ),
      ],
    );
  }

  Future<void> _pickDate(BuildContext context, Object? current) async {
    final withTime = editor?.kind == ColumnEditorKind.dateTime;
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (context) => _DatePickerDialog(
        initial: _parseDate(current) ?? DateTime.now(),
        withTime: withTime,
      ),
    );
    if (picked == null) return;
    onStage(rowIndex, column, _formatDate(picked, withTime: withTime));
  }

  /// Values arrive as text on SQLite/MySQL and may already be a DateTime on
  /// Postgres.
  static DateTime? _parseDate(Object? v) => switch (v) {
        null => null,
        DateTime d => d,
        _ => DateTime.tryParse('$v'.replaceFirst(' ', 'T')),
      };

  /// Engine-neutral `yyyy-MM-dd[ HH:mm:ss]`, which all three engines accept.
  static String _formatDate(DateTime d, {required bool withTime}) {
    String two(int n) => n.toString().padLeft(2, '0');
    final date = '${d.year}-${two(d.month)}-${two(d.day)}';
    if (!withTime) return date;
    return '$date ${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
  }
}

/// Calendar (and clock, for datetime) picker. fluent's own pickers, so the
/// cell editor matches the rest of the app rather than pluto's built-in.
class _DatePickerDialog extends StatefulWidget {
  const _DatePickerDialog({required this.initial, required this.withTime});

  final DateTime initial;
  final bool withTime;

  @override
  State<_DatePickerDialog> createState() => _DatePickerDialogState();
}

class _DatePickerDialogState extends State<_DatePickerDialog> {
  late DateTime _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 420),
      title: Text(
        widget.withTime ? 'Pick date & time' : 'Pick a date',
        style: const TextStyle(fontSize: 16),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DatePicker(
            selected: _value,
            onChanged: (d) => setState(() => _value = DateTime(
                  d.year,
                  d.month,
                  d.day,
                  _value.hour,
                  _value.minute,
                  _value.second,
                )),
          ),
          if (widget.withTime) ...[
            const SizedBox(height: 10),
            TimePicker(
              selected: _value,
              onChanged: (t) => setState(() => _value = DateTime(
                    _value.year,
                    _value.month,
                    _value.day,
                    t.hour,
                    t.minute,
                    _value.second,
                  )),
            ),
          ],
        ],
      ),
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_value),
          child: const Text('Set'),
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
