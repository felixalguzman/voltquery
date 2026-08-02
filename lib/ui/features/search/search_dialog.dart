import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/history_entry.dart';
import '../../../domain/models/schema.dart';
import '../../../domain/sql/sql_statement_splitter.dart';
import '../query_workspace/worksheet_providers.dart';
import '../schema_browser/schema_providers.dart';
import '../schema_browser/table_info_dialog.dart';
import '../settings/settings_providers.dart';
import 'search_providers.dart';

// TODO(theming #7): unify tokens into ui/core/theme.
const _hair = Color(0xFF262A31);
const _accent = Color(0xFF2FE6FF);
const _text = Color(0xFFE6E8EC);
const _textMid = Color(0xFF9BA1AD);
const _textLo = Color(0xFF5A6069);
const _fk = Color(0xFFB98CFF);
const _err = Color(0xFFFF6B6B);

/// Search everything: tables, views, columns and query history at once.
///
/// The counterpart to the sidebar filter, which matches only what the tree has
/// loaded. This asks the **catalog**, so it finds a column in a table you have
/// never expanded — which on a schema with hundreds of tables is nearly all of
/// them, and is the whole reason it exists.
Future<void> showSearchDialog(BuildContext context) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) => const SearchDialog(),
  );
}

class SearchDialog extends ConsumerStatefulWidget {
  const SearchDialog({super.key});

  @override
  ConsumerState<SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends ConsumerState<SearchDialog> {
  late final TextEditingController _input;
  final _focus = FocusNode();

  /// Committed query — what actually runs. Separate from the field's text so a
  /// catalog round-trip doesn't fire per keystroke.
  String _query = '';
  Timer? _debounce;

  /// Index into the flattened result list, for ↑/↓ + Enter.
  int _selected = 0;

  SearchFilter _filter = SearchFilter.all;

  @override
  void initState() {
    super.initState();
    // Seeded from the editor selection: searching for the identifier you just
    // highlighted is the common case, and retyping it is pure friction.
    final seed = ref.read(editorSelectionProvider);
    _input = TextEditingController(text: seed);
    _query = seed;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    // Long enough that typing a table name is one query, short enough that it
    // still feels live. Every keystroke here is a catalog round-trip.
    _debounce = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      setState(() {
        _query = value.trim();
        _selected = 0;
      });
    });
  }

  // --- keyboard ------------------------------------------------------------

  List<_Row> _rows(SearchResults results) => [
        for (final h in results.schema) _Row.schema(h),
        for (final e in results.history) _Row.history(e),
      ];

  void _move(int delta, int count) {
    if (count == 0) return;
    setState(() => _selected = (_selected + delta) % count);
  }

  Future<void> _activate(_Row row) async {
    Navigator.of(context).pop();
    switch (row) {
      case _SchemaRow(:final hit):
        await _openHit(hit);
      case _HistoryRow(:final entry):
        ref.read(requestedQueryProvider.notifier).request(entry.sql);
    }
  }

  /// A table or view opens as a preview; a column opens its table too — the
  /// column is *where* you were going, the table is what you can actually look
  /// at.
  Future<void> _openHit(SchemaSearchHit hit) async {
    final dialect = SqlDialect.of(ref.read(currentConnectionProvider).engine);
    final target =
        dialect.qualify(hit.table.name, schema: hit.table.schema);
    final limit = ref.read(settingsProvider).tablePreviewLimit;
    final id = ref.read(worksheetTabsProvider.notifier).add();
    ref
        .read(worksheetSeedsProvider.notifier)
        .put(id, 'SELECT * FROM $target LIMIT $limit;', autoRun: true);
    ref
        .read(worksheetOriginsProvider.notifier)
        .put(id, '${hit.table.schema}.${hit.table.name}');
  }

  Future<void> _showInfo(SchemaSearchHit hit) async {
    final repo = await ref.read(schemaRepositoryProvider.future);
    if (!mounted) return;
    Navigator.of(context).pop();
    await showTableInfoDialog(
      context,
      table: hit.table,
      repo: repo,
      engine: ref.read(currentConnectionProvider).engine,
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(searchResultsProvider(_query, _filter));
    final results = async.value ?? const SearchResults();
    final rows = _rows(results);
    final screen = MediaQuery.sizeOf(context);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
            _move(1, rows.length),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
            _move(-1, rows.length),
        const SingleActivator(LogicalKeyboardKey.enter): () {
          if (rows.isNotEmpty) _activate(rows[_selected]);
        },
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
      },
      child: ContentDialog(
        constraints: BoxConstraints(
          maxWidth: screen.width.clamp(480.0, 820.0),
          maxHeight: screen.height * 0.8,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _field(async.isLoading),
            const SizedBox(height: 10),
            _filterChips(),
          ],
        ),
        content: SizedBox(
          // Fixed so the dialog doesn't resize as results arrive — a list that
          // grows under the pointer is how you click the wrong row.
          height: (screen.height * 0.52).clamp(220.0, 460.0),
          child: _body(async, results, rows),
        ),
        actions: [
          Text(
            rows.isEmpty ? '' : '↑↓ to move · Enter to open · Esc to close',
            style: const TextStyle(color: _textLo, fontSize: 10.5),
          ),
        ],
      ),
    );
  }

  Widget _field(bool loading) => Row(children: [
        const Icon(FluentIcons.search, size: 14, color: _textMid),
        const SizedBox(width: 10),
        Expanded(
          child: TextBox(
            controller: _input,
            focusNode: _focus,
            autofocus: true,
            placeholder: 'Search tables, columns and history…',
            onChanged: _onChanged,
            style: const TextStyle(
                color: _text, fontSize: 14, fontFamily: 'monospace'),
            decoration: const WidgetStatePropertyAll(BoxDecoration()),
            foregroundDecoration:
                const WidgetStatePropertyAll(BoxDecoration()),
            padding: EdgeInsets.zero,
          ),
        ),
        if (loading)
          const SizedBox(
              width: 14, height: 14, child: ProgressRing(strokeWidth: 2)),
      ]);

  /// Scope chips. More than cosmetic — see [SearchFilter].
  Widget _filterChips() => Row(children: [
        for (final f in SearchFilter.values)
          Padding(
            padding: const EdgeInsets.only(right: 5),
            child: HoverButton(
              onPressed: () => setState(() {
                _filter = f;
                _selected = 0;
              }),
              builder: (context, states) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: _filter == f
                      ? const Color(0x222FE6FF)
                      : (states.isHovered ? const Color(0x14FFFFFF) : null),
                  border: Border.all(
                      color: _filter == f ? _accent : _hair),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(f.label,
                    style: TextStyle(
                        fontSize: 10.5,
                        color: _filter == f ? _accent : _textMid)),
              ),
            ),
          ),
      ]);

  Widget _body(
    AsyncValue<SearchResults> async,
    SearchResults results,
    List<_Row> rows,
  ) {
    if (_query.length < kMinSearchLength) {
      return _Hint(
        _query.isEmpty
            ? 'Type to search every table, view and column in this connection '
                '— including ones you have never expanded — plus your query '
                'history.'
            : 'Keep typing — searches start at $kMinSearchLength characters.',
      );
    }
    if (async.hasError) {
      return _Hint('Search failed: ${async.error}', color: _err);
    }
    if (rows.isEmpty && !async.isLoading) {
      return const _Hint('Nothing matched.');
    }

    final tables = results.schema.where((h) => !h.isColumn).toList();
    final columns = results.schema.where((h) => h.isColumn).toList();
    var index = 0;

    return ListView(
      children: [
        if (results.schemaError != null)
          _Hint('Could not search the schema: ${results.schemaError}',
              color: _err),
        if (tables.isNotEmpty)
          _group('TABLES & VIEWS', tables.length),
        for (final h in tables) _schemaTile(h, index++),
        if (columns.isNotEmpty) _group('COLUMNS', columns.length),
        for (final h in columns) _schemaTile(h, index++),
        if (results.history.isNotEmpty)
          _group('HISTORY', results.history.length),
        for (final e in results.history) _historyTile(e, index++),
      ],
    );
  }

  Widget _group(String label, int count) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
        child: Row(children: [
          Text(label,
              style: const TextStyle(
                  color: _textLo,
                  fontSize: 9.5,
                  letterSpacing: 1.3,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Text('$count',
              style: const TextStyle(
                  color: _textLo, fontSize: 9.5, fontFamily: 'monospace')),
          const SizedBox(width: 8),
          const Expanded(child: Divider(style: DividerThemeData(
            decoration: BoxDecoration(color: _hair),
          ))),
        ]),
      );

  Widget _schemaTile(SchemaSearchHit hit, int index) => _tile(
        index: index,
        icon: switch (hit.kind) {
          SchemaHitKind.view => FluentIcons.page,
          SchemaHitKind.column => FluentIcons.circle_ring,
          SchemaHitKind.table => FluentIcons.table,
        },
        title: hit.name,
        // Where it lives — a bare `id` is useless without it.
        subtitle: hit.isColumn ? hit.qualifiedTable : hit.table.schema,
        trailing: hit.dataType,
        onTap: () => _activate(_Row.schema(hit)),
        onInfo: () => _showInfo(hit),
      );

  Widget _historyTile(HistoryEntry entry, int index) => _tile(
        index: index,
        icon: FluentIcons.history,
        title: entry.sql.replaceAll('\n', ' '),
        subtitle: entry.connectionName,
        trailing: '${entry.rowCount ?? 0} rows',
        onTap: () => _activate(_Row.history(entry)),
      );

  Widget _tile({
    required int index,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    String? trailing,
    VoidCallback? onInfo,
  }) {
    final selected = index == _selected;
    return HoverButton(
      onPressed: onTap,
      builder: (context, states) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0x222FE6FF)
              : (states.isHovered ? const Color(0x14FFFFFF) : null),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(children: [
          Icon(icon, size: 12, color: selected ? _accent : _textMid),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: selected ? _accent : _text,
                        fontSize: 12.5,
                        fontFamily: 'monospace')),
                if (subtitle.isNotEmpty)
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: _textLo,
                          fontSize: 10.5,
                          fontFamily: 'monospace')),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            Text(trailing,
                style: const TextStyle(
                    color: _fk, fontSize: 10.5, fontFamily: 'monospace')),
          ],
          if (onInfo != null) ...[
            const SizedBox(width: 6),
            Tooltip(
              message: 'Table info',
              child: IconButton(
                icon: const Icon(FluentIcons.info, size: 11, color: _textLo),
                onPressed: onInfo,
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

/// A flattened result row, so ↑/↓ can walk groups without caring which is which.
sealed class _Row {
  const _Row();
  factory _Row.schema(SchemaSearchHit hit) = _SchemaRow;
  factory _Row.history(HistoryEntry entry) = _HistoryRow;
}

class _SchemaRow extends _Row {
  const _SchemaRow(this.hit);
  final SchemaSearchHit hit;
}

class _HistoryRow extends _Row {
  const _HistoryRow(this.entry);
  final HistoryEntry entry;
}

class _Hint extends StatelessWidget {
  const _Hint(this.text, {this.color = _textLo});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        alignment: Alignment.topLeft,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        child: Text(text,
            style: TextStyle(color: color, fontSize: 11.5, height: 1.4)),
      );
}
