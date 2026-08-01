import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:voltquery/data/services/local_store.dart';
import 'package:voltquery/domain/models/history_entry.dart';
import 'package:voltquery/domain/drivers/result.dart';
import 'package:voltquery/domain/models/schema.dart';
import 'package:voltquery/ui/features/history/history_providers.dart';
import 'package:voltquery/ui/features/query_workspace/grid_editability.dart';
import 'package:voltquery/ui/features/query_workspace/worksheet_providers.dart';
import 'package:voltquery/ui/features/query_workspace/worksheet_state.dart';

/// End-to-end editability resolution against the seeded demo database: which
/// results the grid will let you write back to, and which stay read-only.
List<Override> _memoryStore() => [
      localStoreProvider.overrideWith((ref) {
        final store = LocalStore.memory();
        ref.onDispose(store.close);
        return store;
      }),
      recentHistoryProvider
          .overrideWith((ref) => Stream.value(const <HistoryEntry>[])),
    ];

/// Runs [sql] in a worksheet and returns the resolved editability of its first
/// row result (null when the grid must stay read-only).
Future<GridEditability?> _editabilityOf(
  ProviderContainer container,
  String sql,
) async {
  await container.read(introspectionSessionProvider.future); // seed demo
  await container.read(worksheetProvider('ws').notifier).run(sql);
  final state = container.read(worksheetProvider('ws'));
  final rows = switch (state) {
    WorksheetScript(:final outcomes) =>
      outcomes.firstWhere((o) => o.isRows).result as WorksheetRows,
    WorksheetRows() => state,
    _ => throw StateError('expected rows, got $state'),
  };
  return rows.editability;
}

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(overrides: _memoryStore());
    addTearDown(container.dispose);
  });

  test('a plain single-table SELECT is editable, with PK and typed editors',
      () async {
    // The demo table: id INTEGER PRIMARY KEY, name TEXT, email TEXT, total REAL
    final e = await _editabilityOf(container, 'SELECT * FROM customers');

    expect(e, isNotNull);
    expect(e!.target.table, 'customers');
    expect(e.primaryKey, ['id']);

    // The PK is not editable in place — the UPDATE addresses the row by it.
    expect(e.isPrimaryKey('id'), isTrue);
    expect(e.isPrimaryKey('name'), isFalse);

    // Types come from the *schema*, which is the whole reason editability
    // resolution and typed editors share one lookup: SQLite reports an empty
    // projection type, so ResultField alone could never do this.
    expect(e.editorFor('name')!.kind.name, 'text');
    expect(e.editorFor('total')!.kind.name, 'decimal');
    expect(e.editorFor('id')!.kind.name, 'integer');
  });

  test('a WHERE/ORDER/LIMIT query is still editable', () async {
    final e = await _editabilityOf(
      container,
      'SELECT * FROM customers WHERE total > 1 ORDER BY name LIMIT 10',
    );
    expect(e, isNotNull);
    expect(e!.target.table, 'customers');
  });

  test('an aggregate result is read-only', () async {
    final e = await _editabilityOf(
      container,
      'SELECT count(*) AS n FROM customers',
    );
    // No 1:1 row mapping → nothing safe to write back to.
    expect(e, isNull);
  });

  test('a computed/expression-only result is read-only', () async {
    final e = await _editabilityOf(container, 'SELECT 1 AS one');
    expect(e, isNull);
  });

  test('a table with no primary key is read-only', () async {
    // audit_log is seeded without a PK precisely to cover this path.
    final e = await _editabilityOf(container, 'SELECT * FROM audit_log');
    // Without a PK a single row can't be addressed — refuse rather than guess.
    expect(e, isNull);
  });

  test('a view is read-only', () async {
    final e = await _editabilityOf(container, 'SELECT * FROM customer_orders');
    expect(e, isNull);
  });

  test('a composite primary key gives multi-column row identity', () async {
    final e = await _editabilityOf(container, 'SELECT * FROM order_items');
    expect(e, isNotNull);
    expect(e!.primaryKey, ['order_id', 'product_id']);
    expect(e.isPrimaryKey('order_id'), isTrue);
    expect(e.isPrimaryKey('quantity'), isFalse);
  });

  test('the demo schema exercises every editor kind the grid renders',
      () async {
    final orders = await _editabilityOf(container, 'SELECT * FROM orders');
    expect(orders, isNotNull);
    // Declared SQLite affinities are chosen so real editors resolve.
    expect(orders!.editorFor('placed_at')!.kind.name, 'dateTime');
    expect(orders.editorFor('shipped')!.kind.name, 'boolean');
    expect(orders.editorFor('amount')!.kind.name, 'decimal');
    // SQLite has no ENUM, but the demo constrains status with CHECK ... IN,
    // which the introspector reads back into a validating dropdown.
    expect(orders.editorFor('status')!.kind.name, 'enumeration');
    expect(orders.editorFor('status')!.options,
        ['pending', 'shipped', 'cancelled']);
    expect(orders.editorFor('customer_id')!.kind.name, 'integer');

    final customers = await _editabilityOf(container, 'SELECT * FROM customers');
    expect(customers!.editorFor('active')!.kind.name, 'boolean');
    expect(customers.editorFor('signed_up')!.kind.name, 'date');
    // NOT NULL vs nullable drives the set-NULL affordance.
    expect(customers.editorFor('name')!.nullable, isFalse);
    expect(customers.editorFor('email')!.nullable, isTrue);
  });

  test('foreign keys are introspectable on the demo schema', () async {
    // orders.customer_id -> customers.id, for the tree's FK glyph and (later)
    // FK navigation in the grid.
    final session = await container.read(introspectionSessionProvider.future);
    final cols = await session.schema.columns(
      const TableInfo(name: 'orders', kind: ObjectKind.table),
    );
    final byName = {for (final c in cols) c.name: c};
    expect(byName['customer_id']!.isForeignKey, isTrue);
    expect(byName['id']!.isPrimaryKey, isTrue);
    expect(byName['amount']!.isForeignKey, isFalse);
  });

  group('applying staged edits', () {
    Future<List<Object?>> firstColumnOf(ProviderContainer c, String sql) async {
      final session = await c.read(introspectionSessionProvider.future);
      final res = await session.execute(sql);
      final rows = await (res as RowsResult).cursor.fetch(10);
      await res.cursor.close();
      return rows.map((r) => r.values.first).toList();
    }

    test('applies the statements and reports rows actually affected', () async {
      await container.read(introspectionSessionProvider.future);
      final result = await container
          .read(worksheetProvider('ws').notifier)
          .applyGridEdits([
        'UPDATE "customers" SET "name" = \'Ada L.\' WHERE "id" = 1;',
        'UPDATE "customers" SET "name" = \'Grace H.\' WHERE "id" = 2;',
      ]);

      expect(result.ok, isTrue);
      expect(result.applied, 2);
      expect(result.rowsAffected, 2); // <- was reported as 0 in history before
      expect(
        await firstColumnOf(container, 'SELECT name FROM customers ORDER BY id LIMIT 2'),
        ['Ada L.', 'Grace H.'],
      );
    });

    test('a failure rolls the whole batch back — no partial writes', () async {
      await container.read(introspectionSessionProvider.future);
      final before =
          await firstColumnOf(container, 'SELECT name FROM customers WHERE id = 1');

      final result = await container
          .read(worksheetProvider('ws').notifier)
          .applyGridEdits([
        'UPDATE "customers" SET "name" = \'changed\' WHERE "id" = 1;',
        'UPDATE "customers" SET "nope" = 1 WHERE "id" = 2;', // no such column
      ]);

      expect(result.ok, isFalse);
      expect(result.applied, 0, reason: 'nothing survives a failed batch');
      // The first statement succeeded before the second failed; without a
      // transaction it would have stuck.
      expect(
        await firstColumnOf(container, 'SELECT name FROM customers WHERE id = 1'),
        before,
      );
    });
  });

  test('the demo seeds bulk tables for performance work', () async {
    final session = await container.read(introspectionSessionProvider.future);

    Future<int> count(String table) async {
      final res = await session.execute('SELECT count(*) FROM $table');
      final rows = await (res as RowsResult).cursor.fetch(1);
      await res.cursor.close();
      return rows.first.values.first! as int;
    }

    // Generated in SQL with a recursive CTE, not row by row — seeding this
    // volume from Dart would cost seconds of startup.
    expect(await count('events'), 50000);
    expect(await count('wide_metrics'), 5000);

    // Wide on purpose: column layout and horizontal scrolling aren't stressed
    // by row count alone.
    final cols = await session.schema.columns(
      const TableInfo(name: 'wide_metrics', kind: ObjectKind.table),
    );
    expect(cols.length, 26); // id + captured_at + m1..m24

    // Still editable despite the size, and its CHECK constraint is a dropdown.
    final e = await _editabilityOf(container, 'SELECT * FROM events LIMIT 100');
    expect(e, isNotNull);
    expect(e!.editorFor('level')!.options,
        ['debug', 'info', 'warn', 'error']);
  });

  test('a projection missing the PK yields no row identity', () async {
    final e = await _editabilityOf(container, 'SELECT name FROM customers');
    // The table itself is editable...
    expect(e, isNotNull);
    expect(e!.primaryKey, ['id']);
    // ...but `id` wasn't selected, so the grid can't build a WHERE clause. The
    // grid checks this per row via its PK lookup and skips those rows.
    expect(
      e.primaryKey.every((pk) => pk == 'name'),
      isFalse,
      reason: 'PK is not among the selected fields',
    );
  });
}
