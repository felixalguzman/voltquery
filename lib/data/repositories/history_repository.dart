import 'package:drift/drift.dart';

import '../../domain/models/history_entry.dart';
import '../services/local_store.dart';

/// Single source of truth for query history (ADR-0004/0005). Persists a
/// [HistoryEntry] per Execution; exposes a reactive recent-history stream.
class HistoryRepository {
  HistoryRepository(this._db);

  final LocalStore _db;

  Future<void> record(HistoryEntry e) {
    return _db.into(_db.historyRows).insert(HistoryRowsCompanion.insert(
          connectionName: e.connectionName,
          engine: e.engine,
          databaseName: Value(e.databaseName),
          sql: e.sql,
          startedAt: e.startedAt,
          durationMs: e.durationMs,
          status: e.status.name,
          source: Value(e.source.name),
          rowCount: Value(e.rowCount),
          errorKind: Value(e.errorKind),
          errorMessage: Value(e.errorMessage),
        ));
  }

  /// Remove one entry (the history row menu's Delete).
  Future<void> delete(int id) =>
      (_db.delete(_db.historyRows)..where((t) => t.id.equals(id))).go();

  /// Remove every entry. Confirmed in the UI — there is no undo.
  Future<void> clear() => _db.delete(_db.historyRows).go();

  /// Drops entries that are both older than [keepDays] **and** outside the
  /// newest [keepRows] (`docs/design/persistence.md`).
  ///
  /// Both conditions, not either: a date rule alone erases the history of
  /// someone who took a month off, and a count rule alone erases a busy
  /// afternoon's. Returns how many rows went.
  Future<int> prune({required int keepDays, required int keepRows}) async {
    final cutoff = DateTime.now().subtract(Duration(days: keepDays));
    // The id of the newest row that survives on count alone; anything at or
    // above it is kept regardless of age.
    final newest = await (_db.select(_db.historyRows)
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
          ..limit(1, offset: keepRows - 1))
        .getSingleOrNull();
    if (newest == null) return 0; // fewer rows than the floor — nothing to do

    return (_db.delete(_db.historyRows)
          ..where((t) =>
              t.startedAt.isSmallerThanValue(cutoff) &
              t.startedAt.isSmallerThanValue(newest.startedAt)))
        .go();
  }

  Stream<List<HistoryEntry>> watchRecent(int limit) {
    final q = _db.select(_db.historyRows)
      ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
      ..limit(limit);
    return q.watch().map((rows) => rows.map(_toDomain).toList());
  }

  HistoryEntry _toDomain(HistoryRow r) => HistoryEntry(
        id: r.id,
        connectionName: r.connectionName,
        engine: r.engine,
        databaseName: r.databaseName,
        sql: r.sql,
        startedAt: r.startedAt,
        durationMs: r.durationMs,
        status: HistoryStatus.values.byName(r.status),
        source: HistorySource.byName(r.source),
        rowCount: r.rowCount,
        errorKind: r.errorKind,
        errorMessage: r.errorMessage,
      );
}
