/// One column of a query **result** — a projection (name, inferred type,
/// ordinal). Carries no PK/FK/nullable metadata; it may be `count(*)`, an
/// expression, or a join. **Not** a schema `ColumnInfo`. See `CONTEXT.md`.
class ResultField {
  const ResultField({
    required this.name,
    required this.dataType,
    required this.ordinal,
  });

  final String name;
  final String dataType;
  final int ordinal;
}

/// One row of a result — an ordered tuple aligned to the [ResultField]s.
class ResultRow {
  const ResultRow(this.values);
  final List<Object?> values;
}

/// Pull-based reader over a row-returning result. Feeds pluto_grid's lazy
/// pagination; holds its [Session] open until [close]. ADR-0003.
abstract interface class ResultCursor {
  List<ResultField> get fields;
  bool get hasMore;

  /// Pull the next batch of up to [n] rows.
  Future<List<ResultRow>> fetch(int n);

  /// Frees the underlying cursor and releases the Session.
  Future<void> close();
}

/// The tagged outcome of one [Session.execute] — the app can't pre-classify
/// arbitrary user SQL, so it switches on the concrete type.
sealed class ExecutionResult {
  const ExecutionResult();
}

/// A row-returning statement (SELECT-like).
class RowsResult extends ExecutionResult {
  const RowsResult(this.cursor);
  final ResultCursor cursor;
}

/// A non-row statement (DML / DDL).
class CommandResult extends ExecutionResult {
  const CommandResult({required this.affectedRows, this.lastInsertId});
  final int affectedRows;
  final Object? lastInsertId;
}
