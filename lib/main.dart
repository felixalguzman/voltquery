import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// VoltQuery — futuristic cross-platform SQL database manager (DBeaver alt).
///
/// Scaffold entry point. Architecture: `docs/design/architecture.md`.
/// The shell (fluent NavigationView + menu bar), theming (mix "Clean Dev-Tool"
/// tokens), and features are built slice-by-slice — start with SQLite
/// connect → query → grid (`docs/README.md`).
void main() {
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
      // TODO(theming #7): replace with Clean Dev-Tool tokens (cyan #2FE6FF,
      // near-black surfaces, sharp 4px corners) via mix in `ui/core/theme`.
      darkTheme: FluentThemeData(
        brightness: Brightness.dark,
        accentColor: Colors.teal,
      ),
      home: const _ScaffoldHome(),
    );
  }
}

class _ScaffoldHome extends StatelessWidget {
  const _ScaffoldHome();

  @override
  Widget build(BuildContext context) {
    return const ScaffoldPage(
      content: Center(
        child: Text('VoltQuery — scaffold. Build the SQLite slice next.'),
      ),
    );
  }
}
