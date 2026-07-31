import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltquery/data/drivers/sqlite/sqlite_driver.dart';
import 'package:voltquery/domain/drivers/result.dart';
import 'package:voltquery/domain/models/connection.dart';
import 'package:voltquery/domain/models/engine.dart';
import 'package:voltquery/ui/features/query_workspace/worksheet_providers.dart';

/// Seam: pointing [currentConnectionProvider] at a file rebuilds
/// [sessionProvider] onto that database — the logic behind "Open .sqlite".
void main() {
  test('opening a SQLite file makes it the active queryable session', () async {
    // Seed a real file-backed database.
    final dir = Directory.systemTemp.createTempSync('vq_fileopen');
    final path = '${dir.path}/data.db';
    final seed = await SqliteDriver().connect(
      Connection(id: 'seed', name: 'seed', engine: Engine.sqlite, sqlitePath: path),
    );
    await seed.execute('CREATE TABLE t (v TEXT)');
    await seed.execute("INSERT INTO t VALUES ('from-file')");
    await seed.close();

    final container = ProviderContainer();
    addTearDown(() {
      container.dispose();
      dir.deleteSync(recursive: true);
    });

    // Default connection is the in-memory demo.
    expect(container.read(currentConnectionProvider).sqlitePath, ':memory:');

    // Point the workspace at the file (what the Open button does).
    container.read(currentConnectionProvider.notifier).state = Connection(
      id: path,
      name: 'data.db',
      engine: Engine.sqlite,
      sqlitePath: path,
    );

    final session = await container.read(sessionProvider.future);
    final result = await session.execute('SELECT v FROM t') as RowsResult;
    final rows = await result.cursor.fetch(10);

    expect(rows.single.values, ['from-file']);
  });
}
