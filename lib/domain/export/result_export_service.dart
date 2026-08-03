import '../drivers/driver.dart';
import '../drivers/result.dart';
import 'result_export.dart';

/// How many rows are pulled from the cursor at a time when exporting.
///
/// Large enough that a million-row export isn't a million round trips, small
/// enough that one batch is never the thing that runs the app out of memory.
const kExportBatchSize = 2000;

/// Writes a query's **full** result, not the render-capped slice the grid holds.
///
/// The grid materializes at most `resultRowCap` rows, so exporting what is on
/// screen would hand someone 500 rows of a 50,000-row table and say nothing.
/// This re-runs the statement and streams the answer, so the file matches the
/// query rather than the viewport.
class ResultExportService {
  const ResultExportService();

  /// Runs [sql] on [session] and writes every row to [sink]. Returns the count.
  ///
  /// Streaming formats are written batch by batch and never hold the result in
  /// memory. Markdown can't be — it aligns columns, so it has to see every row
  /// first — and is buffered instead; that is the trade the format chooses, and
  /// it is the one format nobody points at a million rows.
  Future<int> export({
    required Session session,
    required String sql,
    required ExportFormat format,
    required ExportOptions options,
    required StringSink sink,
    int batchSize = kExportBatchSize,
  }) async {
    final result = await session.execute(sql);
    if (result is! RowsResult) {
      throw ArgumentError('Not a row-returning statement: $sql');
    }
    final cursor = result.cursor;
    final formatter = ResultFormatter.of(format, options);

    try {
      if (!format.streams) {
        final all = <ResultRow>[];
        while (cursor.hasMore) {
          all.addAll(await cursor.fetch(batchSize));
        }
        sink.write(formatter.formatAll(cursor.fields, all));
        return all.length;
      }

      final head = formatter.header(cursor.fields);
      if (head != null) sink.writeln(head);

      var count = 0;
      while (cursor.hasMore) {
        for (final row in await cursor.fetch(batchSize)) {
          sink.writeln(formatter.row(cursor.fields, row, count));
          count++;
        }
      }
      final foot = formatter.footer(count);
      if (foot != null) sink.writeln(foot);
      return count;
    } finally {
      // The cursor holds the statement open; leaking it on a failed export
      // would pin a server-side resource until the Session closed.
      await cursor.close();
    }
  }
}
