import '../../../domain/drivers/driver.dart';
import '../../../domain/drivers/driver_error.dart';
import '../../../domain/drivers/result.dart';
import 'worksheet_state.dart';

/// Runs one SQL statement against a [Session] and materializes a grid-ready
/// [WorksheetResult].
///
/// This first slice drains up to [rowCap] rows into memory (the render cap from
/// ADR-0008); true lazy pagination via `ResultCursor.fetch` on scroll is a later
/// slice. Multi-statement scripts (ADR-0007) are also a later slice.
class WorksheetRunner {
  const WorksheetRunner({this.rowCap = 500, this.batchSize = 100});

  final int rowCap;
  final int batchSize;

  Future<WorksheetResult> run(Session session, String sql) async {
    final sw = Stopwatch()..start();
    try {
      final result = await session.execute(sql);
      switch (result) {
        case RowsResult(:final cursor):
          final rows = <ResultRow>[];
          var capped = false;
          while (true) {
            final batch = await cursor.fetch(batchSize);
            rows.addAll(batch);
            if (rows.length >= rowCap) {
              capped = cursor.hasMore || rows.length > rowCap;
              break;
            }
            if (!cursor.hasMore || batch.isEmpty) break;
          }
          final fields = cursor.fields;
          await cursor.close();
          return WorksheetRows(
            fields: fields,
            rows: rows.length > rowCap ? rows.sublist(0, rowCap) : rows,
            durationMs: (sw..stop()).elapsedMilliseconds,
            capped: capped,
          );
        case CommandResult(:final affectedRows):
          return WorksheetMessage('$affectedRows row(s) affected');
      }
    } on DriverError catch (e) {
      return WorksheetFailure(e);
    }
  }
}
