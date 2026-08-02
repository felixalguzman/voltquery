import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/repositories/settings_repository.dart';
import '../../../data/repositories/ui_state_repository.dart';
import '../../../data/services/font_catalog.dart';
import '../../../domain/models/app_settings.dart';
import '../history/history_providers.dart';

part 'settings_providers.g.dart';

@Riverpod(keepAlive: true)
SettingsRepository settingsRepository(Ref ref) =>
    SettingsRepository(ref.watch(localStoreProvider));

/// App-wide settings, synchronously readable.
///
/// A plain [AppSettings] rather than an `AsyncValue` because nearly every reader
/// is a widget that needs *a* value to render with — an editor can't wait on a
/// font size. It starts at the defaults and the stored values land a tick
/// later; anything that must not flicker on startup (the window title bar)
/// reads the repository directly before `runApp` instead.
@Riverpod(keepAlive: true)
class Settings extends _$Settings {
  /// True once something has been written through this notifier, so a slow
  /// initial read can't land on top of a change the user already made.
  bool _written = false;

  @override
  AppSettings build() {
    // A one-shot read, not `repository.watch()`: this notifier is the only
    // writer, so a drift stream would only ever echo back what we just set —
    // at the cost of a subscription that outlives every widget holding it.
    ref.read(settingsRepositoryProvider).read().then((loaded) {
      if (!_written && ref.mounted) state = loaded;
    });
    return const AppSettings();
  }

  /// Applies [next] immediately and persists it. Optimistic on purpose: a
  /// toggle that waits on a disk write before moving feels broken, and there is
  /// nothing to reconcile against — this is the only writer.
  Future<void> update(AppSettings next) async {
    _written = true;
    state = next;
    await ref.read(settingsRepositoryProvider).save(next);
  }

  /// Convenience for the common "change one field" case.
  Future<void> edit(AppSettings Function(AppSettings) change) =>
      update(change(state));

  Future<void> resetToDefaults() async {
    _written = true;
    state = const AppSettings();
    await ref.read(settingsRepositoryProvider).reset();
  }
}

@Riverpod(keepAlive: true)
UiStateRepository uiStateRepository(Ref ref) =>
    UiStateRepository(ref.watch(localStoreProvider));

/// Installed monospace families for the font picker. **keepAlive**: shelling
/// out to fontconfig once per app run is fine; once per dialog open is not.
@Riverpod(keepAlive: true)
Future<List<String>> monospaceFonts(Ref ref) =>
    const FontCatalog().monospaceFamilies();
