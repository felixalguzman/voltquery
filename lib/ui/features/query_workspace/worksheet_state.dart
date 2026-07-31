import '../../../domain/drivers/driver_error.dart';
import '../../../domain/drivers/result.dart';

/// The outcome of running SQL in a Worksheet — grid-ready.
///
/// One state per row-returning Statement is the full model (ADR-0007); this
/// first slice materializes a single result. Plain sealed classes for now;
/// promote to `freezed` when the query-workspace grows.
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
  });

  final List<ResultField> fields;
  final List<ResultRow> rows;
  final int durationMs;

  /// True when the render cap was hit (more rows exist than were fetched).
  final bool capped;
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
