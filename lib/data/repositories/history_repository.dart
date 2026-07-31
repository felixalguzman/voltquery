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
          rowCount: Value(e.rowCount),
          errorKind: Value(e.errorKind),
          errorMessage: Value(e.errorMessage),
        ));
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
        rowCount: r.rowCount,
        errorKind: r.errorKind,
        errorMessage: r.errorMessage,
      );
}
