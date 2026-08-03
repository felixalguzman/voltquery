import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:voltquery/data/repositories/settings_repository.dart';
import 'package:voltquery/data/repositories/ui_state_repository.dart';
import 'package:voltquery/data/services/local_store.dart';
import 'package:voltquery/domain/models/app_settings.dart';

/// Window ephemera shares the settings table but not the settings model.
void main() {
  test('no saved layout reads as null, not an error', () async {
    final db = LocalStore.memory();
    addTearDown(db.close);

    expect(await UiStateRepository(db).paneLayout('paneLayout.shell'), isNull);
    expect(await UiStateRepository(db).collapsedSections(), isEmpty);
  });

  test('a pane layout round-trips', () async {
    final db = LocalStore.memory();
    addTearDown(db.close);
    final ui = UiStateRepository(db);

    // The shape `PaneController.save()` produces.
    await ui.savePaneLayout('paneLayout.shell', {
      'pixelSizes': {'sidebar': 312.0},
      'fractionalSizes': <String, double>{},
      'overrides': {'sidebar': false},
    });

    final read = await ui.paneLayout('paneLayout.shell');
    expect(read!['pixelSizes'], {'sidebar': 312.0});
    expect(read['overrides'], {'sidebar': false});
  });

  test('collapsed sections round-trip', () async {
    final db = LocalStore.memory();
    addTearDown(db.close);
    final ui = UiStateRepository(db);

    await ui.saveCollapsedSections({'history', 'connections'});

    expect(await ui.collapsedSections(), {'history', 'connections'});
  });

  test('an unreadable layout blob reads as no saved layout', () async {
    final db = LocalStore.memory();
    addTearDown(db.close);
    // A blob from a version whose format we can't parse must not stop the
    // window opening — the layout just falls back to defaults.
    await db.into(db.settingsRows).insert(
          SettingsRowsCompanion.insert(
              key: 'ui.paneLayout.shell', value: 'not json'),
          mode: InsertMode.insertOrReplace,
        );

    expect(await UiStateRepository(db).paneLayout('paneLayout.shell'), isNull);
  });

  test('layout keys stay out of AppSettings', () async {
    final db = LocalStore.memory();
    addTearDown(db.close);
    await UiStateRepository(db).saveCollapsedSections({'schema'});

    // Decoding settings must ignore the ui.* rows entirely rather than choke
    // on keys it doesn't know.
    final settings = await SettingsRepository(db).read();
    expect(settings.toJson(), const AppSettings().toJson());
  });

  test('"Reset to defaults" clears the layout as well as the settings',
      () async {
    // They used to share a table, so one delete did both. They no longer do —
    // UI state is per-machine ephemera and writing it must not notify the
    // settings watchers that now drive the theme — so the reset says so.
    final db = LocalStore.memory();
    addTearDown(db.close);
    final ui = UiStateRepository(db);
    await ui.saveCollapsedSections({'schema'});

    await SettingsRepository(db).reset();
    await ui.reset();

    expect(await ui.collapsedSections(), isEmpty);
  });
}
