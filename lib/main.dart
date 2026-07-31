import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ui/features/query_workspace/worksheet_providers.dart';
import 'ui/features/query_workspace/worksheet_view.dart';

/// VoltQuery — futuristic cross-platform SQL database manager (DBeaver alt).
///
/// Architecture: `docs/design/architecture.md`. This first slice wires the
/// query workspace (re_editor → SQLite driver → pluto_grid) against a seeded
/// in-memory demo database. Shell, theming, and the rest land slice-by-slice.
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

class _Home extends ConsumerWidget {
  const _Home();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Pre-warm the active session so the workspace is usable immediately.
    final session = ref.watch(sessionProvider);
    return ScaffoldPage(
      padding: EdgeInsets.zero,
      content: session.when(
        loading: () => const Center(child: ProgressRing()),
        error: (e, _) => Center(child: Text('Failed to open demo DB: $e')),
        data: (_) => const WorksheetView(),
      ),
    );
  }
}
