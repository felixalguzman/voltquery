import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/drivers/driver_error.dart';
import '../../../domain/models/schema.dart';
import '../query_workspace/worksheet_providers.dart';
import 'schema_providers.dart';
import 'schema_repository.dart';

// TODO(theming #7): unify these tokens into ui/core/theme.
const _panel = Color(0xFF16181D);
const _hair = Color(0xFF262A31);
const _accent = Color(0xFF2FE6FF);
const _text = Color(0xFFE6E8EC);
const _textMid = Color(0xFF9BA1AD);
const _textLo = Color(0xFF5A6069);
const _err = Color(0xFFFF6B6B);
const _mono = TextStyle(color: _text, fontSize: 12.5, fontFamily: 'monospace');

/// Left panel: the active connection's schema as a **lazy tree** (ADR-0008 /
/// issue #13). Every level loads on expand via the per-Connection
/// [SchemaRepository] — nothing below the visible node is introspected until you
/// open it. Postgres nests Schema → objects; SQLite/MySQL show objects directly.
/// Tapping an object loads `SELECT *` into the worksheet; expanding it (chevron)
/// reveals its columns.
class SchemaSidebar extends ConsumerWidget {
  const SchemaSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(schemaRepositoryProvider);
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
            child: repo.when(
              loading: () => const _Spinner(),
              error: (e, _) => _Message('$e', color: _err),
              // Key by repo identity: invalidate → new repo → fresh tree state.
              data: (r) => _SchemaTree(r, key: ObjectKey(r)),
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
          onPressed: () => ref.invalidate(schemaRepositoryProvider),
        ),
      ]),
    );
  }
}

/// Carried in each expandable node's `value`: how to load its children, and a
/// latch so we fetch (and append) them at most once per node.
class _Loader {
  _Loader(this.load);
  final Future<List<TreeViewItem>> Function() load;
  bool loaded = false;
}

class _SchemaTree extends ConsumerStatefulWidget {
  const _SchemaTree(this.repo, {super.key});
  final SchemaRepository repo;

  @override
  ConsumerState<_SchemaTree> createState() => _SchemaTreeState();
}

class _SchemaTreeState extends ConsumerState<_SchemaTree> {
  final _controller = TreeViewController();
  List<TreeViewItem>? _roots;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadRoots();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadRoots() async {
    try {
      final repo = widget.repo;
      final roots = repo.capabilities.hasSchemas
          ? (await repo.schemas()).map(_schemaItem).toList()
          : _objectItems(await repo.tables(const SchemaInfo('')));
      if (!mounted) return;
      _controller.items = roots;
      setState(() => _roots = roots);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  // --- Node builders ---------------------------------------------------------

  TreeViewItem _schemaItem(SchemaInfo s) => TreeViewItem(
        leading: const Icon(FluentIcons.database, size: 13, color: _textMid),
        content: Text(s.name, style: _mono),
        lazy: true,
        value: _Loader(() async => _objectItems(await widget.repo.tables(s))),
        onExpandToggle: _onExpand,
      );

  List<TreeViewItem> _objectItems(List<TableInfo> all) => [
        for (final t in all.where((t) => t.kind == ObjectKind.table))
          _objectItem(t, FluentIcons.table),
        for (final t in all.where((t) => t.kind == ObjectKind.view))
          _objectItem(t, FluentIcons.page),
      ];

  TreeViewItem _objectItem(TableInfo t, IconData icon) => TreeViewItem(
        leading: Icon(icon, size: 13, color: _textMid),
        content: Text(t.name, overflow: TextOverflow.ellipsis, style: _mono),
        lazy: true,
        value: _Loader(() async => _columnItems(await widget.repo.columns(t))),
        onInvoked: (item, reason) async {
          // The chevron also fires onInvoked(expandToggle) — ignore that; only a
          // row press opens the table.
          if (reason == TreeViewItemInvokeReason.expandToggle) return;
          final name = t.name.replaceAll('"', '""');
          // Open in a NEW worksheet tab — never clobber the current editor.
          final id = ref.read(worksheetTabsProvider.notifier).add();
          ref
              .read(worksheetSeedsProvider.notifier)
              .put(id, 'SELECT * FROM "$name" LIMIT 200;');
        },
        onExpandToggle: _onExpand,
      );

  List<TreeViewItem> _columnItems(List<ColumnInfo> cols) => [
        for (final c in cols)
          TreeViewItem(
            collapsable: false,
            leading: Icon(
                c.isPrimaryKey ? FluentIcons.permissions : FluentIcons.circle_ring,
                size: 11, color: c.isPrimaryKey ? _accent : _textLo),
            // Name sizes to content but capped at ~55% of the *actual* row
            // width (via LayoutBuilder — flex weights would reserve a fixed
            // share and truncate the type even with space free); the type takes
            // all remaining width and ellipsizes only when it genuinely can't
            // fit.
            content: LayoutBuilder(builder: (context, cons) {
              return Row(children: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: cons.maxWidth * 0.55),
                  child: Text(c.name,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      maxLines: 1,
                      style: _mono.copyWith(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(c.dataType,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      maxLines: 1,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          color: _textLo,
                          fontSize: 10.5,
                          fontFamily: 'monospace')),
                ),
              ]);
            }),
          ),
      ];

  TreeViewItem _emptyItem() => TreeViewItem(
        collapsable: false,
        content: const Text('(empty)',
            style: TextStyle(
                color: _textLo, fontSize: 11.5, fontStyle: FontStyle.italic)),
      );

  /// Inline, resilient retry node — the node stays expandable; tapping re-runs
  /// the parent's loader (its latch was released on failure).
  TreeViewItem _retryItem(TreeViewItem parent, Object error) {
    final msg = error is DriverError ? error.message : '$error';
    return TreeViewItem(
      collapsable: false,
      content: Text('⚠ $msg — Retry',
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: _err, fontSize: 11.5)),
      onInvoked: (self, reason) async {
        _controller.removeItem(self);
        await _onExpand(parent, true);
      },
    );
  }

  // --- Lazy expand -----------------------------------------------------------

  Future<void> _onExpand(TreeViewItem item, bool getsExpanded) async {
    if (!getsExpanded) return;
    final loader = item.value;
    if (loader is! _Loader || loader.loaded) return;
    loader.loaded = true;
    try {
      final children = await loader.load();
      if (!mounted) return;
      _controller.addItems(
        children.isEmpty ? [_emptyItem()] : children,
        parent: item,
      );
    } catch (e) {
      if (!mounted) return;
      loader.loaded = false; // release the latch so Retry re-fetches
      _controller.addItem(_retryItem(item, e), parent: item);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return _Message('$_error', color: _err);
    final roots = _roots;
    if (roots == null) return const _Spinner();
    if (roots.isEmpty) return const _Message('(empty schema)', color: _textLo);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: TreeView(
        controller: _controller,
        selectionMode: TreeViewSelectionMode.none,
        shrinkWrap: false,
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();
  @override
  Widget build(BuildContext context) => const Center(
        child: SizedBox(
            width: 16, height: 16, child: ProgressRing(strokeWidth: 2)),
      );
}

class _Message extends StatelessWidget {
  const _Message(this.text, {required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(12),
        child: Text(text, style: TextStyle(color: color, fontSize: 11.5)),
      );
}
