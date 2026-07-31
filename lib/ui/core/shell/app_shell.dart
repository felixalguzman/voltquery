import 'package:flutter/widgets.dart';
import 'package:panes/panes.dart';

import '../../features/query_workspace/worksheet_tabs.dart';
import '../../features/schema_browser/schema_sidebar.dart';

/// The app shell: schema sidebar | workspace, in a resizable horizontal
/// `MultiPane`. First piece of `ui/core/shell` — grows into NavigationView +
/// menu bar + Worksheet tabs later.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _panes = PaneController(entries: [
    PaneEntry(id: 'sidebar', initialSize: PaneSize.pixel(240)),
    PaneEntry(id: 'main', initialSize: PaneSize.fraction(1.0)),
  ]);

  @override
  Widget build(BuildContext context) {
    return MultiPane(
      direction: Axis.horizontal,
      controller: _panes,
      paneBuilder: (context, id, _) => switch (id) {
        'sidebar' => const SchemaSidebar(),
        'main' => const WorksheetTabBar(),
        _ => const SizedBox.shrink(),
      },
    );
  }
}
