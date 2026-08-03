import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/volt_tokens.dart';

import '../../../domain/drivers/driver_error.dart';
import '../../../domain/models/column_editor.dart';
import '../../../domain/models/schema.dart';
import '../../core/theme/sql_type_colors.dart';
import '../../../domain/sql/sql_statement_splitter.dart';
import '../../core/menu/context_menu.dart';
import '../../core/widgets/filter_field.dart';
import '../../core/widgets/section_header.dart';
import '../query_workspace/worksheet_providers.dart';
import '../search/search_providers.dart';
import '../settings/settings_providers.dart';
import 'schema_providers.dart';
import 'schema_repository.dart';
import 'table_info_dialog.dart';

// TODO(theming #7): unify these tokens into ui/core/theme.
const _panel = VoltPalette.panel;
const _hair = VoltPalette.hairline;
const _accent = VoltPalette.accent;
const _text = VoltPalette.textHigh;
const _textMid = VoltPalette.textMid;
const _textLo = VoltPalette.textLow;
const _err = VoltPalette.danger;
const _mono = TextStyle(color: _text, fontSize: 12.5, fontFamily: 'monospace');

/// Left panel: the active connection's schema as a **lazy tree** (ADR-0008 /
/// issue #13). Every level loads on expand via the per-Connection
/// [SchemaRepository] — nothing below the visible node is introspected until you
/// open it. Postgres nests Schema → objects; SQLite/MySQL show objects directly.
/// Tapping an object loads `SELECT *` into the worksheet; expanding it (chevron)
/// reveals its columns.
class SchemaSidebar extends ConsumerWidget {
  const SchemaSidebar({super.key, this.collapsed = false, this.onToggle});

  final bool collapsed;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(schemaRepositoryProvider);
    // The sidebar/workspace divider is the pane resizer, not a border here —
    // drawing both doubles the line and overflows a collapsed section.
    return Container(
      decoration: const BoxDecoration(color: _panel),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(ref),
          if (!collapsed)
            FilterRow(
              state: ref.watch(schemaFilterProvider),
              placeholder: 'Filter tables, columns…',
              onChanged: ref.read(schemaFilterProvider.notifier).set,
            ),
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
    final filter = ref.watch(schemaFilterProvider);
    return SectionHeader(
      title: 'SCHEMA',
      collapsed: collapsed,
      onToggle: onToggle,
      actions: [
        IconButton(
          icon: Icon(FluentIcons.filter,
              size: 12, color: filter.open ? _accent : _textMid),
          onPressed: ref.read(schemaFilterProvider.notifier).toggle,
        ),
        IconButton(
          icon: const Icon(FluentIcons.refresh, size: 12, color: _textMid),
          onPressed: () => ref.invalidate(schemaRepositoryProvider),
        ),
      ],
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

  /// A flat model of everything the tree has loaded, kept alongside the
  /// `TreeViewItem`s so the filter has something to match against.
  ///
  /// The items themselves are widgets — matching would mean reading text back
  /// out of them. And rebuilding the tree per keystroke would throw away every
  /// lazy load and expansion, so filtering renders a **separate flat list**
  /// instead and leaves the tree untouched underneath.
  final _objects = <String, TableInfo>{};
  final _columns = <String, List<ColumnInfo>>{};

  /// The catalog leg of the filter.
  ///
  /// The inline filter used to stop at "no match in what is loaded", which is a
  /// dead end when almost nothing is loaded — the honest answer to "is there a
  /// `venta` table?" needs the catalog. So the box now escalates by itself
  /// instead of asking you to go open a different dialog.
  List<SchemaSearchHit> _remoteHits = const [];
  Object? _remoteError;
  bool _remoteBusy = false;
  String _remoteQuery = '';
  Timer? _remoteDebounce;

  /// Longer than the search dialog's: here the local hits are already on
  /// screen, so the catalog leg is a follow-up rather than the whole answer,
  /// and it can afford to wait for you to stop typing.
  static const _remoteDelay = Duration(milliseconds: 300);

  void _scheduleRemote(String query) {
    if (query == _remoteQuery) return;
    _remoteQuery = query;
    _remoteDebounce?.cancel();
    if (query.length < kMinSearchLength) {
      if (_remoteHits.isNotEmpty || _remoteBusy || _remoteError != null) {
        setState(() {
          _remoteHits = const [];
          _remoteBusy = false;
          _remoteError = null;
        });
      }
      return;
    }
    setState(() {
      _remoteBusy = true;
      _remoteError = null;
    });
    _remoteDebounce = Timer(_remoteDelay, () => _runRemote(query));
  }

  Future<void> _runRemote(String query) async {
    try {
      final hits = await widget.repo.search(query, limit: 60);
      // A slower earlier query must not overwrite a newer one's results.
      if (!mounted || query != _remoteQuery) return;
      setState(() {
        _remoteHits = hits;
        _remoteBusy = false;
      });
    } catch (e) {
      if (!mounted || query != _remoteQuery) return;
      setState(() {
        _remoteError = e;
        _remoteHits = const [];
        _remoteBusy = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadRoots();
  }

  @override
  void dispose() {
    _remoteDebounce?.cancel();
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
        content: ContextMenuRegion(
          actions: [
            MenuAction('Copy Name', () => _copy(s.name), icon: FluentIcons.copy)
          ],
          child: _row(
            Text(s.name, overflow: TextOverflow.ellipsis, style: _mono),
          ),
        ),
        lazy: true,
        value: _Loader(() async => _objectItems(await widget.repo.tables(s))),
        onExpandToggle: _onExpand,
      );

  List<TreeViewItem> _objectItems(List<TableInfo> all) {
    for (final t in all) {
      _objects[_keyOf(t)] = t;
    }
    return [
      for (final t in all.where((t) => t.kind == ObjectKind.table))
        _objectItem(t, FluentIcons.table),
      for (final t in all.where((t) => t.kind == ObjectKind.view))
        _objectItem(t, FluentIcons.page),
    ];
  }

  TreeViewItem _objectItem(TableInfo t, IconData icon) => TreeViewItem(
        // fluent hardcodes its expander chevron at 8px, which is a very small
        // target — miss it and the row press opens a worksheet instead. The
        // object icon doubles as a second, larger expand/collapse target.
        leading: _ExpandTap(
          onTap: () => _toggle(t),
          child: Icon(icon, size: 13, color: _textMid),
        ),
        content: ContextMenuRegion(
          actions: [
            MenuAction('Copy Name', () => _copy(t.name), icon: FluentIcons.copy),
            MenuAction('Copy CREATE',
                () => _copyDdl(() => widget.repo.tableDdl(t)),
                icon: FluentIcons.code),
            MenuAction.divider,
            MenuAction('Open in Editor', () => _openTable(t, run: false),
                icon: FluentIcons.open_file),
            MenuAction('Preview Data', () => _openTable(t, run: true),
                icon: FluentIcons.preview),
            MenuAction.divider,
            MenuAction('Table Info…', () => _showInfo(t),
                icon: FluentIcons.info),
          ],
          child: _row(Builder(builder: (context) {
            // The table you last opened stays marked, so after scrolling a few
            // hundred rows you can still see where you were.
            final isCurrent = _lastOpened == _keyOf(t);
            return Text(
              t.name,
              overflow: TextOverflow.ellipsis,
              style: isCurrent
                  ? _mono.copyWith(
                      color: _accent, fontWeight: FontWeight.w600)
                  : _mono,
            );
          })),
        ),
        lazy: true,
        // Columns show immediately on expand; indexes hang under a lazy folder.
        value: _Loader(() async {
          final cols = await widget.repo.columns(t);
          _columns[_keyOf(t)] = cols;
          return [..._columnItems(cols), _indexesFolder(t)];
        }),
        onInvoked: (item, reason) async {
          // The chevron also fires onInvoked(expandToggle) — ignore that; only a
          // row press opens the table (preview = seed + run).
          if (reason == TreeViewItemInvokeReason.expandToggle) return;
          _openTable(t, run: true);
        },
        onExpandToggle: _onExpand,
      );

  /// Expand/collapse the node for [t] — the leading icon's job (see
  /// [_ExpandTap]). Mirrors what the chevron does, including the lazy load.
  void _toggle(TableInfo t) {
    final item = _findObjectItem(t);
    if (item == null) return;
    final next = !item.expanded;
    setState(() => item.expanded = next);
    if (next) _onExpand(item, true);
  }

  TreeViewItem? _findObjectItem(TableInfo t) {
    for (final root in _roots ?? const <TreeViewItem>[]) {
      final hit = _search(root, t.name);
      if (hit != null) return hit;
    }
    return null;
  }

  /// Depth-first lookup by label — schemas nest their objects one level down.
  TreeViewItem? _search(TreeViewItem node, String name) {
    final content = node.content;
    if (content is ContextMenuRegion) {
      final child = content.child;
      if (child is Text && child.data == name) return node;
    }
    for (final c in node.children) {
      final hit = _search(c, name);
      if (hit != null) return hit;
    }
    return null;
  }

  /// Uniform vertical padding for every tree row.
  ///
  /// Two reasons beyond comfort: a dense list of near-identical names is hard
  /// to track a line through, and the sticky header maps scroll offset to a row
  /// index — which only works while every row is the same height. That's also
  /// why every label ellipsizes rather than wrapping.
  static Widget _row(Widget child) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: child,
      );

  // --- Context-menu actions --------------------------------------------------

  void _copy(String text) => Clipboard.setData(ClipboardData(text: text));

  /// Size, shape, keys and indexes without writing a query for any of it.
  void _showInfo(TableInfo t) => showTableInfoDialog(
        context,
        table: t,
        repo: widget.repo,
        engine: ref.read(currentConnectionProvider).engine,
      );

  /// Fetch DDL (cached in the repo) then copy it. Never leaves the clipboard
  /// empty — a fetch failure copies a `--`-commented note instead.
  Future<void> _copyDdl(Future<String> Function() fetch) async {
    try {
      _copy(await fetch());
    } catch (e) {
      _copy('-- Failed to load DDL: $e');
    }
  }

  /// Open [t] in a **new** worksheet tab (never clobbering the current editor).
  /// [run] = Preview Data (auto-run); false = Open in Editor (load only).
  /// Identity of the last table opened from the tree.
  String? _lastOpened;

  static String _keyOf(TableInfo t) => '${t.schema}.${t.name}';

  void _openTable(TableInfo t, {required bool run}) {
    setState(() => _lastOpened = _keyOf(t));
    // Hand focus back after a press. fluent's TreeViewItem requests focus on
    // press and only clears its `_focusedByPress` flag when the node *loses*
    // focus — so a row that keeps focus across the rebuild keeps drawing a
    // focus ring, and clicking several tables left a trail of outlined rows.
    // The editor is where you want the caret after opening a table anyway.
    FocusManager.instance.primaryFocus?.unfocus();

    // Already open? Go back to it. Spawning another tab for a table you're
    // already looking at is how you end up with thirteen worksheets.
    final tabs = ref.read(worksheetTabsProvider);
    final origins = ref.read(worksheetOriginsProvider.notifier);
    final existing = origins.find(_keyOf(t), tabs.ids);
    if (existing != null) {
      ref.read(worksheetTabsProvider.notifier).select(existing);
      return;
    }
    // Quote for the *connection's* dialect: MySQL reads "t" as a string
    // literal unless ANSI_QUOTES is on, so a double-quoted name is a syntax
    // error there. Qualify with the owning schema/database too — the tree can
    // browse outside the session's default, where a bare name would silently
    // resolve against the wrong one.
    final dialect = SqlDialect.of(ref.read(currentConnectionProvider).engine);
    final target = dialect.qualify(t.name, schema: t.schema);
    final id = ref.read(worksheetTabsProvider.notifier).add();
    final limit = ref.read(settingsProvider).tablePreviewLimit;
    ref
        .read(worksheetSeedsProvider.notifier)
        .put(id, 'SELECT * FROM $target LIMIT $limit;', autoRun: run);
    origins.put(id, _keyOf(t));
  }

  List<TreeViewItem> _columnItems(List<ColumnInfo> cols) => [
        for (final c in cols)
          TreeViewItem(
            collapsable: false,
            leading: Icon(
                c.isPrimaryKey
                    ? FluentIcons.permissions
                    : c.isForeignKey
                        ? FluentIcons.link
                        : FluentIcons.circle_ring,
                size: 11,
                color: c.isPrimaryKey
                    ? _accent
                    : c.isForeignKey
                        ? VoltPalette.violet
                        : _textLo),
            // Name sizes to content but capped at ~55% of the *actual* row
            // width (via LayoutBuilder — flex weights would reserve a fixed
            // share and truncate the type even with space free); the type takes
            // all remaining width and ellipsizes only when it genuinely can't
            // fit.
            content: ContextMenuRegion(
              actions: [
                MenuAction('Copy Name', () => _copy(c.name),
                    icon: FluentIcons.copy),
                if (c.references case final ref?)
                  MenuAction(
                    'Copy Referenced Table',
                    () => _copy(ref.table),
                    icon: FluentIcons.link,
                  ),
              ],
              child: _row(LayoutBuilder(builder: (context, cons) {
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
                    // A FK shows what it points at — the glyph alone said a
                    // reference existed but never where it went.
                    child: Text(
                        c.references == null
                            ? c.dataType
                            : '→ ${c.references}',
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        maxLines: 1,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            color: c.references != null
                                ? VoltPalette.violet
                                : SqlTypeColors.dark.of(
                                    ColumnEditorResolver(
                                            ref.read(currentConnectionProvider)
                                                .engine)
                                        .resolve(c.dataType,
                                            nullable: c.nullable)
                                        .kind),
                            fontSize: 10.5,
                            fontFamily: 'monospace')),
                  ),
                ]);
              })),
            ),
          ),
      ];

  /// The lazy "Indexes" group under a table/view.
  TreeViewItem _indexesFolder(TableInfo t) => TreeViewItem(
        leading: const Icon(FluentIcons.folder, size: 12, color: _textLo),
        content: _row(const Text('Indexes',
            style: TextStyle(
                color: _textMid, fontSize: 11.5, letterSpacing: 0.3))),
        lazy: true,
        value:
            _Loader(() async => _indexItems(t, await widget.repo.indexes(t))),
        onExpandToggle: _onExpand,
      );

  List<TreeViewItem> _indexItems(TableInfo t, List<IndexInfo> indexes) => [
        for (final ix in indexes)
          TreeViewItem(
            collapsable: false,
            leading: Icon(FluentIcons.number_symbol,
                size: 11, color: ix.unique ? _accent : _textLo),
            content: ContextMenuRegion(
              actions: [
                MenuAction('Copy Name', () => _copy(ix.name),
                    icon: FluentIcons.copy),
                MenuAction('Copy CREATE',
                    () => _copyDdl(() => widget.repo.indexDdl(t, ix)),
                    icon: FluentIcons.code),
              ],
              child: _row(Row(children: [
                Flexible(
                  child: Text(ix.name,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      maxLines: 1,
                      style: _mono.copyWith(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                      '${ix.unique ? 'UNIQUE ' : ''}(${ix.columns.join(', ')})',
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      maxLines: 1,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          color: ix.unique ? _accent : _textLo,
                          fontSize: 10.5,
                          fontFamily: 'monospace')),
                ),
              ])),
            ),
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

  /// Objects and loaded columns matching [filter], objects first.
  ///
  /// Instant, because it only looks at what the tree already has. Anything
  /// beyond that comes from [_remoteHits], which asks the catalog.
  (List<TableInfo>, List<(TableInfo, ColumnInfo)>) _matches(String filter) {
    final objects = <TableInfo>[];
    final columns = <(TableInfo, ColumnInfo)>[];
    for (final entry in _objects.entries) {
      final t = entry.value;
      if (matchesFilter(t.name, filter)) objects.add(t);
      for (final c in _columns[entry.key] ?? const <ColumnInfo>[]) {
        if (matchesFilter(c.name, filter)) columns.add((t, c));
      }
    }
    objects.sort((a, b) => a.name.compareTo(b.name));
    columns.sort((a, b) {
      final byTable = a.$1.name.compareTo(b.$1.name);
      return byTable != 0 ? byTable : a.$2.name.compareTo(b.$2.name);
    });
    return (objects, columns);
  }

  Widget _filtered(String filter) {
    final (objects, columns) = _matches(filter);
    // What the catalog found that isn't already above — keyed so a table the
    // tree has loaded isn't listed twice.
    final seen = {
      for (final t in objects) 'o:${_keyOf(t)}',
      for (final (t, c) in columns) 'c:${_keyOf(t)}.${c.name}',
    };
    final remote = [
      for (final h in _remoteHits)
        if (!seen.contains(h.isColumn
            ? 'c:${h.table.schema}.${h.table.name}.${h.name}'
            : 'o:${h.table.schema}.${h.table.name}'))
          h,
    ];

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        // Same grouping the search dialog uses, so the two read alike rather
        // than as two different features that happen to match names.
        if (objects.isNotEmpty) _group('TABLES & VIEWS', objects.length),
        for (final t in objects)
          _FilterHit(
            icon: t.kind == ObjectKind.view ? FluentIcons.page : FluentIcons.table,
            label: t.name,
            // Search has no sticky root header to say which schema you're
            // inside, so every hit carries its own.
            trailing: t.schema,
            actions: _objectActions(t),
            onTap: () => _openTable(t, run: true),
          ),
        if (columns.isNotEmpty) _group('COLUMNS', columns.length),
        for (final (t, c) in columns)
          _FilterHit(
            icon: c.isPrimaryKey
                ? FluentIcons.permissions
                : c.isForeignKey
                    ? FluentIcons.link
                    : FluentIcons.circle_ring,
            label: c.name,
            // The table is what makes a column name meaningful — `id` on its
            // own tells you nothing.
            trailing: t.schema.isEmpty ? t.name : '${t.schema}.${t.name}',
            actions: [
              MenuAction('Copy Column Name', () => _copy(c.name),
                  icon: FluentIcons.copy),
              MenuAction.divider,
              ..._objectActions(t),
            ],
            onTap: () => _openTable(t, run: true),
          ),
        // The catalog leg. Kept in its own group rather than merged in: these
        // are things the tree has never loaded, and saying where an answer came
        // from is the difference between a filter and a search.
        if (_remoteBusy)
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(children: [
              SizedBox(
                  width: 10,
                  height: 10,
                  child: ProgressRing(strokeWidth: 1.5)),
              SizedBox(width: 8),
              Flexible(
                child: Text('Searching database…',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _textLo, fontSize: 10)),
              ),
            ]),
          )
        else if (remote.isNotEmpty)
          _group('ELSEWHERE IN DB', remote.length),
        for (final h in remote)
          _FilterHit(
            icon: switch (h.kind) {
              SchemaHitKind.view => FluentIcons.page,
              SchemaHitKind.column => FluentIcons.circle_ring,
              SchemaHitKind.table => FluentIcons.table,
            },
            label: h.name,
            trailing: h.isColumn ? h.qualifiedTable : h.table.schema,
            actions: [
              if (h.isColumn) ...[
                MenuAction('Copy Column Name', () => _copy(h.name),
                    icon: FluentIcons.copy),
                MenuAction.divider,
              ],
              ..._objectActions(h.table),
            ],
            onTap: () => _openTable(h.table, run: true),
          ),
        if (_remoteError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Text('Could not search the database: $_remoteError',
                style: const TextStyle(color: _err, fontSize: 10, height: 1.3)),
          ),
        if (!_remoteBusy &&
            objects.isEmpty &&
            columns.isEmpty &&
            remote.isEmpty &&
            _remoteError == null)
          const _Message('No match.', color: _textLo),
      ],
    );
  }

  /// The same menu a tree node offers. A result you can't right-click is a
  /// worse version of the row you'd have found by scrolling.
  List<MenuAction> _objectActions(TableInfo t) => [
        MenuAction('Copy Name', () => _copy(t.name), icon: FluentIcons.copy),
        MenuAction('Copy CREATE', () => _copyDdl(() => widget.repo.tableDdl(t)),
            icon: FluentIcons.code),
        MenuAction.divider,
        MenuAction('Open in Editor', () => _openTable(t, run: false),
            icon: FluentIcons.open_file),
        MenuAction('Preview Data', () => _openTable(t, run: true),
            icon: FluentIcons.preview),
        MenuAction.divider,
        MenuAction('Table Info…', () => _showInfo(t), icon: FluentIcons.info),
      ];

  Widget _group(String label, int count) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        child: Row(children: [
          Flexible(
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: _textLo,
                    fontSize: 9,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 6),
          Text('$count',
              style: const TextStyle(
                  color: _textLo, fontSize: 9, fontFamily: 'monospace')),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    if (_error != null) return _Message('$_error', color: _err);
    final roots = _roots;
    if (roots == null) return const _Spinner();
    if (roots.isEmpty) return const _Message('(empty schema)', color: _textLo);

    final filter = ref.watch(schemaFilterProvider);
    if (filter.active) {
      // Scheduled from build so it follows the provider without a second
      // listener; _scheduleRemote no-ops when the query hasn't changed.
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => mounted ? _scheduleRemote(filter.text) : null);
      return _filtered(filter.text);
    }
    if (_remoteQuery.isNotEmpty) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => mounted ? _scheduleRemote('') : null);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Which expanded root you're inside, pinned while you scroll. In a
        // schema with hundreds of tables the header scrolls away immediately,
        // and collapsing it meant scrolling all the way back up to find it.
        if (_stickyRoot case final root?) _stickyHeader(root),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n is ScrollUpdateNotification ||
                    n is ScrollEndNotification) {
                  _updateSticky(n.metrics.pixels);
                }
                return false;
              },
              child: TreeView(
                controller: _controller,
                selectionMode: TreeViewSelectionMode.none,
                shrinkWrap: false,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Rows are a fixed height in fluent's TreeView, so the node at the top of the
  /// viewport is just an index into the flattened visible list — no layout
  /// measurement needed.
  /// Matches the padding in [_row] plus fluent's own row chrome. Uniform by
  /// construction — labels ellipsize, so nothing wraps to a second line.
  static const _rowHeight = 38.0;

  void _updateSticky(double pixels) {
    final roots = _roots;
    if (roots == null) return;
    final flat = <(TreeViewItem, TreeViewItem)>[]; // (node, its root)
    void walk(TreeViewItem node, TreeViewItem root) {
      flat.add((node, root));
      if (!node.expanded) return;
      for (final c in node.children) {
        walk(c, root);
      }
    }

    for (final r in roots) {
      walk(r, r);
    }

    final index = (pixels / _rowHeight).floor();
    // Only a *descendant* needs the reminder; sitting on the root itself
    // already shows it.
    final root = index > 0 && index < flat.length ? flat[index].$2 : null;
    final showFor = (root != null && flat[index].$1 != root) ? root : null;
    if (showFor != _stickyRoot) setState(() => _stickyRoot = showFor);
  }

  TreeViewItem? _stickyRoot;

  Widget _stickyHeader(TreeViewItem root) {
    final label = _labelOf(root) ?? '';
    return GestureDetector(
      // Tapping collapses it — the reason you were scrolling back up.
      //
      // Via the controller: setting `item.expanded` directly changes the model
      // without telling the TreeView to rebuild, so the tree stayed open and
      // only this header reacted.
      onTap: () {
        _controller.collapseItem(root);
        setState(() => _stickyRoot = null);
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          height: 24,
          padding: const EdgeInsets.only(left: 8, right: 6),
          decoration: const BoxDecoration(
            color: VoltPalette.panelAlt,
            border: Border(bottom: BorderSide(color: _hair)),
          ),
          child: Row(children: [
            const Icon(FluentIcons.chevron_down, size: 8, color: _textLo),
            const SizedBox(width: 8),
            const Icon(FluentIcons.database, size: 11, color: _textMid),
            const SizedBox(width: 6),
            Expanded(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: _textMid, fontSize: 11.5, fontFamily: 'monospace')),
            ),
            const Text('collapse',
                style: TextStyle(color: _textLo, fontSize: 9.5)),
          ]),
        ),
      ),
    );
  }

  /// The text a node renders, dug out of the ContextMenuRegion we wrap it in.
  static String? _labelOf(TreeViewItem node) {
    final content = node.content;
    if (content is ContextMenuRegion) {
      final child = content.child;
      if (child is Text) return child.data;
    }
    if (content is Text) return content.data;
    return null;
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

/// A larger tap target that sits on a tree node's leading icon and toggles
/// expansion, compensating for fluent's 8px chevron.
class _ExpandTap extends StatelessWidget {
  const _ExpandTap({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        // Fills the leading slot so the whole icon area is clickable, not just
        // the glyph.
        child: Center(child: child),
      ),
    );
  }
}

/// One row in the filtered flat list. Deliberately not a `TreeViewItem` —
/// filtering renders its own list so the tree underneath keeps every lazy load
/// and expansion it had, and comes back untouched when the box is cleared.
class _FilterHit extends StatelessWidget {
  const _FilterHit({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
    this.actions = const [],
  });

  final IconData icon;
  final String label;

  /// Where the hit lives — the owning table for a column, the schema for an
  /// object. Search has no sticky header to supply that context.
  final String? trailing;
  final VoidCallback onTap;
  final List<MenuAction> actions;

  @override
  Widget build(BuildContext context) {
    final row = _row(context);
    if (actions.isEmpty) return row;
    return ContextMenuRegion(actions: actions, child: row);
  }

  Widget _row(BuildContext context) {
    return HoverButton(
      onPressed: onTap,
      builder: (context, states) => Container(
        color: states.isHovered ? VoltPalette.accentTint : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(children: [
          Icon(icon, size: 11, color: _textMid),
          const SizedBox(width: 8),
          // Expanded, not Flexible: two Flexible children split the row evenly,
          // so the name was ellipsising at half width while the schema label
          // sat in space it didn't need. A Row lays inflexible children out
          // first, so the schema takes what it needs (capped) and the name gets
          // everything that's left.
          Expanded(
            child:
                Text(label, overflow: TextOverflow.ellipsis, style: _mono),
          ),
          if (trailing != null && trailing!.isNotEmpty) ...[
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Text(
                trailing!,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    color: _textLo, fontSize: 10.5, fontFamily: 'monospace'),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}
