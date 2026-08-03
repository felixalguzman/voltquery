import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/models/app_settings.dart';
import '../services/local_store.dart';

/// Reads and writes [AppSettings] against the `settings_rows` key-value table
/// (ADR-0005, `docs/design/persistence.md`).
///
/// Writes are per-key upserts rather than a whole-table rewrite, so a key this
/// build doesn't know about is left alone instead of being deleted by an older
/// version saving over it.
class SettingsRepository {
  SettingsRepository(this._db);

  final LocalStore _db;

  Future<AppSettings> read() async {
    final rows = await _db.select(_db.settingsRows).get();
    return AppSettings.fromJson(_decode(rows));
  }

  /// Live settings — the UI rebuilds as soon as a knob is written, including
  /// from another window.
  Stream<AppSettings> watch() => _db
      .select(_db.settingsRows)
      .watch()
      .map((rows) => AppSettings.fromJson(_decode(rows)));

  /// Persists every known key of [settings]. Unknown rows are untouched.
  Future<void> save(AppSettings settings) {
    return _db.batch((b) {
      for (final e in settings.toJson().entries) {
        b.insert(
          _db.settingsRows,
          SettingsRowsCompanion.insert(key: e.key, value: jsonEncode(e.value)),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  /// Writes one setting. [value] must be JSON-encodable.
  Future<void> put(String key, Object? value) {
    return _db
        .into(_db.settingsRows)
        .insert(
          SettingsRowsCompanion.insert(key: key, value: jsonEncode(value)),
          mode: InsertMode.insertOrReplace,
        );
  }

  /// Back to defaults — drops every row, including keys this build doesn't
  /// know, because "reset" that leaves something behind isn't a reset.
  Future<void> reset() => _db.delete(_db.settingsRows).go();

  /// A row whose value isn't valid JSON is skipped, not fatal: one corrupt
  /// setting must not take the other eleven (or the app) down with it.
  Map<String, Object?> _decode(List<SettingsRow> rows) {
    final out = <String, Object?>{};
    for (final r in rows) {
      try {
        out[r.key] = jsonDecode(r.value);
      } catch (_) {
        continue;
      }
    }
    return out;
  }
}
