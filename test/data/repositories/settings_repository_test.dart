import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltquery/data/repositories/settings_repository.dart';
import 'package:voltquery/data/services/local_store.dart';
import 'package:voltquery/domain/models/app_settings.dart';
import 'package:voltquery/domain/models/ssl_mode.dart';

/// Seam: SettingsRepository over an in-memory drift LocalStore.
void main() {
  test('an empty store reads as the defaults', () async {
    final db = LocalStore.memory();
    addTearDown(db.close);

    final settings = await SettingsRepository(db).read();

    expect(settings.resultRowCap, const AppSettings().resultRowCap);
    expect(settings.titleBarVisible, isTrue);
    expect(settings.defaultSslMode, SslMode.require);
  });

  test('save round-trips every field', () async {
    final db = LocalStore.memory();
    addTearDown(db.close);
    final repo = SettingsRepository(db);

    const written = AppSettings(
      historyRetentionEnabled: false,
      historyRetentionDays: 7,
      historyRetentionRows: 50,
      editorFontFamily: 'JetBrains Mono',
      editorFontSize: 16,
      resultRowCap: 2000,
      resultFetchBatch: 250,
      tablePreviewLimit: 25,
      nullDisplay: '∅',
      titleBarVisible: false,
      defaultSslMode: SslMode.verifyFull,
      defaultConnectTimeoutSeconds: 45,
      vaultAutoLockMinutes: 15,
    );
    await repo.save(written);

    final read = await repo.read();
    expect(read.toJson(), written.toJson());
  });

  test('put writes one key without disturbing the others', () async {
    final db = LocalStore.memory();
    addTearDown(db.close);
    final repo = SettingsRepository(db);

    await repo.save(const AppSettings(resultRowCap: 750));
    await repo.put('titleBarVisible', false);

    final read = await repo.read();
    expect(read.titleBarVisible, isFalse);
    expect(read.resultRowCap, 750);
  });

  test('save leaves rows this build does not know about alone', () async {
    final db = LocalStore.memory();
    addTearDown(db.close);
    final repo = SettingsRepository(db);

    // Something a *newer* version wrote. Saving from this build must not
    // delete it, or downgrading once would silently drop the setting.
    await repo.put('settingFromTheFuture', 42);
    await repo.save(const AppSettings(resultRowCap: 900));

    final rows = await db.select(db.settingsRows).get();
    expect(rows.map((r) => r.key), contains('settingFromTheFuture'));
  });

  test('a corrupt row falls back to the default instead of throwing', () async {
    final db = LocalStore.memory();
    addTearDown(db.close);
    final repo = SettingsRepository(db);
    await repo.save(const AppSettings(resultRowCap: 900));

    // Not valid JSON — e.g. a half-written row after a crash.
    await db.into(db.settingsRows).insert(
          SettingsRowsCompanion.insert(key: 'nullDisplay', value: '{oops'),
          mode: InsertMode.insertOrReplace,
        );

    final read = await repo.read();
    expect(read.nullDisplay, const AppSettings().nullDisplay);
    expect(read.resultRowCap, 900, reason: 'other settings still readable');
  });

  test('watch emits on write', () async {
    final db = LocalStore.memory();
    addTearDown(db.close);
    final repo = SettingsRepository(db);

    final emissions = <AppSettings>[];
    final sub = repo.watch().listen(emissions.add);
    addTearDown(sub.cancel);
    await pumpEventQueue();

    await repo.put('resultRowCap', 1234);
    await pumpEventQueue();

    expect(emissions.last.resultRowCap, 1234);
  });

  test('reset clears everything back to defaults', () async {
    final db = LocalStore.memory();
    addTearDown(db.close);
    final repo = SettingsRepository(db);

    await repo.save(const AppSettings(resultRowCap: 5, titleBarVisible: false));
    await repo.reset();

    final read = await repo.read();
    expect(read.toJson(), const AppSettings().toJson());
  });
}
