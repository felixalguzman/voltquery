import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/repositories/history_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'data/services/local_store.dart';
import 'ui/core/shell/app_shell.dart';
import 'ui/core/shell/window_chrome.dart';
import 'ui/features/history/history_providers.dart';
import 'ui/features/query_workspace/worksheet_providers.dart';
import 'ui/features/settings/vault_auto_lock.dart';

/// VoltQuery — futuristic cross-platform SQL database manager (DBeaver alt).
///
/// Architecture: `docs/design/architecture.md`. This first slice wires the
/// query workspace (re_editor → SQLite driver → pluto_grid) against a seeded
/// in-memory demo database. Shell, theming, and the rest land slice-by-slice.
/// [onContainerReady] is handed the app's [ProviderContainer] just before the
/// first frame. Nothing in the shipped app passes it — it exists so a debug
/// entrypoint (`test_driver/app.dart`) can attach the VM-service bridge to the
/// *real* app state rather than standing up a second container beside it.
Future<void> main({
  void Function(ProviderContainer container)? onContainerReady,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  // Clear demo temp DBs from earlier runs so the demo starts pristine (its path
  // is a fresh temp file per launch — see demoConnection).
  sweepDemoDbs();
  await initWindowChrome();

  // Opened here rather than lazily inside the provider so the title bar can be
  // settled *before* the first frame: reading it from the provider would show
  // the bar for a frame and then yank it, which reads as a glitch.
  final store = LocalStore();
  final settings = await SettingsRepository(store).read();
  await applyTitleBarVisibility(settings.titleBarVisible);

  if (settings.historyRetentionEnabled) {
    // Best-effort: a failed prune must not stop the app opening. Worst case the
    // history stays longer than asked, which is the harmless direction.
    try {
      await HistoryRepository(store).prune(
        keepDays: settings.historyRetentionDays,
        keepRows: settings.historyRetentionRows,
      );
    } catch (_) {}
  }

  // Built here rather than by `ProviderScope` so it can be handed out before
  // the first frame. It lives for the process, so there is nothing to dispose.
  final container = ProviderContainer(
    overrides: [localStoreProvider.overrideWithValue(store)],
  );
  onContainerReady?.call(container);

  runApp(UncontrolledProviderScope(
    container: container,
    child: const VoltQueryApp(),
  ));
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
  Widget build(BuildContext context) => const VaultAutoLock(
        child: ScaffoldPage(padding: EdgeInsets.zero, content: AppShell()),
      );
}
