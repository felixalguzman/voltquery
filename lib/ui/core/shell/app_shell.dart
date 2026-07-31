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
  final _panes = PaneController(entries: [
    PaneEntry(id: 'sidebar', initialSize: PaneSize.pixel(240)),
    PaneEntry(id: 'main', initialSize: PaneSize.fraction(1.0)),
  ]);

  void _newTab() => ref.read(worksheetTabsProvider.notifier).add();
  void _dispatch(WorksheetCommand c) =>
      ref.read(worksheetCommandsProvider.notifier).dispatch(c);
  void _refreshSchema() => ref.invalidate(schemaRepositoryProvider);

  Future<void> _openSqlite() async {
    const group = XTypeGroup(label: 'SQLite', extensions: ['db', 'sqlite', 'sqlite3']);
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
        const SingleActivator(LogicalKeyboardKey.keyO, control: true): _openSqlite,
        const SingleActivator(LogicalKeyboardKey.keyO, meta: true): _openSqlite,
      },
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
      child: MenuBar(
        items: [
          MenuBarItem(title: 'File', items: [
            MenuFlyoutItem(
                text: const Text('New Worksheet     Ctrl+N'),
                onPressed: _newTab),
            MenuFlyoutItem(
                text: const Text('Open SQLite…      Ctrl+O'),
                onPressed: _openSqlite),
          ]),
          MenuBarItem(title: 'Query', items: [
            MenuFlyoutItem(
                text: const Text('Run               Ctrl+Enter'),
                onPressed: () => _dispatch(WorksheetCommand.runSmart)),
            MenuFlyoutItem(
                text: const Text('Run Script        F5'),
                onPressed: () => _dispatch(WorksheetCommand.runWhole)),
            MenuFlyoutItem(
                text: const Text('Run at Cursor'),
                onPressed: () => _dispatch(WorksheetCommand.runAtCursor)),
            MenuFlyoutItem(
                text: const Text('Run Selection'),
                onPressed: () => _dispatch(WorksheetCommand.runSelection)),
            const MenuFlyoutSeparator(),
            MenuFlyoutItem(
                text: const Text('Cancel'),
                onPressed: () => _dispatch(WorksheetCommand.cancel)),
          ]),
          MenuBarItem(title: 'View', items: [
            MenuFlyoutItem(
                text: const Text('Refresh Schema'), onPressed: _refreshSchema),
          ]),
        ],
      ),
    );
  }
}
