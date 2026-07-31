import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart' as m;
import 'package:flutter/services.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:panes/panes.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/sql.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';

import '../../../domain/sql/sql_statement_splitter.dart';
import 'worksheet_providers.dart';
import 'worksheet_state.dart';

// Clean Dev-Tool tokens (ADR-0007/theming #7) — inline until ui/core/theme lands.
const _bg = Color(0xFF0D0E11);
const _panel = Color(0xFF16181D);
const _hair = Color(0xFF262A31);
const _accent = Color(0xFF2FE6FF);
const _textMid = Color(0xFF9BA1AD);
const _err = Color(0xFFFF6B6B);
const _ok = Color(0xFF6FE39A);

/// The query workspace: `re_editor` (top) + `pluto_grid` (bottom) in a resizable
/// vertical `MultiPane`, driven by [worksheetProvider]. First end-to-end slice
/// of connect → query → grid (issues #12/#15).
class WorksheetView extends ConsumerStatefulWidget {
  const WorksheetView({super.key, required this.worksheetId});

  final String worksheetId;

  @override
  ConsumerState<WorksheetView> createState() => _WorksheetViewState();
}

class _WorksheetViewState extends ConsumerState<WorksheetView> {
  late final CodeLineEditingController _code;
  final _panes = PaneController(
    entries: [
      PaneEntry(id: 'editor', initialSize: PaneSize.fraction(0.42)),
      PaneEntry(id: 'result', initialSize: PaneSize.fraction(0.58)),
    ],
  );

  @override
  void initState() {
    super.initState();
    // A tab opened from the sidebar carries a seed query; else the default.
    final seed = ref.read(worksheetSeedsProvider)[widget.worksheetId];
    _code =
        CodeLineEditingController.fromText(seed ?? 'SELECT * FROM customers;');
    if (seed != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(worksheetSeedsProvider.notifier).take(widget.worksheetId);
        ref.read(worksheetProvider(widget.worksheetId).notifier).run(seed);
      });
    }
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _runSql(String sql) =>
      ref.read(worksheetProvider(widget.worksheetId).notifier).run(sql);

  /// Run the whole editor buffer (▶ Run). Also the sidebar's request path.
  void _run() => _runSql(_code.text);

  /// Run just the selected SQL, if any.
  void _runSelection() {
    if (_code.selectedText.trim().isNotEmpty) _runSql(_code.selectedText);
  }

  /// Run the single statement under the caret (dialect-aware split).
  void _runAtCursor() {
    final engine = ref.read(currentConnectionProvider).engine;
    final st = SqlStatementSplitter(SqlDialect.of(engine))
        .statementAt(_code.text, _caretOffset());
    if (st != null) _runSql(st.sql);
  }

  /// Ctrl/⌘+Enter: run the selection if there is one, else the statement at the
  /// caret — the DataGrip/DBeaver default.
  void _runSmart() =>
      _code.selectedText.trim().isNotEmpty ? _runSelection() : _runAtCursor();

  /// Absolute char offset of the caret in the full buffer (re_editor gives it as
  /// line + column).
  int _caretOffset() {
    final sel = _code.selection;
    final lines = _code.text.split('\n');
    final line = sel.extentIndex.clamp(0, lines.length - 1);
    var off = 0;
    for (var i = 0; i < line; i++) {
      off += lines[i].length + 1; // + newline
    }
    return off + sel.extentOffset;
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(worksheetProvider(widget.worksheetId));
    final connName = ref.watch(currentConnectionProvider).name;
    // Sidebar can request a query — only the *active* worksheet responds.
    ref.listen<String?>(requestedQueryProvider, (_, next) {
      final isActive =
          ref.read(worksheetTabsProvider).activeId == widget.worksheetId;
      if (next != null && isActive) {
        _code.text = next;
        _run();
        ref.read(requestedQueryProvider.notifier).clear();
      }
    });
    return Container(
      color: _bg,
      child: MultiPane(
        direction: Axis.vertical,
        controller: _panes,
        paneBuilder: (context, id, _) => switch (id) {
          'editor' => _editorPane(connName),
          'result' => _ResultPane(result: result),
          _ => const SizedBox.shrink(),
        },
      ),
    );
  }

  Future<void> _openFile() async {
    const group = XTypeGroup(
      label: 'SQLite',
      extensions: ['db', 'sqlite', 'sqlite3'],
    );
    final file = await openFile(acceptedTypeGroups: const [group]);
    if (file != null && mounted) {
      ref.read(currentConnectionProvider.notifier).openFile(file.path);
    }
  }

  Widget _editorPane(String connName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _toolbar(connName),
        Expanded(
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.enter, control: true):
                  _runSmart,
              const SingleActivator(LogicalKeyboardKey.enter, meta: true):
                  _runSmart,
            },
            child: CodeEditor(
              controller: _code,
              style: CodeEditorStyle(
                fontSize: 13.5,
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
    );
  }

  Widget _toolbar(String connName) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(
        color: _panel,
        border: Border(bottom: BorderSide(color: _hair)),
      ),
      child: Row(
        children: [
          const Icon(FluentIcons.database, size: 14, color: _accent),
          const SizedBox(width: 6),
          Text(
            '$connName · SQLite',
            style: const TextStyle(color: _textMid, fontSize: 12),
          ),
          const SizedBox(width: 12),
          Button(onPressed: _openFile, child: const Text('Open…')),
          const Spacer(),
          FilledButton(onPressed: _run, child: const Text('▶ Run')),
          const SizedBox(width: 6),
          DropDownButton(
            title: const Icon(FluentIcons.chevron_down, size: 10),
            items: [
              MenuFlyoutItem(
                leading: const Icon(FluentIcons.caret_right, size: 12),
                text: const Text('Run at cursor   Ctrl+Enter'),
                onPressed: _runAtCursor,
              ),
              MenuFlyoutItem(
                leading: const Icon(FluentIcons.text_field, size: 12),
                text: const Text('Run selection'),
                onPressed: _runSelection,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResultPane extends StatelessWidget {
  const _ResultPane({required this.result});
  final WorksheetResult result;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _panel,
      child: switch (result) {
        WorksheetIdle() => _centered('Run a query to see results.'),
        WorksheetRunning() => const Center(child: ProgressRing()),
        // A single-statement script renders its one result directly (grid /
        // message / failure); a multi-statement script gets sub-tabs + log.
        WorksheetScript(:final outcomes) =>
          outcomes.length == 1
              ? _single(outcomes.first.result)
              : _ScriptView(outcomes: outcomes),
        _ => _single(result),
      },
    );
  }
}

/// Renders one statement's payload — the original single-result view.
Widget _single(WorksheetResult r) => switch (r) {
  WorksheetRows() => _grid(r),
  WorksheetMessage(:final text) => _banner(
    text,
    color: _ok,
    icon: FluentIcons.check_mark,
  ),
  WorksheetFailure(:final error) => _banner(
    '${error.kind.name}: ${error.message}',
    color: _err,
    icon: FluentIcons.error_badge,
  ),
  _ => _centered('Run a query to see results.'),
};

Widget _centered(String s) => Center(
  child: Text(s, style: const TextStyle(color: _textMid)),
);

Widget _banner(String s, {required Color color, required IconData icon}) {
  return Padding(
    padding: const EdgeInsets.all(14),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Flexible(
          child: Text(s, style: TextStyle(color: color)),
        ),
      ],
    ),
  );
}

/// Multi-statement result: a result sub-tab per row-returning statement + a
/// Messages tab logging every statement's outcome (ADR-0007 / #15).
class _ScriptView extends StatefulWidget {
  const _ScriptView({required this.outcomes});
  final List<StatementOutcome> outcomes;

  @override
  State<_ScriptView> createState() => _ScriptViewState();
}

class _ScriptViewState extends State<_ScriptView> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final rows = [
      for (final o in widget.outcomes)
        if (o.isRows) o,
    ];
    // No grids to show → the log is the whole view.
    if (rows.isEmpty) return _messagesLog(widget.outcomes);

    final labels = [for (final o in rows) 'Result ${o.index}', 'Messages'];
    final views = <Widget>[
      for (final o in rows) _grid(o.result as WorksheetRows),
      _messagesLog(widget.outcomes),
    ];
    final sel = _tab.clamp(0, views.length - 1);
    return Column(
      children: [
        _tabStrip(labels, sel),
        Expanded(
          child: IndexedStack(index: sel, children: views),
        ),
      ],
    );
  }

  Widget _tabStrip(List<String> labels, int sel) {
    return Container(
      height: 30,
      color: _bg,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            HoverButton(
              onPressed: () => setState(() => _tab = i),
              builder: (context, states) {
                final active = i == sel;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: active ? _accent : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    color: states.isHovered ? _panel : null,
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      color: active ? _accent : _textMid,
                      fontSize: 12,
                      fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// The execution log — one line per statement (status, detail, duration).
Widget _messagesLog(List<StatementOutcome> outcomes) {
  return Container(
    color: _panel,
    child: ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: outcomes.length,
      itemBuilder: (context, i) => _logRow(outcomes[i]),
    ),
  );
}

Widget _logRow(StatementOutcome o) {
  final (String text, Color color, IconData icon) = switch (o.result) {
    WorksheetRows r => (
      '${r.rows.length} row(s)${r.capped ? ' · capped' : ''} · ${r.durationMs} ms',
      _ok,
      FluentIcons.check_mark,
    ),
    // DDL has no meaningful affected-row count — show a plain OK.
    WorksheetMessage m => (
      o.kind == StatementKind.ddl ? 'OK' : m.text,
      _ok,
      FluentIcons.check_mark,
    ),
    WorksheetFailure f => (
      '${f.error.kind.name}: ${f.error.message}',
      _err,
      FluentIcons.error_badge,
    ),
    _ => ('', _textMid, FluentIcons.info),
  };
  final preview = o.sql.replaceAll(RegExp(r'\s+'), ' ').trim();
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 8),
        Text(
          '#${o.index}',
          style: const TextStyle(
            color: _textMid,
            fontSize: 11.5,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text, style: TextStyle(color: color, fontSize: 12)),
              Text(
                preview,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _textMid,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _grid(WorksheetRows r) {
  final columns = [
    for (var i = 0; i < r.fields.length; i++)
      PlutoColumn(
        title: r.fields[i].name,
        field: 'c$i',
        type: PlutoColumnType.text(),
        enableEditingMode: false,
      ),
  ];
  final rows = [
    for (final row in r.rows)
      PlutoRow(
        cells: {
          for (var i = 0; i < r.fields.length; i++)
            'c$i': PlutoCell(value: row.values[i] ?? 'NULL'),
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
            configuration: const PlutoGridConfiguration.dark(
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
                  color: Color(0xFFE6E8EC),
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
            ),
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
        Container(
          height: 26,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          color: _bg,
          child: Text(
            '${r.rows.length} row(s) · ${r.durationMs} ms'
            '${r.capped ? ' · capped' : ''}',
            style: const TextStyle(color: _textMid, fontSize: 11),
          ),
        ),
      ],
    ),
  );
}
