import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/sql.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';

import '../../../domain/models/column_editor.dart';
import '../../../domain/models/engine.dart';
import '../../../domain/models/schema.dart';
import '../../core/theme/sql_type_colors.dart';
import 'schema_repository.dart';

// TODO(theming #7): unify tokens into ui/core/theme.
const _bg = Color(0xFF0D0E11);
const _hair = Color(0xFF262A31);
const _accent = Color(0xFF2FE6FF);
const _text = Color(0xFFE6E8EC);
const _textMid = Color(0xFF9BA1AD);
const _textLo = Color(0xFF5A6069);
const _fk = Color(0xFFB98CFF);

/// Quick facts about a table: size, shape, keys and indexes, without writing a
/// query for any of it.
Future<void> showTableInfoDialog(
  BuildContext context, {
  required TableInfo table,
  required SchemaRepository repo,
  required Engine engine,
}) {
  return showDialog(
    context: context,
    builder: (context) =>
        _TableInfoDialog(table: table, repo: repo, engine: engine),
  );
}

class _TableInfoDialog extends StatefulWidget {
  const _TableInfoDialog({
    required this.table,
    required this.repo,
    required this.engine,
  });

  final TableInfo table;
  final SchemaRepository repo;
  final Engine engine;

  @override
  State<_TableInfoDialog> createState() => _TableInfoDialogState();
}

class _TableInfoDialogState extends State<_TableInfoDialog> {
  /// The table currently shown. Following a relation swaps this rather than
  /// opening another dialog — jumping through five tables should not leave five
  /// dialogs stacked on screen.
  late TableInfo _table = widget.table;
  final _back = <TableInfo>[];

  late Future<_Info> _info = _load();

  /// Filled only when the user asks — an exact count is a full scan.
  int? _exactRows;
  bool _counting = false;
  int _tab = 0;

  Future<_Info> _load() async {
    // Columns and indexes are already cached from expanding the tree, so this
    // is usually just the stats round-trip.
    final results = await Future.wait([
      widget.repo.columns(_table),
      widget.repo.indexes(_table),
      widget.repo.stats(_table),
      // Best-effort: a view or an engine that can't reproduce DDL shouldn't
      // fail the whole dialog.
      widget.repo.tableDdl(_table).catchError((_) => ''),
      widget.repo.referencedBy(_table).catchError((_) => <ColumnRef>[]),
    ]);
    return _Info(
      columns: results[0] as List<ColumnInfo>,
      indexes: results[1] as List<IndexInfo>,
      stats: results[2] as TableStats,
      ddl: results[3] as String,
      referencedBy: results[4] as List<ColumnRef>,
    );
  }

  Future<void> _countExactly() async {
    setState(() => _counting = true);
    try {
      final n = await widget.repo.rowCount(_table);
      if (mounted) setState(() => _exactRows = n);
    } catch (_) {
      // A failed count shouldn't take the dialog down; the estimate stands.
    } finally {
      if (mounted) setState(() => _counting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _table;
    final qualified = t.schema.isEmpty ? t.name : '${t.schema}.${t.name}';
    // Sized to the window rather than fixed: a table with twenty indexes (or a
    // wide column list) was scrolling inside a small box while most of the
    // screen sat empty.
    final screen = MediaQuery.sizeOf(context);
    return ContentDialog(
      constraints: BoxConstraints(
        maxWidth: screen.width.clamp(420.0, 900.0),
        maxHeight: screen.height * 0.8,
      ),
      title: Row(
        children: [
          if (_back.isNotEmpty) ...[
            Tooltip(
              message: 'Back to ${_back.last.name}',
              child: IconButton(
                icon: const Icon(FluentIcons.back, size: 13, color: _textMid),
                onPressed: _goBack,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Icon(t.kind == ObjectKind.view ? FluentIcons.page : FluentIcons.table,
              size: 15, color: _textMid),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(qualified,
                style: const TextStyle(fontSize: 15, fontFamily: 'monospace')),
          ),
          Text(t.kind == ObjectKind.view ? 'VIEW' : 'TABLE',
              style: const TextStyle(color: _textLo, fontSize: 10.5)),
        ],
      ),
      content: FutureBuilder<_Info>(
        future: _info,
        builder: (context, snap) {
          if (snap.hasError) {
            return Text('Could not read table info: ${snap.error}',
                style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 12));
          }
          if (!snap.hasData) {
            return const SizedBox(
              height: 120,
              child: Center(
                  child: SizedBox(
                      width: 18,
                      height: 18,
                      child: ProgressRing(strokeWidth: 2))),
            );
          }
          final info = snap.data!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _tabStrip(),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(right: 12),
                  child: switch (_tab) {
                    1 => _columnsTab(info),
                    2 => _relationsTab(info),
                    3 => _ddlTab(info),
                    _ => _body(info),
                  },
                ),
              ),
            ],
          );
        },
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _tabStrip() => Row(
        children: [
          for (final (i, label)
              in ['Overview', 'Columns', 'Relations', 'DDL'].indexed)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: HoverButton(
                onPressed: () => setState(() => _tab = i),
                builder: (context, states) => Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _tab == i
                        ? const Color(0x222FE6FF)
                        : (states.isHovered ? const Color(0x14FFFFFF) : null),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _tab == i ? _accent : Colors.transparent,
                    ),
                  ),
                  child: Text(label,
                      style: TextStyle(
                          fontSize: 12,
                          color: _tab == i ? _accent : _textMid)),
                ),
              ),
            ),
        ],
      );

  /// The columns themselves — a count alone answers almost nothing you'd open
  /// this dialog to find out.
  Widget _columnsTab(_Info info) {
    final shown = info.columns.where((c) {
      if (_fkOnly && !c.isForeignKey) return false;
      if (_typeFilter != null &&
          c.dataType.split('(').first.trim().toUpperCase() != _typeFilter) {
        return false;
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _columnFilters(info, shown.length),
        const SizedBox(height: 8),
        if (shown.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('No columns match this filter.',
                style: TextStyle(color: _textLo, fontSize: 11.5)),
          ),
        ..._columnRows(shown),
      ],
    );
  }

  Widget _columnFilters(_Info info, int shownCount) {
    final fkCount = info.columns.where((c) => c.isForeignKey).length;
    final filtered = _typeFilter != null || _fkOnly;
    return Row(
      children: [
        _filterChip(
          'Foreign keys ($fkCount)',
          active: _fkOnly,
          enabled: fkCount > 0,
          // Filters combine (AND) — they always did in the matching logic; it
          // was only these setters clearing each other.
          onTap: () => setState(() => _fkOnly = !_fkOnly),
        ),
        if (_typeFilter case final type?) ...[
          const SizedBox(width: 6),
          _filterChip(type, active: true,
              onTap: () => setState(() => _typeFilter = null)),
        ],
        const Spacer(),
        Text(
          filtered
              ? '$shownCount of ${info.columns.length}'
              : '${info.columns.length} columns',
          style: const TextStyle(color: _textLo, fontSize: 10.5),
        ),
        if (filtered) ...[
          const SizedBox(width: 8),
          HoverButton(
            onPressed: () => setState(() {
              _typeFilter = null;
              _fkOnly = false;
            }),
            builder: (context, states) => const Text('Clear',
                style: TextStyle(color: _accent, fontSize: 10.5)),
          ),
        ],
      ],
    );
  }

  Widget _filterChip(String label,
          {required bool active,
          required VoidCallback onTap,
          bool enabled = true}) =>
      HoverButton(
        onPressed: enabled ? onTap : null,
        builder: (context, states) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: active
                ? const Color(0x222FE6FF)
                : (states.isHovered ? const Color(0x14FFFFFF) : _bg),
            border: Border.all(color: active ? _accent : _hair),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label,
                style: TextStyle(
                    color: enabled
                        ? (active ? _accent : _textMid)
                        : _textLo,
                    fontSize: 10.5,
                    fontFamily: 'monospace')),
            if (active) ...[
              const SizedBox(width: 5),
              const Icon(FluentIcons.clear, size: 7, color: _accent),
            ],
          ]),
        ),
      );

  List<Widget> _columnRows(List<ColumnInfo> columns) => [
          for (final c in columns)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 16,
                    child: Icon(
                      c.isPrimaryKey
                          ? FluentIcons.permissions
                          : c.isForeignKey
                              ? FluentIcons.link
                              : FluentIcons.circle_ring,
                      size: 10,
                      color: c.isPrimaryKey
                          ? _accent
                          : c.isForeignKey
                              ? _fk
                              : _textLo,
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: SelectableText(c.name,
                        style: const TextStyle(
                            color: _text,
                            fontSize: 12,
                            fontFamily: 'monospace')),
                  ),
                  Expanded(
                    flex: 4,
                    child: HoverButton(
                      // The type filters to its own kind; a foreign key
                      // navigates to what it points at, which is the thing you
                      // actually wanted when you read it.
                      onPressed: () => c.references == null
                          ? setState(() => _typeFilter = c.dataType
                              .split('(')
                              .first
                              .trim()
                              .toUpperCase())
                          : _goTo(c.references!),
                      builder: (context, states) => Text(
                        c.references != null
                            ? '→ ${c.references}'
                            : c.dataType,
                        style: TextStyle(
                          color: c.references != null
                              ? _fk
                              : _colors.of(_kindOf(c)),
                          fontSize: 11,
                          fontFamily: 'monospace',
                          decoration: states.isHovered
                              ? TextDecoration.underline
                              : null,
                          decorationColor:
                              c.references != null ? _fk : _colors.of(_kindOf(c)),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      [
                        if (!c.nullable) 'NOT NULL',
                        if (c.defaultValue != null)
                          'default ${c.defaultValue}',
                      ].join(' · '),
                      style: const TextStyle(color: _textLo, fontSize: 10.5),
                    ),
                  ),
                ],
              ),
            ),
        ];

  /// Both directions of every relationship, each row a jump.
  ///
  /// Outbound and inbound answer different questions — "what does this need"
  /// versus "what needs this" — and having them side by side is what makes the
  /// dialog usable for walking a schema rather than inspecting one table.
  Widget _relationsTab(_Info info) {
    final outbound = info.columns.where((c) => c.references != null).toList();

    if (outbound.isEmpty && info.referencedBy.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'This table has no foreign keys, and nothing references it.',
          style: TextStyle(color: _textLo, fontSize: 11.5),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (outbound.isNotEmpty) ...[
          _collapsible(
            key: 'rel-out',
            title: 'References',
            count: outbound.length,
            subtitle: 'What this table depends on.',
            children: [
              for (final c in outbound)
                _relationRow(
                  from: c.name,
                  arrow: '→',
                  target: '${c.references}',
                  ref: c.references!,
                ),
            ],
          ),
          const SizedBox(height: 14),
        ],
        if (info.referencedBy.isNotEmpty)
          _collapsible(
            key: 'rel-in',
            title: 'Referenced by',
            count: info.referencedBy.length,
            subtitle: 'What depends on this table.',
            // A shared table can be referenced by hundreds; scanning that by
            // eye is hopeless, so this list gets its own filter.
            trailing: info.referencedBy.length > _inlineLimit
                ? SizedBox(
                    width: 180,
                    height: 24,
                    child: TextBox(
                      placeholder: 'Filter…',
                      style: const TextStyle(fontSize: 11),
                      onChanged: (v) =>
                          setState(() => _relationFilter = v.trim()),
                    ),
                  )
                : null,
            children: [
              for (final r in _filteredInbound(info.referencedBy))
                _relationRow(
                  from: '${r.table}.${r.column}',
                  arrow: '←',
                  target: _table.name,
                  ref: r,
                  highlightSource: true,
                ),
              if (_filteredInbound(info.referencedBy).isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Nothing matches that filter.',
                      style: TextStyle(color: _textLo, fontSize: 11)),
                ),
            ],
          ),
      ],
    );
  }

  Widget _relationRow({
    required String from,
    required String arrow,
    required String target,
    required ColumnRef ref,
    bool highlightSource = false,
  }) =>
      HoverButton(
        onPressed: () => _goTo(ref),
        builder: (context, states) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          margin: const EdgeInsets.only(bottom: 3),
          decoration: BoxDecoration(
            color: states.isHovered ? const Color(0x14FFFFFF) : _bg,
            border: Border.all(color: _hair),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  from,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: highlightSource ? _fk : _text,
                      fontSize: 11.5,
                      fontFamily: 'monospace'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(arrow,
                    style: const TextStyle(color: _textLo, fontSize: 11.5)),
              ),
              Expanded(
                child: Text(
                  target,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: highlightSource ? _text : _fk,
                      fontSize: 11.5,
                      fontFamily: 'monospace'),
                ),
              ),
              Icon(FluentIcons.chevron_right,
                  size: 8,
                  color: states.isHovered ? _accent : _textLo),
            ],
          ),
        ),
      );

  Widget _ddlTab(_Info info) {
    if (info.ddl.isEmpty) {
      return const Text('No DDL available for this object.',
          style: TextStyle(color: _textLo, fontSize: 11.5));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Button(
            onPressed: () =>
                Clipboard.setData(ClipboardData(text: info.ddl)),
            child: const Text('Copy', style: TextStyle(fontSize: 11)),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 120, maxHeight: 320),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _bg,
            border: Border.all(color: _hair),
            borderRadius: BorderRadius.circular(4),
          ),
          // Same highlighting as the editor. SQLite stores DDL exactly as it
          // was typed — often one long line — so it's also reflowed onto one
          // column per line before display.
          child: CodeEditor(
            readOnly: true,
            controller: CodeLineEditingController.fromText(_prettyDdl(info.ddl)),
            style: CodeEditorStyle(
              fontSize: 11.5,
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

  /// Breaks a single-line `CREATE TABLE t (a, b, c)` onto one column per line.
  ///
  /// Only splits at depth-1 commas, so a `NUMERIC(10,2)` or a composite
  /// `PRIMARY KEY (a, b)` isn't torn apart. Anything already multi-line (MySQL
  /// and Postgres both return formatted DDL) is left alone.
  static String _prettyDdl(String ddl) {
    if (ddl.contains('\n')) return ddl;
    final open = ddl.indexOf('(');
    final close = ddl.lastIndexOf(')');
    if (open < 0 || close <= open) return ddl;

    final head = ddl.substring(0, open).trimRight();
    final body = ddl.substring(open + 1, close);
    final tail = ddl.substring(close + 1);

    final parts = <String>[];
    final buf = StringBuffer();
    var depth = 0;
    var inString = false;
    for (var i = 0; i < body.length; i++) {
      final c = body[i];
      if (inString) {
        buf.write(c);
        if (c == "'") inString = false;
        continue;
      }
      if (c == "'") {
        inString = true;
        buf.write(c);
        continue;
      }
      if (c == '(') depth++;
      if (c == ')') depth--;
      if (c == ',' && depth == 0) {
        parts.add(buf.toString().trim());
        buf.clear();
        continue;
      }
      buf.write(c);
    }
    if (buf.toString().trim().isNotEmpty) parts.add(buf.toString().trim());
    if (parts.length < 2) return ddl;

    return '$head (\n  ${parts.join(',\n  ')}\n)$tail';
  }

  Widget _body(_Info info) {
    final pk = info.columns.where((c) => c.isPrimaryKey).toList();
    final fks = info.columns.where((c) => c.isForeignKey).toList();
    final nullable = info.columns.where((c) => c.nullable).length;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (info.stats.comment case final comment?) ...[
            Text(comment,
                style: const TextStyle(color: _textMid, fontSize: 12)),
            const SizedBox(height: 12),
          ],
          _rowsTile(info.stats),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _stat('Columns', '${info.columns.length}',
                    sub: '$nullable nullable'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _stat('Foreign keys', '${fks.length}',
                    // Distinct parents matter more than the raw column count:
                    // three columns pointing at one table is one dependency.
                    sub: fks.isEmpty
                        ? null
                        : '${_distinctTargets(fks)} table'
                            '${_distinctTargets(fks) == 1 ? "" : "s"}'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _stat('Indexes', '${info.indexes.length}',
                    sub: info.indexes.isEmpty
                        ? null
                        : '${info.indexes.where((i) => i.unique).length} '
                            'unique'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _stat('Size', _bytes(info.stats.totalBytes),
                    sub: info.stats.indexBytes == null
                        ? null
                        : '${_bytes(info.stats.indexBytes)} idx'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _typeBreakdown(info.columns),
          const SizedBox(height: 14),
          _section('Primary key',
              pk.isEmpty ? null : pk.map((c) => c.name).join(', '),
              // Worth stating plainly: it's why the grid won't let you edit.
              emptyNote: 'None — rows in this table cannot be edited in the '
                  'grid, since there is no way to address one.'),
          if (fks.isNotEmpty) ...[
            const SizedBox(height: 12),
            _collapsible(
              key: 'fk',
              title: 'Foreign keys',
              count: fks.length,
              children: [
                for (final c in _preview(fks))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text('${c.name} → ${c.references}',
                        style: const TextStyle(
                            color: _fk,
                            fontSize: 11.5,
                            fontFamily: 'monospace')),
                  ),
                if (fks.length > _inlineLimit) _seeAll(fks.length),
              ],
            ),
          ],
          if (info.referencedBy.isNotEmpty) ...[
            const SizedBox(height: 12),
            _collapsible(
              key: 'refby',
              title: 'Referenced by',
              count: info.referencedBy.length,
              subtitle: 'What depends on this table.',
              children: [
                for (final r in _preview(info.referencedBy))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text('$r',
                        style: const TextStyle(
                            color: _fk,
                            fontSize: 11.5,
                            fontFamily: 'monospace')),
                  ),
                if (info.referencedBy.length > _inlineLimit)
                  _seeAll(info.referencedBy.length),
              ],
            ),
          ],
          const SizedBox(height: 12),
          if (info.indexes.isEmpty) ...[
            _label('Indexes (0)'),
            const SizedBox(height: 4),
            const Text('None',
                style: TextStyle(color: _textLo, fontSize: 11.5)),
          ] else
            _collapsible(
              key: 'idx',
              title: 'Indexes',
              count: info.indexes.length,
              children: [
                for (final ix in info.indexes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      '${ix.unique ? "UNIQUE " : ""}${ix.name} '
                      '(${ix.columns.join(", ")})',
                      style: TextStyle(
                          color: ix.unique ? _accent : _textMid,
                          fontSize: 11.5,
                          fontFamily: 'monospace'),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  /// Row count, distinguishing an estimate from a real count — presenting a
  /// planner estimate as fact is how people end up mistrusting the whole panel.
  Widget _rowsTile(TableStats stats) {
    final exact = _exactRows;
    final estimate = stats.estimatedRows;
    final value = exact != null
        ? _number(exact)
        : (estimate != null ? '≈ ${_number(estimate)}' : 'Unknown');
    final sub = exact != null
        ? 'exact'
        : (estimate != null ? 'estimated from catalog statistics' : null);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _bg,
        border: Border.all(color: _hair),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label('Rows'),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        color: _text, fontSize: 18, fontFamily: 'monospace')),
                if (sub != null)
                  Text(sub,
                      style: const TextStyle(color: _textLo, fontSize: 10.5)),
              ],
            ),
          ),
          if (exact == null)
            Button(
              onPressed: _counting ? null : _countExactly,
              child: Text(_counting ? 'Counting…' : 'Count exactly',
                  style: const TextStyle(fontSize: 11)),
            ),
        ],
      ),
    );
  }

  /// What the table is *made of*, at a glance — a column count says how many,
  /// not what kind.
  Widget _typeBreakdown(List<ColumnInfo> columns) {
    final counts = <String, int>{};
    for (final c in columns) {
      // Group by base type: varchar(50) and varchar(255) are one kind here.
      final base = c.dataType.split('(').first.trim().toUpperCase();
      counts[base.isEmpty ? 'UNTYPED' : base] =
          (counts[base.isEmpty ? 'UNTYPED' : base] ?? 0) + 1;
    }
    // Grouped by meaning rather than by frequency: scanning a table's shape is
    // easier when every numeric type sits together, then dates, then text —
    // a count-descending list interleaves them arbitrarily.
    int rank(String type) => switch (_kindForType(type)) {
          ColumnEditorKind.integer || ColumnEditorKind.decimal => 0,
          ColumnEditorKind.date ||
          ColumnEditorKind.dateTime ||
          ColumnEditorKind.time =>
            1,
          ColumnEditorKind.text => 2,
          ColumnEditorKind.boolean => 3,
          ColumnEditorKind.enumeration => 4,
          ColumnEditorKind.json => 5,
          ColumnEditorKind.binary => 6,
        };
    final ordered = counts.entries.toList()
      ..sort((a, b) {
        final byKind = rank(a.key).compareTo(rank(b.key));
        if (byKind != 0) return byKind;
        return b.value == a.value
            ? a.key.compareTo(b.key)
            : b.value.compareTo(a.value);
      });
    if (ordered.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final e in ordered)
          HoverButton(
            // Clicking a type answers "which columns are those?" — the question
            // the count immediately raises.
            onPressed: () => setState(() {
              _typeFilter = e.key;
              _tab = 1;
            }),
            builder: (context, states) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: states.isHovered ? const Color(0x14FFFFFF) : _bg,
                border: Border.all(color: _hair),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text('${e.value} × ${e.key}',
                  style: TextStyle(
                      color: _colorForType(e.key),
                      fontSize: 10.5,
                      fontFamily: 'monospace')),
            ),
          ),
      ],
    );
  }

  static const _colors = SqlTypeColors.dark;

  /// Which Overview/Relations sections are collapsed. Long sections start
  /// collapsed — a table referenced by 959 others buries everything below it.
  final _collapsed = <String>{};

  bool _isCollapsed(String key, int count) =>
      _collapsed.contains(key) ||
      (!_collapsed.contains('!$key') && count > _inlineLimit);

  void _toggleSection(String key, int count) => setState(() {
        if (_isCollapsed(key, count)) {
          _collapsed
            ..remove(key)
            ..add('!$key'); // explicitly opened
        } else {
          _collapsed
            ..add(key)
            ..remove('!$key');
        }
      });

  /// Above this a section collapses by default and Overview shows a preview
  /// rather than the whole list.
  static const _inlineLimit = 8;

  /// Active Columns-tab filters.
  String? _typeFilter;
  bool _fkOnly = false;

  /// Follow a relation, in place.
  void _goTo(ColumnRef ref) {
    final next = TableInfo(
      name: ref.table,
      kind: ObjectKind.table,
      schema: ref.schema.isEmpty ? _table.schema : ref.schema,
    );
    if (next.name == _table.name && next.schema == _table.schema) return;
    setState(() {
      _back.add(_table);
      _table = next;
      _info = _load();
      _exactRows = null;
      _typeFilter = null;
      _fkOnly = false;
    });
  }

  void _goBack() {
    if (_back.isEmpty) return;
    setState(() {
      _table = _back.removeLast();
      _info = _load();
      _exactRows = null;
      _typeFilter = null;
      _fkOnly = false;
    });
  }

  ColumnEditorKind _kindForType(String dataType) =>
      ColumnEditorResolver(widget.engine)
          .resolve(dataType, nullable: true)
          .kind;

  /// How many *distinct* tables this one points at.
  static int _distinctTargets(List<ColumnInfo> fks) =>
      fks.map((c) => c.references?.table ?? '').toSet().length;

  /// Semantic kind for a column, via the same resolver that drives the grid's
  /// editors — so the colour and the editor always agree about what a type is.
  ColumnEditorKind _kindOf(ColumnInfo c) =>
      ColumnEditorResolver(widget.engine)
          .resolve(c.dataType, nullable: c.nullable)
          .kind;

  Color _colorForType(String dataType) => _colors.of(
      ColumnEditorResolver(widget.engine)
          .resolve(dataType, nullable: true)
          .kind);

  Widget _stat(String label, String value, {String? sub}) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _bg,
          border: Border.all(color: _hair),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label(label),
            const SizedBox(height: 2),
            Text(value,
                style: const TextStyle(
                    color: _text, fontSize: 15, fontFamily: 'monospace')),
            if (sub != null)
              Text(sub, style: const TextStyle(color: _textLo, fontSize: 10.5)),
          ],
        ),
      );

  Widget _section(String label, String? value, {required String emptyNote}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label),
          const SizedBox(height: 4),
          if (value == null)
            Text(emptyNote,
                style: const TextStyle(color: _textLo, fontSize: 11.5))
          else
            SelectableText(value,
                style: const TextStyle(
                    color: _accent, fontSize: 11.5, fontFamily: 'monospace')),
        ],
      );

  String _relationFilter = '';

  /// Substring, case-insensitive — table names here share long prefixes
  /// (`act_`, `ven_`), so prefix matching would filter almost nothing.
  List<ColumnRef> _filteredInbound(List<ColumnRef> all) {
    if (_relationFilter.isEmpty) return all;
    final needle = _relationFilter.toLowerCase();
    return all
        .where((r) =>
            r.table.toLowerCase().contains(needle) ||
            r.column.toLowerCase().contains(needle))
        .toList();
  }

  /// Overview shows a preview; the full list lives on Relations, which is built
  /// for it.
  List<T> _preview<T>(List<T> all) =>
      all.length <= _inlineLimit ? all : all.take(_inlineLimit).toList();

  Widget _seeAll(int total) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: HoverButton(
          onPressed: () => setState(() => _tab = 2),
          builder: (context, states) => Text(
            'and ${total - _inlineLimit} more — see Relations',
            style: const TextStyle(color: _accent, fontSize: 10.5),
          ),
        ),
      );

  /// A section that can be folded away, with its count in the header — so a
  /// list of 959 doesn't push everything else off the tab.
  Widget _collapsible({
    required String key,
    required String title,
    required int count,
    String? subtitle,
    required List<Widget> children,
    Widget? trailing,
  }) {
    final collapsed = _isCollapsed(key, count);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        HoverButton(
          onPressed: () => _toggleSection(key, count),
          builder: (context, states) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Icon(
                  collapsed
                      ? FluentIcons.chevron_right
                      : FluentIcons.chevron_down,
                  size: 8,
                  color: _textLo,
                ),
                const SizedBox(width: 6),
                _label('$title ($count)'),
                const SizedBox(width: 8),
                ?trailing,
              ],
            ),
          ),
        ),
        if (!collapsed) ...[
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(left: 14, bottom: 4),
              child: Text(subtitle,
                  style: const TextStyle(color: _textLo, fontSize: 10.5)),
            ),
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: children,
            ),
          ),
        ],
      ],
    );
  }

  Widget _label(String text) => Text(text.toUpperCase(),
      style: const TextStyle(
          color: _textLo,
          fontSize: 9.5,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600));

  static String _number(int n) {
    final s = '$n';
    final out = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
      out.write(s[i]);
    }
    return out.toString();
  }

  /// Null means the engine can't tell us — say so rather than printing "0 B",
  /// which reads as "this table is empty".
  static String _bytes(int? bytes) {
    if (bytes == null) return 'Unknown';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    final rounded = value >= 100 || unit == 0
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    return '$rounded ${units[unit]}';
  }
}

class _Info {
  const _Info({
    required this.columns,
    required this.indexes,
    required this.stats,
    required this.ddl,
    required this.referencedBy,
  });

  final List<ColumnInfo> columns;
  final List<IndexInfo> indexes;
  final TableStats stats;
  final String ddl;
  final List<ColumnRef> referencedBy;
}
