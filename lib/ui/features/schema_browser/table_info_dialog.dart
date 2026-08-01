import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';

import '../../../domain/models/schema.dart';
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
}) {
  return showDialog(
    context: context,
    builder: (context) => _TableInfoDialog(table: table, repo: repo),
  );
}

class _TableInfoDialog extends StatefulWidget {
  const _TableInfoDialog({required this.table, required this.repo});

  final TableInfo table;
  final SchemaRepository repo;

  @override
  State<_TableInfoDialog> createState() => _TableInfoDialogState();
}

class _TableInfoDialogState extends State<_TableInfoDialog> {
  late final Future<_Info> _info = _load();

  /// Filled only when the user asks — an exact count is a full scan.
  int? _exactRows;
  bool _counting = false;
  int _tab = 0;

  Future<_Info> _load() async {
    // Columns and indexes are already cached from expanding the tree, so this
    // is usually just the stats round-trip.
    final results = await Future.wait([
      widget.repo.columns(widget.table),
      widget.repo.indexes(widget.table),
      widget.repo.stats(widget.table),
      // Best-effort: a view or an engine that can't reproduce DDL shouldn't
      // fail the whole dialog.
      widget.repo.tableDdl(widget.table).catchError((_) => ''),
      widget.repo.referencedBy(widget.table).catchError((_) => <ColumnRef>[]),
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
      final n = await widget.repo.rowCount(widget.table);
      if (mounted) setState(() => _exactRows = n);
    } catch (_) {
      // A failed count shouldn't take the dialog down; the estimate stands.
    } finally {
      if (mounted) setState(() => _counting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.table;
    final qualified = t.schema.isEmpty ? t.name : '${t.schema}.${t.name}';
    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 560, maxHeight: 560),
      title: Row(
        children: [
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
                    2 => _ddlTab(info),
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
          for (final (i, label) in ['Overview', 'Columns', 'DDL'].indexed)
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
  Widget _columnsTab(_Info info) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final c in info.columns)
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
                    child: Text(
                      c.references != null
                          ? '→ ${c.references}'
                          : c.dataType,
                      style: TextStyle(
                          color: c.references != null ? _fk : _textMid,
                          fontSize: 11,
                          fontFamily: 'monospace'),
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
        ],
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
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _bg,
            border: Border.all(color: _hair),
            borderRadius: BorderRadius.circular(4),
          ),
          child: SelectableText(info.ddl,
              style: const TextStyle(
                  color: _text, fontSize: 11.5, fontFamily: 'monospace')),
        ),
      ],
    );
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
                child: _stat('Size', _bytes(info.stats.totalBytes),
                    sub: info.stats.indexBytes == null
                        ? null
                        : '${_bytes(info.stats.indexBytes)} indexes'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _section('Primary key',
              pk.isEmpty ? null : pk.map((c) => c.name).join(', '),
              // Worth stating plainly: it's why the grid won't let you edit.
              emptyNote: 'None — rows in this table cannot be edited in the '
                  'grid, since there is no way to address one.'),
          if (fks.isNotEmpty) ...[
            const SizedBox(height: 12),
            _label('Foreign keys'),
            const SizedBox(height: 4),
            for (final c in fks)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text('${c.name} → ${c.references}',
                    style: const TextStyle(
                        color: _fk, fontSize: 11.5, fontFamily: 'monospace')),
              ),
          ],
          if (info.referencedBy.isNotEmpty) ...[
            const SizedBox(height: 12),
            _label('Referenced by (${info.referencedBy.length})'),
            const SizedBox(height: 2),
            const Text('What depends on this table.',
                style: TextStyle(color: _textLo, fontSize: 10.5)),
            const SizedBox(height: 4),
            for (final r in info.referencedBy)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text('$r',
                    style: const TextStyle(
                        color: _fk, fontSize: 11.5, fontFamily: 'monospace')),
              ),
          ],
          const SizedBox(height: 12),
          _label('Indexes (${info.indexes.length})'),
          const SizedBox(height: 4),
          if (info.indexes.isEmpty)
            const Text('None',
                style: TextStyle(color: _textLo, fontSize: 11.5))
          else
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
