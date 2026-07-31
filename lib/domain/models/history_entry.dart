/// Outcome kind of a recorded execution.
enum HistoryStatus { ok, error, canceled }

/// A **durable record** of a past Execution (CONTEXT.md / ADR-0005). Does not
/// store the ResultSet — re-running re-executes. Persisted in `voltquery.db`.
class HistoryEntry {
  const HistoryEntry({
    this.id,
    required this.connectionName,
    required this.engine,
    this.databaseName,
    required this.sql,
    required this.startedAt,
    required this.durationMs,
    required this.status,
    this.rowCount,
    this.errorKind,
    this.errorMessage,
  });

  final int? id;
  final String connectionName;
  final String engine;
  final String? databaseName;
  final String sql;
  final DateTime startedAt;
  final int durationMs;
  final HistoryStatus status;
  final int? rowCount;
  final String? errorKind;
  final String? errorMessage;
}
