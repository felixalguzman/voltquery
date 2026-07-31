import 'package:flutter/material.dart' as m;
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:panes/panes.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/sql.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';

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
  const WorksheetView({super.key});

  @override
  ConsumerState<WorksheetView> createState() => _WorksheetViewState();
}

class _WorksheetViewState extends ConsumerState<WorksheetView> {
  final _code =
      CodeLineEditingController.fromText('SELECT * FROM customers;');
  final _panes = PaneController(entries: [
    PaneEntry(id: 'editor', initialSize: PaneSize.fraction(0.42)),
    PaneEntry(id: 'result', initialSize: PaneSize.fraction(0.58)),
  ]);

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _run() => ref.read(worksheetProvider.notifier).run(_code.text);

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(worksheetProvider);
    return Container(
      color: _bg,
      child: MultiPane(
        direction: Axis.vertical,
        controller: _panes,
        paneBuilder: (context, id, _) => switch (id) {
          'editor' => _editorPane(),
          'result' => _ResultPane(result: result),
          _ => const SizedBox.shrink(),
        },
      ),
    );
  }

  Widget _editorPane() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _toolbar(),
        Expanded(
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
      ],
    );
  }

  Widget _toolbar() {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(
        color: _panel,
        border: Border(bottom: BorderSide(color: _hair)),
      ),
      child: Row(children: [
        const Icon(FluentIcons.database, size: 14, color: _accent),
        const SizedBox(width: 6),
        const Text('demo · SQLite', style: TextStyle(color: _textMid, fontSize: 12)),
        const Spacer(),
        FilledButton(
          onPressed: _run,
          child: const Text('▶ Run'),
        ),
      ]),
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
        WorksheetMessage(:final text) =>
          _banner(text, color: _ok, icon: FluentIcons.check_mark),
        WorksheetFailure(:final error) => _banner(
            '${error.kind.name}: ${error.message}',
            color: _err,
            icon: FluentIcons.error_badge,
          ),
        WorksheetRows() => _grid(result as WorksheetRows),
      },
    );
  }

  Widget _centered(String s) =>
      Center(child: Text(s, style: const TextStyle(color: _textMid)));

  Widget _banner(String s, {required Color color, required IconData icon}) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Flexible(child: Text(s, style: TextStyle(color: color))),
      ]),
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
        PlutoRow(cells: {
          for (var i = 0; i < r.fields.length; i++)
            'c$i': PlutoCell(value: row.values[i] ?? 'NULL'),
        }),
    ];
    // pluto_grid needs a Material ancestor (absent under FluentApp).
    return m.Material(
      color: _panel,
      child: Column(children: [
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
                    fontFamily: 'monospace', fontSize: 12.5, color: Color(0xFFE6E8EC)),
                columnTextStyle: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: _textMid),
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
      ]),
    );
  }
}
