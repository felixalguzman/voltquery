import 'package:base_menu/base_menu.dart';
import 'package:file_selector/file_selector.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:panes/panes.dart';

import '../../features/connections/connections_panel.dart';
import '../../features/history/history_panel.dart';
import '../../features/query_workspace/worksheet_providers.dart';
import '../../features/query_workspace/worksheet_tabs.dart';
import '../../features/schema_browser/schema_providers.dart';
import '../../features/schema_browser/schema_sidebar.dart';

// TODO(theming #7): unify tokens into ui/core/theme.
const _panel = Color(0xFF16181D);
const _hair = Color(0xFF262A31);
const _text = Color(0xFFE6E8EC);
const _textMid = Color(0xFF9BA1AD);
const _accent = Color(0xFF2FE6FF);

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
      PaneEntry(id: 'sidebar', initialSize: PaneSize.pixel(240)),
      PaneEntry(id: 'main', initialSize: PaneSize.fraction(1.0)),
    ],
  );
  final _fileMenu = MenuController();
  final _queryMenu = MenuController();
  final _viewMenu = MenuController();

  void _newTab() => ref.read(worksheetTabsProvider.notifier).add();
  void _dispatch(WorksheetCommand c) =>
      ref.read(worksheetCommandsProvider.notifier).dispatch(c);
  void _refreshSchema() => ref.invalidate(schemaRepositoryProvider);

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
      },
      child: ScrollConfiguration(
        behavior: const _AutoHideScrollBehavior(),
        child: FocusScope(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _menuBar(),
              Expanded(
                child: MultiPane(
                  direction: Axis.horizontal,
                  controller: _panes,
                  paneBuilder: (context, id, _) => switch (id) {
                    'sidebar' => const Column(
                      children: [
                        Expanded(flex: 2, child: ConnectionsPanel()),
                        Expanded(flex: 3, child: SchemaSidebar()),
                        Expanded(flex: 2, child: HistoryPanel()),
                      ],
                    ),
                    'main' => const WorksheetTabBar(),
                    _ => const SizedBox.shrink(),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
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
      child: BaseMenuBar(
        child: BaseMenuPanel(
          constraints: const BoxConstraints.tightFor(height: 30),
          children: [
            _topMenu(_fileMenu, 'File', [
              _MenuAction('New Worksheet', _newTab, accel: 'Ctrl+N'),
              _MenuAction('Open SQLite…', _openSqlite, accel: 'Ctrl+O'),
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
              _MenuAction('Refresh Schema', _refreshSchema),
            ]),
          ],
        ),
      ),
    );
  }

  /// A top-level menu (File/Query/View) as a BaseSubmenu with a styled anchor +
  /// a dark dropdown panel.
  Widget _topMenu(
      MenuController controller, String title, List<_MenuAction> actions) {
    return BaseSubmenu(
      controller: controller,
      requestCloseOnPointerExit: false,
      // Without an onPressed the anchor is tap-disabled (hover-only). Toggle so
      // clicking opens/closes too — the expected menubar behaviour.
      onPressed: () =>
          controller.isOpen ? controller.close() : controller.open(),
      menu: DecoratedBox(
        decoration: BoxDecoration(
          color: _panel,
          border: Border.all(color: _hair),
          borderRadius: BorderRadius.circular(6),
          boxShadow: const [
            BoxShadow(color: Color(0x66000000), blurRadius: 12, offset: Offset(0, 4)),
          ],
        ),
        child: BaseMenuPanel(
          constraints: const BoxConstraints.tightFor(width: 232),
          children: [
            const SizedBox(height: 4),
            for (final a in actions)
              a.isSeparator
                  ? const _MenuSeparator()
                  : BaseMenuItem(onPressed: a.onPressed, child: _MenuRow(a)),
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

/// A dropdown row: label + optional accelerator hint, focus-highlighted.
class _MenuRow extends StatelessWidget {
  const _MenuRow(this.action);
  final _MenuAction action;
  @override
  Widget build(BuildContext context) {
    final focused = BaseMenuItem.isFocusHighlightShownOf(context);
    return Container(
      color: focused ? _accent.withValues(alpha: 0.16) : null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(children: [
        Expanded(
          child: Text(action.label,
              style: const TextStyle(color: _text, fontSize: 12.5)),
        ),
        if (action.accel != null) ...[
          const SizedBox(width: 24),
          Text(action.accel!,
              style: const TextStyle(color: _textMid, fontSize: 11)),
        ],
      ]),
    );
  }
}

class _MenuSeparator extends StatelessWidget {
  const _MenuSeparator();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: SizedBox(height: 1, child: ColoredBox(color: _hair)),
      );
}
