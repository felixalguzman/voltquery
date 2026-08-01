import '../../../domain/drivers/driver_error.dart';
import '../../../domain/drivers/result.dart';
import '../../../domain/sql/sql_statement_splitter.dart';
import 'grid_editability.dart';

/// The outcome of running SQL in a Worksheet — grid-ready.
///
/// A script yields one [StatementOutcome] per Statement, gathered into a
/// [WorksheetScript] (ADR-0007). Plain sealed classes for now; promote to
/// `freezed` when the query-workspace grows.
sealed class WorksheetResult {
  const WorksheetResult();
}

class WorksheetIdle extends WorksheetResult {
  const WorksheetIdle();
}

class WorksheetRunning extends WorksheetResult {
  const WorksheetRunning();
}

/// A row-returning result, drained into memory (render-capped) for the grid.
class WorksheetRows extends WorksheetResult {
  const WorksheetRows({
    required this.fields,
    required this.rows,
    required this.durationMs,
    required this.capped,
    this.editability,
  });

  final List<ResultField> fields;
  final List<ResultRow> rows;
  final int durationMs;

  /// True when the render cap was hit (more rows exist than were fetched).
  final bool capped;

  /// Set when this result maps 1:1 onto one table's rows, so the grid can write
  /// back. Null → read-only (a join, an aggregate, a table with no PK…).
  final GridEditability? editability;

  WorksheetRows withEditability(GridEditability? value) => WorksheetRows(
        fields: fields,
        rows: rows,
        durationMs: durationMs,
        capped: capped,
        editability: value,
      );
}

/// A non-row statement (DML/DDL) — shown in the messages area.
class WorksheetMessage extends WorksheetResult {
  const WorksheetMessage(this.text);
  final String text;
}

/// A normalized failure — drives the error toast + Messages tab.
class WorksheetFailure extends WorksheetResult {
  const WorksheetFailure(this.error);
  final DriverError error;
}

/// One Statement's execution within a script run (ADR-0007). [result] is the
/// per-statement payload: [WorksheetRows] (→ a result sub-tab), [WorksheetMessage]
/// (DML/DDL affected-count → messages log) or [WorksheetFailure].
class StatementOutcome {
  const StatementOutcome({
    required this.index,
    required this.sql,
    required this.kind,
    required this.result,
  });

  /// 1-based position in the script.
  final int index;
  final String sql;
  final StatementKind kind;
  final WorksheetResult result;

  bool get isRows => result is WorksheetRows;
  bool get isFailure => result is WorksheetFailure;
}

/// The result of running a (possibly multi-statement) script: the ordered
/// outcomes. Row-returning statements become result sub-tabs; the rest post to
/// the messages log (ADR-0007 / #15).
class WorksheetScript extends WorksheetResult {
  const WorksheetScript(this.outcomes, {this.canceled = false});
  final List<StatementOutcome> outcomes;

  /// The run was stopped early by the user (Cancel) — remaining statements did
  /// not execute.
  final bool canceled;

  List<StatementOutcome> get rowResults => [
    for (final o in outcomes)
      if (o.isRows) o,
  ];
}
