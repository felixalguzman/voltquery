import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart' as m;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/sql.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';

import '../../core/theme/volt_tokens.dart';

import '../../../domain/models/column_editor.dart';
import '../../../domain/drivers/result.dart';
import '../../../domain/sql/dml_builder.dart';
import '../../../domain/sql/editable_result.dart';
import '../../../domain/export/result_export.dart';
import '../../../domain/sql/sql_statement_splitter.dart';
import '../../core/menu/context_menu.dart';
import '../settings/settings_providers.dart';
import 'export_dialog.dart';
import 'grid_edit_buffer.dart';
import 'grid_editability.dart';
import 'worksheet_providers.dart';
import 'worksheet_state.dart';

// Palette lives in ui/core/theme (#7); these are local names for it.
const _bg = VoltPalette.canvas;
const _panel = VoltPalette.panel;
const _hair = VoltPalette.hairline;
const _accent = VoltPalette.accent;
const _text = VoltPalette.textHigh;
const _textMid = VoltPalette.textMid;
const _textLo = VoltPalette.textLow;
const _dirty = VoltPalette.warning;
const _added = VoltPalette.success;
const _removed = VoltPalette.danger;

/// Which row of the *result* a grid row stands for — never where pluto happens
/// to be showing it.
///
/// pluto sorts its rows in place and reports the view index, so keying a staged
/// edit on `rowIdx` meant that sorting a column and then editing wrote to
/// whichever row had moved into that visual slot. The identity therefore rides
/// on the [PlutoRow] itself, and the view index is never used to address data.
sealed class _RowRef {
  const _RowRef();

  /// The ref pluto is carrying for [row], or null if it isn't one of ours.
  static _RowRef? of(PlutoRow row) {
    final key = row.key;
    return key is ValueKey<_RowRef> ? key.value : null;
  }
}

/// A row that came back from the query, at [index] in [WorksheetRows.rows].
class _ResultRef extends _RowRef {
  const _ResultRef(this.index);
  final int index;

  @override
  bool operator ==(Object other) => other is _ResultRef && other.index == index;
  @override
  int get hashCode => Object.hash('result', index);
}

/// A row the user is inserting, identified by [PendingRow.id].
class _PendingRef extends _RowRef {
  const _PendingRef(this.id);
  final int id;

  @override
  bool operator ==(Object other) => other is _PendingRef && other.id == id;
  @override
  int get hashCode => Object.hash('pending', id);
}

/// Key for one of the result grid's status-bar actions ("Add Row", "Discard",
/// "Review & Apply").
///
/// A named function rather than scattered string literals: on a narrow pane
/// those buttons are icon-only, so their label is not in the tree and a test —
/// or Flutter Driver against the live app — has nothing else to select on.
String gridActionKey(String label) => 'grid.action.$label';

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
    this.sourceSql,
  });

  final WorksheetRows rows;
  final String worksheetId;

  /// Identifies this grid's staged-edit buffer (one per result sub-tab).
  final String gridId;

  /// The statement these rows came from. Re-run after a change that alters
  /// which rows exist — an applied INSERT or DELETE leaves what's on screen
  /// describing a table that no longer looks like that.
  final String? sourceSql;

  @override
  ConsumerState<ResultGrid> createState() => _ResultGridState();
}

class _ResultGridState extends ConsumerState<ResultGrid> {
  GridEditability? get _edit => widget.rows.editability;

  /// pluto owns its row list after `onLoaded` — the widget's `rows` argument is
  /// read once — so adding and discarding new rows has to go through it.
  PlutoGridStateManager? _sm;
  SqlDialect get _dialect =>
      SqlDialect.of(ref.read(currentConnectionProvider).engine);
  bool get _editable => _edit != null;

  /// Field key for column [i] — pluto needs a stable string key per column,
  /// and result columns can repeat names (`SELECT id, id`).
  static String _fieldKey(int i) => 'c$i';

  /// A row's primary-key values as originally read. Shared with the debug
  /// bridge so what it reports is what would actually run.
  Map<String, Object?>? _pkValues(int rowIndex) {
    final e = _edit;
    if (e == null) return null;
    return primaryKeyValues(e, widget.rows.fields, widget.rows.rows, rowIndex);
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

    // From the row itself, never `e.rowIdx` — see [_RowRef].
    final rowRef = _RowRef.of(e.row);
    if (rowRef == null) return;

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
    Future.microtask(() {
      if (!mounted) return;
      final notifier = ref.read(gridEditsProvider(widget.gridId).notifier);
      switch (rowRef) {
        case _PendingRef(:final id):
          notifier.setPendingValue(id, field.name, value);
        case _ResultRef(:final index):
          notifier.stage(StagedEdit(
            rowIndex: index,
            column: field.name,
            oldValue: widget.rows.rows[index].values[colIndex],
            newValue: value,
          ));
      }
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
    if (statements.isEmpty) {
      // Reachable with changes staged: a new row nobody typed into produces no
      // INSERT. Saying so beats a button that looks broken.
      await displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('Nothing to apply'),
          content: const Text('New rows need at least one value.'),
          severity: InfoBarSeverity.warning,
          onClose: close,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _ReviewDialog(statements: statements),
    );
    if (confirmed != true || !mounted) return;

    // Applying an INSERT or a DELETE changes *which* rows exist, so what's on
    // screen stops describing the table. An UPDATE doesn't: the staged values
    // are already rendered in place.
    final structural = buf.deletes.isNotEmpty || buf.inserts.isNotEmpty;

    final result = await ref
        .read(worksheetProvider(widget.worksheetId).notifier)
        .applyGridEdits(statements);
    if (!mounted) return;

    if (result.ok) {
      ref.read(gridEditsProvider(widget.gridId).notifier).clear();
      await displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: Text('${result.applied} statement(s) applied · '
              '${result.rowsAffected} row(s)'),
          severity: InfoBarSeverity.success,
          onClose: close,
        ),
      );
      final sql = widget.sourceSql;
      if (structural && sql != null && mounted) {
        await ref.read(worksheetProvider(widget.worksheetId).notifier).run(sql);
      }
    } else {
      await displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('Apply failed'),
          content: Text(result.error!.message),
          severity: InfoBarSeverity.error,
          onClose: close,
        ),
      );
    }
  }

  /// Bring pluto's row list back in line with the buffer's new rows.
  ///
  /// Reconciliation rather than "append on click" because the buffer is the
  /// source of truth and it can change from anywhere — Discard, a successful
  /// Apply, a duplicate action in a context menu three cells away.
  void _syncPendingRows(List<PendingRow> pending) {
    final sm = _sm;
    if (sm == null) return;

    final onScreen = <int, PlutoRow>{};
    for (final row in sm.rows) {
      if (_RowRef.of(row) case _PendingRef(:final id)) onScreen[id] = row;
    }
    final wanted = {for (final p in pending) p.id};

    final stale = [
      for (final entry in onScreen.entries)
        if (!wanted.contains(entry.key)) entry.value,
    ];
    if (stale.isNotEmpty) sm.removeRows(stale);

    final fresh = [
      for (final p in pending)
        if (!onScreen.containsKey(p.id)) _pendingPlutoRow(p),
    ];
    if (fresh.isEmpty) return;
    sm.appendRows(fresh);
    // Land the caret in the new row: it's usually below the fold on a long
    // result, and pluto scrolls the current cell into view.
    final firstEditable = sm.columns.firstWhere(
      (c) => !c.readOnly,
      orElse: () => sm.columns.first,
    );
    sm.setCurrentCell(fresh.last.cells[firstEditable.field], sm.rows.length - 1);
  }

  /// A new row renders as all-empty; its values come from the buffer via
  /// [_CellView], the same way a staged edit does.
  PlutoRow _pendingPlutoRow(PendingRow p) => PlutoRow(
        key: ValueKey<_RowRef>(_PendingRef(p.id)),
        cells: {
          for (var i = 0; i < widget.rows.fields.length; i++)
            _fieldKey(i): PlutoCell(value: ''),
        },
      );

  @override
  Widget build(BuildContext context) {
    final buf = _editable
        ? ref.watch(gridEditsProvider(widget.gridId))
        : const GridEditBuffer();
    final r = widget.rows;
    // `select` so a change to any *other* setting doesn't rebuild the grid.
    final nullDisplay =
        ref.watch(settingsProvider.select((s) => s.nullDisplay));

    // After the frame, not during it: pluto's state manager notifies listeners
    // when rows change, which is illegal mid-build.
    ref.listen(
      gridEditsProvider(widget.gridId).select((b) => b.inserts),
      (_, next) => _syncPendingRows(next),
    );

    final columns = [
      for (var i = 0; i < r.fields.length; i++)
        _column(i, r.fields[i].name, buf, nullDisplay),
    ];
    final rows = [
      for (var rowIndex = 0; rowIndex < r.rows.length; rowIndex++)
        PlutoRow(
          key: ValueKey<_RowRef>(_ResultRef(rowIndex)),
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
                _sm = e.stateManager;
                // A grid can be rebuilt with a buffer that already holds new
                // rows (the widget re-mounted, e.g. switching result sub-tabs).
                if (buf.inserts.isNotEmpty) _syncPendingRows(buf.inserts);
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

  PlutoColumn _column(
      int i, String name, GridEditBuffer buf, String nullDisplay) {
    final editor = _edit?.editorFor(name);
    final isPk = _edit?.isPrimaryKey(name) ?? false;
    // Booleans are edited by tapping the toggle in [_boolCell], so pluto's own
    // editor must stay out of the way.
    final isBool = editor?.kind == ColumnEditorKind.boolean;
    final typeable =
        _editable && editor != null && !editor.isReadOnly && !isBool;
    final canEdit = typeable && !isPk;

    return PlutoColumn(
      title: name,
      field: _fieldKey(i),
      type: _plutoType(editor),
      enableEditingMode: typeable,
      readOnly: !canEdit,
      // A PK column is read-only on an *existing* row — the staged UPDATE
      // addresses that row by this value, so editing it in place would change
      // the row's identity out from under the statement. A new row has no
      // identity yet, so its key has to be typeable or a table without a
      // sequence could never gain a row.
      checkReadOnly: isPk && typeable
          ? (row, _) => _RowRef.of(row) is! _PendingRef
          : null,
      // A read-only grid can never have a staged edit, so its cells don't need
      // to subscribe to anything — that's the whole cost avoided on the common
      // browse-a-big-table path.
      renderer: _editable
          ? (ctx) {
              // From the row, not `ctx.rowIdx`: see [_RowRef].
              final rowRef = _RowRef.of(ctx.row);
              if (rowRef == null) return const SizedBox.shrink();
              return _CellView(
                gridId: widget.gridId,
                rowRef: rowRef,
                column: name,
                colIndex: i,
                editor: editor,
                // A new row has no identity to preserve, so even its primary
                // key is fair game — you have to be able to supply one.
                editable: !isPk || rowRef is _PendingRef,
                rows: widget.rows,
                onStage: _stage,
                onSetPending: _setPending,
                onToggleDelete: _toggleDelete,
                onDuplicate: _duplicateRow,
                onDiscardNew: _discardNewRow,
                onExport: _export,
                dialect: _dialect,
                editability: _edit,
                nullDisplay: nullDisplay,
              );
            }
          // Passed down rather than watched per cell: a read-only grid's cells
          // subscribe to nothing, which is the whole point of _StaticCell.
          // Still addressed by row identity, not `ctx.rowIdx` — indexing the
          // result by the view position is what made sorting a column look
          // like it did nothing at all.
          : (ctx) => _StaticCell(
                value: switch (_RowRef.of(ctx.row)) {
                  _ResultRef(:final index)
                      when index < widget.rows.rows.length =>
                    widget.rows.rows[index].values[i],
                  _ => null,
                },
                nullDisplay: nullDisplay,
              ),
    );
  }

  /// Stage a value that didn't come from a pluto editor (the boolean toggle,
  /// the date picker, Set NULL).
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

  /// Ask what to export, then do it. Null result = cancelled.
  Future<void> _export() async {
    final sql = widget.sourceSql;
    final request = await showDialog<ExportRequest>(
      context: context,
      builder: (context) => ExportDialog(
        visibleRows: widget.rows.rows.length,
        capped: widget.rows.capped,
        // Re-running needs the statement; without it, only what's loaded can
        // leave, and the dialog says so rather than pretending otherwise.
        canExportAll: sql != null,
        defaultOptions: ExportOptions(
          dialect: _dialect,
          table: _edit?.target.table ?? 'exported_rows',
        ),
      ),
    );
    if (request == null || !mounted) return;

    try {
      final (text, rowCount) = await _serialize(request, sql);
      if (!mounted) return;
      if (request.sink == ExportSink.clipboard) {
        await Clipboard.setData(ClipboardData(text: text));
        if (mounted) _toast('Copied $rowCount row(s)');
      } else {
        final saved = await _save(text, request.format);
        if (mounted && saved != null) _toast('Wrote $rowCount row(s) to $saved');
      }
    } catch (e) {
      if (mounted) _toastError('Export failed', '$e');
    }
  }

  /// The exported text and how many rows it holds.
  Future<(String, int)> _serialize(ExportRequest request, String? sql) async {
    if (request.scope == ExportScope.visible || sql == null) {
      final formatter = ResultFormatter.of(request.format, request.options);
      return (
        formatter.formatAll(widget.rows.fields, widget.rows.rows),
        widget.rows.rows.length,
      );
    }
    // Whole result: re-run and stream. Into a buffer for now — the file sink
    // would avoid holding it at all, but `file_selector` hands back a path only
    // after the dialog closes, and asking where to save *before* knowing the
    // export succeeds is the worse trade.
    final buffer = StringBuffer();
    final count = await ref
        .read(worksheetProvider(widget.worksheetId).notifier)
        .exportResult(
          sql: sql,
          format: request.format,
          options: request.options,
          sink: buffer,
        );
    return (buffer.toString(), count);
  }

  /// Writes [text] to a file the user picks. Returns its name, or null if the
  /// save dialog was dismissed.
  Future<String?> _save(String text, ExportFormat format) async {
    final table = _edit?.target.table ?? 'result';
    final location = await getSaveLocation(
      suggestedName: '$table.${format.extension}',
      acceptedTypeGroups: [
        XTypeGroup(label: format.label, extensions: [format.extension]),
      ],
    );
    if (location == null) return null;
    await File(location.path).writeAsString(text);
    return location.path.split(Platform.pathSeparator).last;
  }

  void _toast(String title) => displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: Text(title),
          severity: InfoBarSeverity.success,
          onClose: close,
        ),
      );

  void _toastError(String title, String detail) => displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: Text(title),
          content: Text(detail),
          severity: InfoBarSeverity.error,
          onClose: close,
        ),
      );

  /// The same, for a row that doesn't exist yet.
  void _setPending(int id, String column, Object? newValue) {
    final problem = _edit?.editorFor(column)?.validate(newValue);
    if (problem != null) {
      _invalid(column, problem);
      return;
    }
    ref
        .read(gridEditsProvider(widget.gridId).notifier)
        .setPendingValue(id, column, newValue);
  }

  void _toggleDelete(int rowIndex) =>
      ref.read(gridEditsProvider(widget.gridId).notifier).toggleDelete(rowIndex);

  void _discardNewRow(int id) =>
      ref.read(gridEditsProvider(widget.gridId).notifier).removePendingRow(id);

  void _addRow([Map<String, Object?> seed = const {}]) =>
      ref.read(gridEditsProvider(widget.gridId).notifier).addRow(seed);

  /// Duplicate an existing row, **minus its primary key**.
  ///
  /// Copying the key would collide on the first INSERT; leaving it unset lets a
  /// sequence or identity column assign the next one, and a table with a
  /// natural key gets an empty cell to fill in — which is the honest prompt.
  void _duplicateRow(int rowIndex) {
    final e = _edit;
    if (e == null || rowIndex >= widget.rows.rows.length) return;
    final row = widget.rows.rows[rowIndex];
    _addRow({
      for (var i = 0; i < widget.rows.fields.length; i++)
        if (!e.isPrimaryKey(widget.rows.fields[i].name) &&
            e.editorFor(widget.rows.fields[i].name) != null)
          widget.rows.fields[i].name: row.values[i],
    });
  }

  Widget _statusBar(GridEditBuffer buf) {
    final r = widget.rows;
    final pending = buf.count;
    return Container(
      height: 28,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(left: 12, right: 6),
      color: _bg,
      // The results pane is user-resizable and gets genuinely narrow. Two rules
      // when it does: the counters yield before the actions (a button you
      // cannot reach is worse than a number you cannot read), and below
      // [_compactBarWidth] the actions drop their labels rather than being
      // pushed off the edge — which is what happened, since an overflowing
      // child is still laid out and simply never painted.
      child: LayoutBuilder(builder: (context, c) {
        final compact = c.maxWidth < _compactBarWidth;
        return Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      '${r.rows.length} row(s) · ${r.durationMs} ms'
                      '${r.capped ? ' · capped' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _textMid, fontSize: 11),
                    ),
                  ),
                  if (_editable && pending == 0) ...[
                    const SizedBox(width: 10),
                    const Icon(FluentIcons.edit, size: 10, color: _textLo),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'editable · ${_edit!.target.table}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _textLo, fontSize: 11),
                      ),
                    ),
                  ],
                  if (pending > 0) ...[
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        _pendingSummary(buf),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _dirty, fontSize: 11),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Always offered on an editable grid, not only once something is
            // staged: adding the first row is exactly the case where there is
            // nothing to right-click.
            _barButton('Export', FluentIcons.download, _textMid, _export,
                compact: compact),
            const SizedBox(width: 4),
            if (_editable) ...[
              _barButton('Add Row', FluentIcons.add, _textMid, _addRow,
                  compact: compact),
              const SizedBox(width: 4),
            ],
            if (pending > 0) ...[
              _barButton(
                'Discard',
                FluentIcons.cancel,
                _textMid,
                () => ref
                    .read(gridEditsProvider(widget.gridId).notifier)
                    .clear(),
                compact: compact,
              ),
              const SizedBox(width: 4),
              _barButton(
                'Review & Apply',
                FluentIcons.check_mark,
                _accent,
                () => _review(buf),
                compact: compact,
              ),
            ],
          ],
        );
      }),
    );
  }

  /// Below this the status bar's buttons go icon-only. Sized off the widest
  /// state (all three buttons plus a readable counter), not guessed.
  static const _compactBarWidth = 420.0;

  /// "3 edits · 1 new · 2 deleted" — the kinds are worth separating, because
  /// "5 pending changes" reads the same whether or not two of them drop rows.
  static String _pendingSummary(GridEditBuffer buf) {
    final parts = [
      if (buf.edits.isNotEmpty) '${buf.edits.length} edit'
          '${buf.edits.length == 1 ? '' : 's'}',
      if (buf.inserts.isNotEmpty) '${buf.inserts.length} new',
      if (buf.deletes.isNotEmpty) '${buf.deletes.length} deleted',
    ];
    return '${parts.join(' · ')} pending';
  }

  /// [compact] drops the label. The tooltip carries it instead, so a narrow
  /// pane loses the word but never the action.
  Widget _barButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed, {
    bool compact = false,
  }) {
    final button = HoverButton(
      onPressed: onPressed,
      builder: (context, states) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: states.isHovered ? VoltPalette.hover : null,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 10, color: color),
            if (!compact) ...[
              const SizedBox(width: 5),
              Text(label, style: TextStyle(color: color, fontSize: 11)),
            ],
          ],
        ),
      ),
    );
    // Always tooltipped, not only when compact: the label is 11px either way.
    // Keyed so the button stays findable when [compact] has removed its text —
    // that is what the driver and the widget tests select on. fluent's Tooltip
    // is not material's, so `find.byTooltip` does not see it.
    return Tooltip(
      key: ValueKey(gridActionKey(label)),
      message: label,
      child: button,
    );
  }

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
      activatedColor: VoltPalette.selected,
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
  const _StaticCell({required this.value, required this.nullDisplay});

  final Object? value;
  final String nullDisplay;

  @override
  Widget build(BuildContext context) {
    if (value == null) {
      return Text(
        nullDisplay,
        style: const TextStyle(
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
    required this.rowRef,
    required this.column,
    required this.colIndex,
    required this.editor,
    required this.editable,
    required this.rows,
    required this.onStage,
    required this.onSetPending,
    required this.onToggleDelete,
    required this.onDuplicate,
    required this.onDiscardNew,
    required this.onExport,
    required this.dialect,
    required this.nullDisplay,
    this.editability,
  });

  final String gridId;
  final _RowRef rowRef;
  final String column;
  final int colIndex;
  final ColumnEditor? editor;
  final bool editable;
  final WorksheetRows rows;
  final void Function(int rowIndex, String column, Object? value) onStage;
  final void Function(int id, String column, Object? value) onSetPending;
  final void Function(int rowIndex) onToggleDelete;
  final void Function(int rowIndex) onDuplicate;
  final void Function(int id) onDiscardNew;
  final VoidCallback onExport;
  final SqlDialect dialect;
  final String nullDisplay;
  final GridEditability? editability;

  int? get _resultIndex => switch (rowRef) {
        _ResultRef(:final index) => index,
        _PendingRef() => null,
      };

  Object? get _original {
    final i = _resultIndex;
    if (i == null || i >= rows.rows.length) return null;
    return rows.rows[i].values[colIndex];
  }

  /// Route a value to whichever half of the buffer owns this row.
  void _put(Object? value) => switch (rowRef) {
        _PendingRef(:final id) => onSetPending(id, column, value),
        _ResultRef(:final index) => onStage(index, column, value),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (rowRef case _PendingRef(:final id)) {
      return _pendingBody(context, ref, id);
    }

    final rowIndex = _resultIndex!;
    // `select` down to *this* cell's entry. Watching the whole buffer meant a
    // single staged edit rebuilt every visible cell, which is the sort of thing
    // that shows up as scroll jank on a large result.
    final staged = ref.watch(
      gridEditsProvider(gridId).select((b) => b.at(rowIndex, column)),
    );
    final deleted = ref.watch(
      gridEditsProvider(gridId).select((b) => b.isDeleted(rowIndex)),
    );
    final value = staged != null ? staged.newValue : _original;
    final isDirty = staged != null;

    if (deleted) return _deletedBody(value);

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

  /// A row staged for deletion still shows its data — struck through, so you
  /// can see *what* is about to go — and stops offering cell edits, which
  /// [GridEditBuffer.toggleDelete] discards anyway.
  Widget _deletedBody(Object? value) => ContextMenuRegion(
        actions: _actions(value, deleted: true),
        child: Row(
          children: [
            Container(width: 2, height: 16, color: _removed),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                value == null ? nullDisplay : '$value',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _removed,
                  fontSize: 12.5,
                  fontFamily: 'monospace',
                  decoration: TextDecoration.lineThrough,
                  decorationColor: _removed,
                ),
              ),
            ),
          ],
        ),
      );

  /// A cell of a row that doesn't exist yet.
  ///
  /// An untouched cell reads `default`, not NULL: the column is left out of the
  /// INSERT entirely, so the engine's default or sequence decides. That is a
  /// different outcome from writing NULL into it, and on a nullable column with
  /// a default it's the difference between the default and nothing.
  Widget _pendingBody(BuildContext context, WidgetRef ref, int id) {
    final (specified, value) = ref.watch(
      gridEditsProvider(gridId).select((b) => b.pendingCell(id, column)),
    );

    final Widget inner = !specified
        ? const Text(
            'default',
            style: TextStyle(
              color: _textLo,
              fontSize: 11.5,
              fontFamily: 'monospace',
              fontStyle: FontStyle.italic,
            ),
          )
        : switch (editor?.kind) {
            ColumnEditorKind.boolean => _boolBody(context, value, false),
            ColumnEditorKind.date ||
            ColumnEditorKind.dateTime =>
              _dateBody(context, value, false),
            _ => value == null
                ? _nullLabel()
                : Text(
                    '$value',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _added,
                      fontSize: 12.5,
                      fontFamily: 'monospace',
                    ),
                  ),
          };

    return ContextMenuRegion(
      actions: _actions(value),
      child: Row(
        children: [
          Container(width: 2, height: 16, color: _added),
          const SizedBox(width: 6),
          Flexible(child: inner),
        ],
      ),
    );
  }

  /// Cell + row actions. These live here rather than in a toolbar because the
  /// row you mean is the one you right-clicked — and Set NULL is the only way
  /// to reach a deliberate NULL, since empty text input on a nullable column is
  /// ambiguous.
  List<MenuAction> _actions(Object? value, {bool deleted = false}) {
    final i = _resultIndex;
    final row = i != null && i < rows.rows.length ? rows.rows[i] : null;
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
      MenuAction(
        'Export Results…',
        onExport,
        icon: FluentIcons.download,
      ),
      // Cell edits are pointless on a row that is on its way out — staging the
      // delete discarded them, and staging another would only re-add noise.
      if (editable && !deleted) ...[
        MenuAction.divider,
        MenuAction(
          'Set NULL',
          () => _put(null),
          icon: FluentIcons.circle_ring,
        ),
        MenuAction(
          'Revert Cell',
          () => _put(_original),
          icon: FluentIcons.undo,
        ),
      ],
      // Row-level writes, only on a grid that can write at all.
      if (editability != null) ...[
        MenuAction.divider,
        if (i != null) ...[
          MenuAction(
            'Duplicate Row',
            () => onDuplicate(i),
            icon: FluentIcons.copy,
          ),
          MenuAction(
            deleted ? 'Keep Row' : 'Delete Row',
            () => onToggleDelete(i),
            icon: deleted ? FluentIcons.undo : FluentIcons.delete,
          ),
        ],
        if (rowRef case _PendingRef(:final id))
          MenuAction(
            'Discard New Row',
            () => onDiscardNew(id),
            icon: FluentIcons.cancel,
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

  String _display(Object? v) => v == null ? nullDisplay : '$v';

  Widget _nullLabel() => Text(
        nullDisplay,
        style: const TextStyle(
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
          isNull ? nullDisplay : (on ? 'true' : 'false'),
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
      onTap: () => _put(_nextBool(value)),
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
    _put(_formatDate(picked, withTime: withTime));
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
