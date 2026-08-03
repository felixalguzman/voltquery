import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/models/tree_expansion.dart';
import '../services/local_store.dart';

/// Per-machine UI ephemera — pane sizes, what's collapsed, which tree nodes
/// were open — kept apart from `AppSettings`.
///
/// Its own table, not the settings one. These are not preferences anyone sets
/// deliberately, they're where you happened to leave things, and they have no
/// business in an exported connection. More concretely:
/// `SettingsRepository.watch` now drives the app's theme, so a splitter drag
/// written into that table would rebuild the entire widget tree.
class UiStateRepository {
  UiStateRepository(this._db);

  final LocalStore _db;

  static String _treeKey(String connectionId) => 'tree.$connectionId';

  Future<TreeExpansion> readTreeExpansion(String connectionId) async =>
      TreeExpansion.decode(await _readRaw(_treeKey(connectionId)));

  /// Writes, or deletes the row when nothing is open — an empty list is the
  /// default, and keeping it would leave a row per connection ever touched.
  Future<void> writeTreeExpansion(
    String connectionId,
    TreeExpansion expansion,
  ) async {
    final key = _treeKey(connectionId);
    if (expansion.isEmpty) {
      await (_db.delete(_db.uiStateRows)..where((r) => r.key.equals(key))).go();
      return;
    }
    await _db.into(_db.uiStateRows).insert(
          UiStateRowsCompanion.insert(key: key, value: expansion.encode()),
          mode: InsertMode.insertOrReplace,
        );
  }

  /// Everything this machine remembered about the layout. Paired with
  /// `SettingsRepository.reset` behind "Reset to defaults": the two live in
  /// different tables now, so resetting has to say so explicitly rather than
  /// relying on them sharing one.
  Future<void> reset() => _db.delete(_db.uiStateRows).go();

  /// Called when a connection is deleted, so its UI state doesn't outlive it.
  Future<void> forget(String connectionId) =>
      (_db.delete(_db.uiStateRows)
            ..where((r) => r.key.equals(_treeKey(connectionId))))
          .go();

  /// Layout blob for one [PaneController], from its `save()`.
  ///
  /// Opaque on purpose: the shape belongs to the `panes` package, and a version
  /// of it we can't decode should be dropped, not migrated.
  Future<Map<String, dynamic>?> paneLayout(String key) async =>
      await _readJson(key) as Map<String, dynamic>?;

  Future<void> savePaneLayout(String key, Map<String, dynamic> layout) =>
      _write(key, layout);

  Future<Set<String>> collapsedSections() async {
    final raw = await _readJson('collapsedSections');
    return switch (raw) {
      final List<Object?> l => {for (final e in l) '$e'},
      _ => <String>{},
    };
  }

  Future<void> saveCollapsedSections(Set<String> ids) =>
      _write('collapsedSections', ids.toList());

  /// A blob written by another version must never stop the window opening, so
  /// anything unreadable reads as "no saved layout".
  Future<String?> _readRaw(String key) async {
    final row = await (_db.select(_db.uiStateRows)
          ..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<Object?> _readJson(String key) async {
    final raw = await _readRaw(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> _write(String key, Object? value) {
    return _db.into(_db.uiStateRows).insert(
          UiStateRowsCompanion.insert(key: key, value: jsonEncode(value)),
          mode: InsertMode.insertOrReplace,
        );
  }
}
