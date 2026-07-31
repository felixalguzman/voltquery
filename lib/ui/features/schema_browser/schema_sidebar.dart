import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/schema.dart';
import '../query_workspace/worksheet_providers.dart';

// TODO(theming #7): unify these tokens into ui/core/theme.
const _panel = Color(0xFF16181D);
const _hair = Color(0xFF262A31);
const _accent = Color(0xFF2FE6FF);
const _textMid = Color(0xFF9BA1AD);
const _textLo = Color(0xFF5A6069);

/// Left panel listing the active connection's tables + views (via the tested
/// `SchemaIntrospector`). Clicking an object loads `SELECT * FROM …` into the
/// worksheet and runs it. First piece of the schema browser (issue #13).
class SchemaSidebar extends ConsumerWidget {
  const SchemaSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tables = ref.watch(schemaTablesProvider);
    return Container(
      decoration: const BoxDecoration(
        color: _panel,
        border: Border(right: BorderSide(color: _hair)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(ref),
          Expanded(
            child: tables.when(
              loading: () => const Center(
                  child: SizedBox(
                      width: 16, height: 16, child: ProgressRing(strokeWidth: 2))),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(12),
                child: Text('$e',
                    style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 11)),
              ),
              data: (list) => _list(ref, list),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(WidgetRef ref) {
    return Container(
      height: 34,
      padding: const EdgeInsets.only(left: 12, right: 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _hair)),
      ),
      child: Row(children: [
        const Text('SCHEMA',
            style: TextStyle(
                color: _textLo,
                fontSize: 10.5,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w600)),
        const Spacer(),
        IconButton(
          icon: const Icon(FluentIcons.refresh, size: 12, color: _textMid),
          onPressed: () => ref.invalidate(schemaTablesProvider),
        ),
      ]),
    );
  }

  Widget _list(WidgetRef ref, List<TableInfo> all) {
    final tables = all.where((t) => t.kind == ObjectKind.table).toList();
    final views = all.where((t) => t.kind == ObjectKind.view).toList();
    if (all.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('(no tables)', style: TextStyle(color: _textLo, fontSize: 12)),
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 6),
      children: [
        if (tables.isNotEmpty) _group('Tables', tables.length),
        for (final t in tables) _row(ref, t, FluentIcons.table),
        if (views.isNotEmpty) _group('Views', views.length),
        for (final v in views) _row(ref, v, FluentIcons.page),
      ],
    );
  }

  Widget _group(String label, int count) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 3),
        child: Text('$label · $count',
            style: const TextStyle(
                color: _textLo, fontSize: 10, letterSpacing: 1.0)),
      );

  Widget _row(WidgetRef ref, TableInfo t, IconData icon) {
    return HoverButton(
      onPressed: () {
        final name = t.name.replaceAll('"', '""');
        ref
            .read(requestedQueryProvider.notifier)
            .request('SELECT * FROM "$name" LIMIT 200;');
      },
      builder: (context, states) => Container(
        color: states.isHovered ? _accent.withValues(alpha: 0.10) : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: Row(children: [
          Icon(icon, size: 13, color: _textMid),
          const SizedBox(width: 8),
          Expanded(
            child: Text(t.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Color(0xFFE6E8EC),
                    fontSize: 12.5,
                    fontFamily: 'monospace')),
          ),
        ]),
      ),
    );
  }
}
