import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:voltquery/data/drivers/sqlite/sqlite_driver.dart';
import 'package:voltquery/domain/drivers/driver.dart';
import 'package:voltquery/domain/export/result_export.dart';
import 'package:voltquery/domain/export/result_export_service.dart';
import 'package:voltquery/domain/models/connection.dart';
import 'package:voltquery/domain/models/engine.dart';

/// Exporting against a real engine.
///
/// The claim under test is the one that would otherwise be found in a
/// spreadsheet a week later: an export contains **every** row the query
/// returns, not the render-capped slice the grid is holding.
void main() {
  late Session session;
  const service = ResultExportService();

  setUp(() async {
    session = await SqliteDriver().connect(
      const Connection(
        id: 't',
        name: 'mem',
        engine: Engine.sqlite,
        sqlitePath: ':memory:',
      ),
    );
    await session.execute('CREATE TABLE big (id INTEGER PRIMARY KEY, name TEXT)');
    // Comfortably past the 500-row default cap and past the 2000-row fetch
    // batch, so both the truncation bug and an off-by-one at a batch boundary
    // would show up.
    await session.execute('''
      WITH RECURSIVE seq(n) AS (
        SELECT 1 UNION ALL SELECT n + 1 FROM seq WHERE n < 5000
      )
      INSERT INTO big (id, name) SELECT n, 'row ' || n FROM seq
    ''');
  });

  tearDown(() async => session.close());

  Future<(String, int)> export(
    ExportFormat format, {
    String sql = 'SELECT * FROM big ORDER BY id',
    ExportOptions options = const ExportOptions(),
    int batchSize = kExportBatchSize,
  }) async {
    final buffer = StringBuffer();
    final count = await service.export(
      session: session,
      sql: sql,
      format: format,
      options: options,
      sink: buffer,
      batchSize: batchSize,
    );
    return (buffer.toString(), count);
  }

  test('every row is exported, not the capped slice the grid holds', () async {
    final (text, count) = await export(ExportFormat.csv);

    expect(count, 5000);
    // Header plus 5000 rows, and the last row is really there.
    expect(text.trimRight().split('\n'), hasLength(5001));
    expect(text, contains('5000,row 5000'));
  });

  test('a batch boundary is not an off-by-one', () async {
    // 5000 rows in batches of 700 lands mid-batch at the end — the shape that
    // drops or duplicates a row if the loop is wrong.
    final (text, count) = await export(ExportFormat.csv, batchSize: 700);
    expect(count, 5000);
    expect(text.trimRight().split('\n'), hasLength(5001));

    final ids = text
        .trimRight()
        .split('\n')
        .skip(1)
        .map((l) => int.parse(l.split(',').first))
        .toList();
    expect(ids.first, 1);
    expect(ids.last, 5000);
    expect(ids.toSet(), hasLength(5000), reason: 'no row exported twice');
  });

  test('streamed JSON parses as one array', () async {
    // Written batch by batch, so the brackets and commas are placed by hand —
    // exactly the code that produces almost-valid JSON when it is wrong.
    final (text, count) = await export(ExportFormat.json);
    final parsed = jsonDecode(text) as List;

    expect(count, 5000);
    expect(parsed, hasLength(5000));
    expect(parsed.first, {'id': 1, 'name': 'row 1'});
    expect(parsed.last, {'id': 5000, 'name': 'row 5000'});
  });

  test('Markdown buffers and still gets every row', () async {
    // The one format that cannot stream, because it aligns columns.
    final (text, count) = await export(
      ExportFormat.markdown,
      sql: 'SELECT * FROM big ORDER BY id LIMIT 10',
    );
    expect(count, 10);
    expect(text.trimRight().split('\n'), hasLength(12)); // header + rule + 10
  });

  test('an empty result still writes a well-formed file', () async {
    final (csv, csvCount) =
        await export(ExportFormat.csv, sql: 'SELECT * FROM big WHERE 0');
    expect(csvCount, 0);
    expect(csv.trim(), 'id,name'); // header only

    final (json, jsonCount) =
        await export(ExportFormat.json, sql: 'SELECT * FROM big WHERE 0');
    expect(jsonCount, 0);
    expect(jsonDecode(json), isEmpty);
  });

  test('a non-row statement is refused rather than writing nothing', () async {
    // Silently producing an empty file for `UPDATE …` would look like a table
    // with no rows.
    await expectLater(
      () => export(ExportFormat.csv, sql: 'UPDATE big SET name = name'),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('the cursor is closed even when the export fails', () async {
    // The cursor pins the statement; leaking it on failure would hold a
    // server-side resource until the whole Session went away.
    await expectLater(
      () => export(ExportFormat.csv, sql: 'SELECT * FROM no_such_table'),
      throwsA(anything),
    );
    // The session is still usable, which is the observable consequence.
    final (_, count) =
        await export(ExportFormat.csv, sql: 'SELECT * FROM big LIMIT 1');
    expect(count, 1);
  });
}
