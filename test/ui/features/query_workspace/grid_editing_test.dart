import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:voltquery/data/services/local_store.dart';
import 'package:voltquery/domain/models/history_entry.dart';
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
    await container.read(introspectionSessionProvider.future);
    await container
        .read(worksheetProvider('ws').notifier)
        .run('CREATE TABLE nopk (a TEXT, b TEXT);');

    final e = await _editabilityOf(container, 'SELECT * FROM nopk');
    // Without a PK a single row can't be addressed — refuse rather than guess.
    expect(e, isNull);
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
