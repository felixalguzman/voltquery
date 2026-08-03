import 'dart:convert';

import 'package:drift/drift.dart';

import '../services/local_store.dart';

/// Per-machine window ephemera — pane sizes, what's collapsed — kept apart from
/// [AppSettings].
///
/// Same `settings_rows` table (one store, one migration lineage per ADR-0005),
/// but under a `ui.` key prefix and out of the settings model: these are not
/// preferences anyone sets deliberately, they're where you happened to leave
/// the splitters. Mixing them into `AppSettings` would put splitter pixel
/// counts in the same object as "default TLS mode".
class UiStateRepository {
  UiStateRepository(this._db);

  static const _prefix = 'ui.';

  final LocalStore _db;

  /// Layout blob for one [PaneController], from its `save()`.
  ///
  /// Opaque on purpose: the shape belongs to the `panes` package, and a version
  /// of it we can't decode should be dropped, not migrated.
  Future<Map<String, dynamic>?> paneLayout(String key) async =>
      await _readJson('$_prefix$key') as Map<String, dynamic>?;

  Future<void> savePaneLayout(String key, Map<String, dynamic> layout) =>
      _write('$_prefix$key', layout);

  Future<Set<String>> collapsedSections() async {
    final raw = await _readJson('${_prefix}collapsedSections');
    return switch (raw) {
      final List<Object?> l => {for (final e in l) '$e'},
      _ => <String>{},
    };
  }

  Future<void> saveCollapsedSections(Set<String> ids) =>
      _write('${_prefix}collapsedSections', ids.toList());

  /// A blob written by another version must never stop the window opening, so
  /// anything unreadable reads as "no saved layout".
  Future<Object?> _readJson(String key) async {
    final row = await (_db.select(
      _db.settingsRows,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    if (row == null) return null;
    try {
      return jsonDecode(row.value);
    } catch (_) {
      return null;
    }
  }

  Future<void> _write(String key, Object? value) {
    return _db
        .into(_db.settingsRows)
        .insert(
          SettingsRowsCompanion.insert(key: key, value: jsonEncode(value)),
          mode: InsertMode.insertOrReplace,
        );
  }
}
