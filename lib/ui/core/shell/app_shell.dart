import 'dart:async';

import 'package:base_menu/base_menu.dart';
import 'package:file_selector/file_selector.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:panes/panes.dart';
import 'package:window_manager/window_manager.dart';

import '../../features/connections/connections_panel.dart';
import '../../features/connections/host_key_dialog.dart';
import '../../features/history/history_panel.dart';
import '../../features/query_workspace/worksheet_providers.dart';
import '../../features/query_workspace/worksheet_tabs.dart';
import '../../features/schema_browser/schema_providers.dart';
import '../../features/schema_browser/schema_sidebar.dart';
import '../../features/search/search_dialog.dart';
import '../../features/settings/settings_dialog.dart';
import '../../features/settings/settings_providers.dart';
import '../menu/app_menu.dart';
import '../widgets/section_header.dart';

// TODO(theming #7): unify tokens into ui/core/theme. Menu-panel chrome now lives
// in ui/core/menu/app_menu.dart (shared with the tree context menus, #53).
const _panel = Color(0xFF16181D);
const _hair = Color(0xFF262A31);
const _accent = Color(0xFF2FE6FF);
const _text = Color(0xFFE6E8EC);
const _textLo = Color(0xFF5A6069);

/// Auto-hiding scrollbars for the panels — fluent's default (Linux/Windows) keeps
/// a persistent vertical bar; `thumbVisibility: false` shows it only while
/// scrolling and fades it out otherwise.
class _AutoHideScrollBehavior extends FluentScrollBehavior {
  const _AutoHideScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    final vertical =
        details.direction == AxisDirection.up ||
        details.direction == AxisDirection.down;
    if (!vertical) return child;
    return Scrollbar(
      controller: details.controller,
      thumbVisibility: false,
      child: child,
    );
  }
}

/// The stacked sidebar sections, top to bottom. [weight] is the share of the
/// sidebar each takes before anyone drags anything — the schema tree gets the
/// most because it's the one you scroll.
enum _Section {
  connections('connections', 'Connections', FluentIcons.plug_connected, 0.28),
  schema('schema', 'Schema', FluentIcons.build_queue, 0.44),
  history('history', 'History', FluentIcons.history, 0.28);

  const _Section(this.id, this.title, this.icon, this.weight);
  final String id;
  final String title;
  final IconData icon;
  final double weight;
}

/// One square icon button in the menu bar's layout cluster. Tinted when the
/// panel it controls is showing, so the row reads as a set of states rather
/// than a row of identical glyphs.
class _LayoutToggle extends StatelessWidget {
  const _LayoutToggle({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: HoverButton(
        onPressed: onPressed,
        builder: (context, states) => Container(
          width: 24,
          height: 22,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: states.isHovered ? const Color(0x14FFFFFF) : null,
            borderRadius: BorderRadius.circular(3),
          ),
          child: Icon(icon, size: 12, color: active ? _accent : _textLo),
        ),
      ),
    );
  }
}

/// The app shell: a **menu bar** over the schema sidebar | workspace split.
/// Menu commands + **app-wide shortcuts** (⌃⏎ Run, Ctrl+N/O, F5) are handled
/// here and routed to the active Worksheet via [WorksheetCommands] — so Run
/// works regardless of what holds focus (fixes chaining after a run). NavigationView
/// comes later (#21).
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final _panes = PaneController(
    entries: [
      PaneEntry(
        id: 'sidebar',
        initialSize: PaneSize.pixel(240),
        minSize: PaneSize.pixel(160),
        // Drag the splitter shut and the sidebar hides itself, rather than
        // sticking at its minimum. View → Sidebar (Ctrl+B) brings it back.
        autoHide: true,
      ),
      PaneEntry(id: 'main', initialSize: PaneSize.fraction(1.0)),
    ],
  );

  /// The three stacked sidebar sections, resizable against each other.
  ///
  /// Fractions rather than fixed heights so the split survives a window resize;
  /// [_sectionEntry] swaps a section to a header-height **pixel** pane when it
  /// collapses. The type change is what makes that stick — `updatePane` only
  /// clears a dragged size override when pixel/fraction changes.
  late final _sections = PaneController(
    entries: [for (final s in _Section.values) _sectionEntry(s)],
  );

  final _collapsed = <_Section>{};

  /// Layout is saved on a trailing debounce: a splitter drag fires
  /// `notifyListeners` every frame, and a drift write per frame would be
  /// absurd. 600ms after you let go is soon enough — the only way to lose a
  /// layout change is to quit within that window.
  Timer? _saveLayout;
  bool _layoutRestored = false;

  PaneEntry _sectionEntry(_Section s) => _collapsed.contains(s)
      ? PaneEntry(
          id: s.id,
          initialSize: PaneSize.pixel(kSectionHeaderHeight),
          minSize: PaneSize.pixel(kSectionHeaderHeight),
          maxSize: PaneSize.pixel(kSectionHeaderHeight),
        )
      : PaneEntry(
          id: s.id,
          initialSize: PaneSize.fraction(s.weight),
          minSize: PaneSize.pixel(72),
        );

  void _toggleSection(_Section s) {
    setState(() {
      _collapsed.contains(s) ? _collapsed.remove(s) : _collapsed.add(s);
    });
    _sections.updatePane(_sectionEntry(s));
    _scheduleLayoutSave();
  }

  void _toggleSidebar() => _panes.toggle('sidebar');

  /// Restores the saved layout: what was collapsed first, then the sizes.
  ///
  /// Order matters — collapsing swaps a section's pane between fraction and
  /// pixel, and `PaneController.load` writes into whichever map the entry is
  /// using. Sizes applied before the collapse state would land in the wrong one
  /// and be ignored.
  Future<void> _restoreLayout() async {
    final ui = ref.read(uiStateRepositoryProvider);
    final collapsed = await ui.collapsedSections();
    if (!mounted) return;

    if (collapsed.isNotEmpty) {
      setState(() {
        _collapsed
          ..clear()
          ..addAll(_Section.values.where((s) => collapsed.contains(s.id)));
      });
      for (final s in _collapsed) {
        _sections.updatePane(_sectionEntry(s));
      }
    }

    final shell = await ui.paneLayout('paneLayout.shell');
    final sections = await ui.paneLayout('paneLayout.sections');
    if (!mounted) return;
    if (shell != null) _panes.load(shell);
    if (sections != null) _sections.load(sections);

    // Only start listening once the restore is in: `load` notifies, and saving
    // in response would just rewrite what we read.
    _layoutRestored = true;
    _panes.addListener(_scheduleLayoutSave);
    _sections.addListener(_scheduleLayoutSave);
  }

  void _scheduleLayoutSave() {
    if (!_layoutRestored) return;
    _saveLayout?.cancel();
    _saveLayout = Timer(const Duration(milliseconds: 600), _persistLayout);
  }

  Future<void> _persistLayout() async {
    final ui = ref.read(uiStateRepositoryProvider);
    await ui.saveCollapsedSections({for (final s in _collapsed) s.id});
    await ui.savePaneLayout('paneLayout.shell', _panes.save());
    await ui.savePaneLayout('paneLayout.sections', _sections.save());
  }

  final _fileMenu = MenuController();
  final _editMenu = MenuController();
  final _queryMenu = MenuController();
  final _viewMenu = MenuController();

  /// True while any top menu is open — then hovering a sibling switches to it
  /// (standard menubar). When nothing is open, hover does nothing.
  bool _barOpen = false;

  void _onMenuOpen() {
    if (!_barOpen) setState(() => _barOpen = true);
  }

  void _onMenuClose() {
    // On a hover-switch one closes as another opens; settle before checking.
    Future.microtask(() {
      if (!mounted) return;
      final any = _fileMenu.isOpen ||
          _editMenu.isOpen ||
          _queryMenu.isOpen ||
          _viewMenu.isOpen;
      if (any != _barOpen) setState(() => _barOpen = any);
    });
  }

  @override
  void dispose() {
    _saveLayout?.cancel();
    _panes.removeListener(_scheduleLayoutSave);
    _sections.removeListener(_scheduleLayoutSave);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // The tunnel refuses an unrecognised bastion unless something can ask the
    // user about it; registering here is what turns "fail closed" into a
    // prompt. Deferred a frame so the first build isn't mutating a provider.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _restoreLayout();
      ref.read(hostKeyPromptProvider.notifier).register(
        (verdict, fingerprint) async {
          if (!mounted) return false;
          final conn = ref.read(currentConnectionProvider);
          return showHostKeyDialog(
            context,
            verdict: verdict,
            host: conn.options.ssh.host,
            port: conn.options.ssh.port,
            fingerprint: fingerprint,
          );
        },
      );
    });
  }

  void _newTab() => ref.read(worksheetTabsProvider.notifier).add();
  void _dispatch(WorksheetCommand c) =>
      ref.read(worksheetCommandsProvider.notifier).dispatch(c);
  void _refreshSchema() => ref.invalidate(schemaRepositoryProvider);

  Future<void> _openSettings() => showSettingsDialog(context);

  Future<void> _openSearch() => showSearchDialog(context);

  /// File → Quit. Present because hiding the title bar (Settings → Window)
  /// takes the OS close button with it — the app must stay closable from
  /// inside itself.
  Future<void> _quit() => windowManager.close();

  Future<void> _openSqlite() async {
    const group = XTypeGroup(
      label: 'SQLite',
      extensions: ['db', 'sqlite', 'sqlite3'],
    );
    final file = await openFile(acceptedTypeGroups: const [group]);
    if (file != null && mounted) {
      ref.read(currentConnectionProvider.notifier).openFile(file.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, control: true): () =>
            _dispatch(WorksheetCommand.runSmart),
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): () =>
            _dispatch(WorksheetCommand.runSmart),
        const SingleActivator(LogicalKeyboardKey.f5): () =>
            _dispatch(WorksheetCommand.runWhole),
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): _newTab,
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true): _newTab,
        const SingleActivator(LogicalKeyboardKey.keyO, control: true):
            _openSqlite,
        const SingleActivator(LogicalKeyboardKey.keyO, meta: true): _openSqlite,
        const SingleActivator(LogicalKeyboardKey.comma, control: true):
            _openSettings,
        const SingleActivator(LogicalKeyboardKey.comma, meta: true):
            _openSettings,
        const SingleActivator(LogicalKeyboardKey.keyQ, control: true): _quit,
        const SingleActivator(LogicalKeyboardKey.keyQ, meta: true): _quit,
        const SingleActivator(LogicalKeyboardKey.keyF,
            control: true, shift: true): _openSearch,
        const SingleActivator(LogicalKeyboardKey.keyF,
            meta: true, shift: true): _openSearch,
        const SingleActivator(LogicalKeyboardKey.keyB, control: true):
            _toggleSidebar,
        const SingleActivator(LogicalKeyboardKey.keyB, meta: true):
            _toggleSidebar,
      },
      child: ScrollConfiguration(
        behavior: const _AutoHideScrollBehavior(),
        child: FocusScope(
          // A 1px line you can grab 5px either side of: visible enough to read
          // as a boundary, forgiving enough to hit. The package's own
          // zero-space example makes the same split between drawn and
          // hit-tested thickness.
          child: PaneTheme(
            data: const PaneThemeData(
              resizerThickness: 1,
              resizerHitTestThickness: 11,
              resizerColor: _hair,
              resizerHoverColor: _accent,
              resizerFocusedColor: _accent,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _menuBar(),
                Expanded(
                  child: MultiPane(
                    direction: Axis.horizontal,
                    controller: _panes,
                    paneBuilder: (context, id, _) => switch (id) {
                      'sidebar' => _sidebar(),
                      'main' => const WorksheetTabBar(),
                      _ => const SizedBox.shrink(),
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Connections / Schema / History stacked and resizable. Each collapses to
  /// its own header, in place — so a collapsed section is still the thing you
  /// click to bring it back, and the order never shuffles.
  Widget _sidebar() {
    return MultiPane(
      direction: Axis.vertical,
      controller: _sections,
      paneBuilder: (context, id, _) => switch (id) {
        'connections' => ConnectionsPanel(
            collapsed: _collapsed.contains(_Section.connections),
            onToggle: () => _toggleSection(_Section.connections),
          ),
        'schema' => SchemaSidebar(
            collapsed: _collapsed.contains(_Section.schema),
            onToggle: () => _toggleSection(_Section.schema),
          ),
        'history' => HistoryPanel(
            collapsed: _collapsed.contains(_Section.history),
            onToggle: () => _toggleSection(_Section.history),
          ),
        _ => const SizedBox.shrink(),
      },
    );
  }

  Widget _menuBar() {
    return Container(
      height: 30,
      decoration: const BoxDecoration(
        color: _panel,
        border: Border(bottom: BorderSide(color: _hair)),
      ),
      alignment: Alignment.centerLeft,
      child: Row(children: [
        _menus(),
        // The empty strip beside the menus drags the window. With the title bar
        // hidden (Settings → Window) this is the only grab handle left, and on
        // a tiling WM it costs nothing.
        const Expanded(
          child: DragToMoveArea(child: SizedBox.expand()),
        ),
        ..._layoutToggles(),
        const SizedBox(width: 6),
      ]),
    );
  }

  /// Layout toggles at the right of the bar — the same place VS Code puts them,
  /// and what the `panes` example does with its title-bar actions.
  ///
  /// The View menu still lists all of these: the menu is for discovery and
  /// keyboard access, these are for the third time in a minute you want the
  /// history panel out of the way.
  List<Widget> _layoutToggles() {
    return [
      // The sidebar's visibility lives in the controller, not in our state —
      // dragging the splitter shut flips it without any setState here — so the
      // tint has to follow the controller directly.
      ListenableBuilder(
        listenable: _panes,
        builder: (context, _) => _LayoutToggle(
          icon: FluentIcons.dock_left,
          tooltip: 'Toggle Sidebar (Ctrl+B)',
          active: _panes.isVisible('sidebar'),
          onPressed: _toggleSidebar,
        ),
      ),
      Container(
        width: 1,
        height: 14,
        margin: const EdgeInsets.symmetric(horizontal: 5),
        color: _hair,
      ),
      for (final s in _Section.values)
        _LayoutToggle(
          icon: s.icon,
          tooltip: '${_collapsed.contains(s) ? 'Expand' : 'Collapse'} ${s.title}',
          active: !_collapsed.contains(s),
          onPressed: () => _toggleSection(s),
        ),
    ];
  }

  Widget _menus() {
    return BaseMenuBar(
        child: BaseMenuPanel(
          constraints: const BoxConstraints.tightFor(height: 30),
          children: [
            _topMenu(_fileMenu, 'File', [
              _MenuAction('New Worksheet', _newTab, accel: 'Ctrl+N'),
              _MenuAction('Open SQLite…', _openSqlite, accel: 'Ctrl+O'),
              _MenuAction.separator,
              _MenuAction('Settings…', _openSettings, accel: 'Ctrl+,'),
              _MenuAction.separator,
              _MenuAction('Quit', _quit, accel: 'Ctrl+Q'),
            ]),
            _topMenu(_editMenu, 'Edit', [
              _MenuAction('Search Everything…', _openSearch,
                  accel: 'Ctrl+Shift+F'),
            ]),
            _topMenu(_queryMenu, 'Query', [
              _MenuAction('Run', () => _dispatch(WorksheetCommand.runSmart),
                  accel: 'Ctrl+Enter'),
              _MenuAction('Run Script', () => _dispatch(WorksheetCommand.runWhole),
                  accel: 'F5'),
              _MenuAction(
                  'Run at Cursor', () => _dispatch(WorksheetCommand.runAtCursor)),
              _MenuAction(
                  'Run Selection', () => _dispatch(WorksheetCommand.runSelection)),
              _MenuAction.separator,
              _MenuAction('Cancel', () => _dispatch(WorksheetCommand.cancel)),
            ]),
            _topMenu(_viewMenu, 'View', [
              _MenuAction('Toggle Sidebar', _toggleSidebar, accel: 'Ctrl+B'),
              _MenuAction.separator,
              for (final s in _Section.values)
                _MenuAction(
                  '${_collapsed.contains(s) ? 'Expand' : 'Collapse'} ${s.title}',
                  () => _toggleSection(s),
                ),
              _MenuAction.separator,
              _MenuAction('Refresh Schema', _refreshSchema),
            ]),
          ],
        ),
    );
  }

  /// A top-level menu (File/Query/View) as a BaseSubmenu with a styled anchor +
  /// a dark dropdown panel.
  Widget _topMenu(
      MenuController controller, String title, List<_MenuAction> actions) {
    return BaseSubmenu(
      controller: controller,
      // Click opens; once the bar is active, hovering a sibling switches to it.
      requestOpenOnPointerEnter: _barOpen,
      requestCloseOnPointerExit: false,
      onOpen: _onMenuOpen,
      onClose: _onMenuClose,
      onPressed: () =>
          controller.isOpen ? controller.close() : controller.open(),
      menu: MenuSurface(
        child: BaseMenuPanel(
          constraints: const BoxConstraints.tightFor(width: 232),
          children: [
            const SizedBox(height: 4),
            for (final a in actions)
              a.isSeparator
                  ? const MenuDivider()
                  : BaseMenuItem(
                      onPressed: a.onPressed,
                      child: MenuActionRow(a.label, accel: a.accel),
                    ),
            const SizedBox(height: 4),
          ],
        ),
      ),
      child: _TopLabel(title),
    );
  }
}

/// One dropdown action (or a separator sentinel).
class _MenuAction {
  const _MenuAction(this.label, this.onPressed, {this.accel})
      : isSeparator = false;
  const _MenuAction._sep()
      : label = '',
        onPressed = _noop,
        accel = null,
        isSeparator = true;

  static const separator = _MenuAction._sep();
  static void _noop() {}

  final String label;
  final VoidCallback onPressed;
  final String? accel;
  final bool isSeparator;
}

/// Top-bar menu button with hover highlight.
class _TopLabel extends StatefulWidget {
  const _TopLabel(this.title);
  final String title;
  @override
  State<_TopLabel> createState() => _TopLabelState();
}

class _TopLabelState extends State<_TopLabel> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Container(
        color: _hover ? const Color(0x14FFFFFF) : null,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        child: Text(widget.title,
            style: const TextStyle(color: _text, fontSize: 12.5)),
      ),
    );
  }
}

