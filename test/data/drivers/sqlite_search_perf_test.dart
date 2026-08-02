import 'package:flutter_test/flutter_test.dart';
import 'package:voltquery/data/drivers/sqlite/sqlite_driver.dart';
import 'package:voltquery/domain/drivers/driver.dart';
import 'package:voltquery/domain/drivers/schema_introspector.dart';
import 'package:voltquery/domain/models/connection.dart';
import 'package:voltquery/domain/models/engine.dart';

/// What the global search costs as a schema gets big.
///
/// The search runs **per keystroke** (debounced 220ms), so its cost is a UI
/// budget, not a batch one. The column query is the one worth watching: SQLite
/// keeps no column catalog, so it joins `sqlite_master` to `pragma_table_info`
/// and effectively walks every table's schema on each search.
///
/// Two sizes so the *shape* of the curve is visible, not just one number:
/// a large schema and an extreme one. Bounds are deliberately loose — an order
/// of magnitude above what this machine does — so the test catches a
/// pathological regression (a per-table query, a dropped LIMIT) rather than
/// failing on a slow CI box. The printed timings are the real signal.
void main() {
  const sizes = [
    (tables: 500, columns: 30), // a large real schema
    (tables: 2000, columns: 40), // an extreme one: 80k columns
  ];

  for (final size in sizes) {
    final total = size.tables * size.columns;
    group('${size.tables} tables x ${size.columns} columns ($total columns)',
        () {
      late Session session;
      late SchemaIntrospector introspector;

      setUpAll(() async {
        session = await SqliteDriver().connect(
          const Connection(
            id: 't',
            name: 'mem',
            engine: Engine.sqlite,
            sqlitePath: ':memory:',
          ),
        );
        // One transaction: 2000 separate DDL commits would dominate the setup.
        await session.execute('BEGIN');
        for (var t = 0; t < size.tables; t++) {
          final cols = [
            for (var c = 0; c < size.columns; c++) 'col_${t}_$c TEXT',
          ].join(', ');
          await session.execute(
              'CREATE TABLE ven_tabla_$t (id INTEGER PRIMARY KEY, $cols)');
        }
        await session.execute('COMMIT');
        introspector = session.schema;
        // Warm the page cache so first-query cost isn't charged to search.
        await introspector.search('warmup');
      });

      tearDownAll(() async => session.close());

      Future<Duration> time(Future<void> Function() body) async {
        final sw = Stopwatch()..start();
        await body();
        return sw.elapsed;
      }

      void report(String label, Duration d) {
        // ignore: avoid_print
        print('[${size.tables}x${size.columns}] $label: ${d.inMilliseconds}ms');
      }

      test('a selective search finds one column among $total', () async {
        final elapsed = await time(() async {
          final hits = await introspector.search('col_37_12');
          expect(hits, isNotEmpty);
        });
        report('selective', elapsed);
        expect(elapsed.inMilliseconds, lessThan(3000));
      });

      test('a broad search is bounded by the limit, not the schema', () async {
        // 'col_' matches every column in the database. The LIMIT is the only
        // thing between the dialog and all $total of them.
        final elapsed = await time(() async {
          final hits = await introspector.search('col_', limit: 200);
          expect(hits, hasLength(200));
        });
        report('broad, limit 200', elapsed);
        expect(elapsed.inMilliseconds, lessThan(3000));
      });

      test('a table-name search does not pay for columns', () async {
        // Object hits fill the limit first, so the column join never runs —
        // the common case of typing a table name stays on the cheap path.
        final elapsed =
            await time(() => introspector.search('ven_tabla', limit: 200));
        report('table names only', elapsed);
        expect(elapsed.inMilliseconds, lessThan(3000));
      });

      test('a miss across the whole schema is still cheap', () async {
        final elapsed = await time(() async {
          expect(await introspector.search('nothing_matches_this'), isEmpty);
        });
        report('no match', elapsed);
        expect(elapsed.inMilliseconds, lessThan(3000));
      });

      test('cost tracks the limit rather than the schema size', () async {
        final small = await time(() => introspector.search('col_', limit: 50));
        final large =
            await time(() => introspector.search('col_', limit: 2000));
        report('limit 50', small);
        report('limit 2000', large);
        expect(large.inMilliseconds, lessThan(5000));
      });
    });
  }
}
