/// Outcome kind of a recorded execution.
enum HistoryStatus { ok, error, canceled }

/// Who wrote the SQL.
///
/// The line is **what the user asked for**, not who typed it: a statement the
/// app composed because you clicked something belongs in history, because it
/// ran against your database and you may need to see it, re-run it, or explain
/// it to a DBA. What does *not* belong is the chatter the app needs to draw
/// itself — expanding a tree node, reading a column list — which would bury
/// everything else within a minute of browsing.
enum HistorySource {
  /// Typed or opened in a worksheet and run deliberately.
  editor,

  /// DML the result grid generated from staged cell edits.
  gridEdit,

  /// The app ran it on your behalf from a UI action — Table Info's exact
  /// `count(*)`, for instance, which is a full scan worth having a record of.
  tool;

  String get label => switch (this) {
        HistorySource.editor => 'editor',
        HistorySource.gridEdit => 'grid edit',
        HistorySource.tool => 'tool',
      };

  /// True for everything the user did not write themselves — what the panel's
  /// "hide generated" filter hides.
  bool get isGenerated => this != HistorySource.editor;

  static HistorySource byName(String? name) => HistorySource.values.firstWhere(
        (s) => s.name == name,
        // Rows written before this column existed were all worksheet runs.
        orElse: () => HistorySource.editor,
      );
}

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
    this.source = HistorySource.editor,
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
  final HistorySource source;
  final int? rowCount;
  final String? errorKind;
  final String? errorMessage;
}
