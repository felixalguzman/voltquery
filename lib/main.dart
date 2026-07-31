import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ui/core/shell/app_shell.dart';
import 'ui/features/query_workspace/worksheet_providers.dart';

/// VoltQuery — futuristic cross-platform SQL database manager (DBeaver alt).
///
/// Architecture: `docs/design/architecture.md`. This first slice wires the
/// query workspace (re_editor → SQLite driver → pluto_grid) against a seeded
/// in-memory demo database. Shell, theming, and the rest land slice-by-slice.
void main() {
  // Clear demo temp DBs from earlier runs so the demo starts pristine (its path
  // is a fresh temp file per launch — see demoConnection).
  sweepDemoDbs();
  // TODO(build): window_manager setup (size, min-size, title) before runApp.
  runApp(const ProviderScope(child: VoltQueryApp()));
}

class VoltQueryApp extends StatelessWidget {
  const VoltQueryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FluentApp(
      title: 'VoltQuery',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      // TODO(theming #7): Clean Dev-Tool tokens via mix in `ui/core/theme`.
      darkTheme: FluentThemeData(
        brightness: Brightness.dark,
        accentColor: Colors.teal,
        scaffoldBackgroundColor: const Color(0xFF0D0E11),
      ),
      home: const _Home(),
    );
  }
}

class _Home extends StatelessWidget {
  const _Home();

  @override
  // The shell always renders — a connection failure must never brick the app.
  // Session errors surface inline (schema sidebar / worksheet result), and the
  // Connections panel stays reachable to unlock the vault or switch connections.
  Widget build(BuildContext context) =>
      const ScaffoldPage(padding: EdgeInsets.zero, content: AppShell());
}
