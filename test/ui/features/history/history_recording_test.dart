import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltquery/data/services/local_store.dart';
import 'package:voltquery/domain/models/history_entry.dart';
import 'package:voltquery/ui/features/history/history_providers.dart';
import 'package:voltquery/ui/features/query_workspace/worksheet_providers.dart';

/// Integration: running a query in a Worksheet records a HistoryEntry that
/// surfaces in recentHistory. In-memory drift store.
void main() {
  test('running a query records it to history', () async {
    final container = ProviderContainer(overrides: [
      localStoreProvider.overrideWith((ref) {
        final store = LocalStore.memory();
        ref.onDispose(store.close);
        return store;
      }),
    ]);
    addTearDown(container.dispose);

    await container.read(introspectionSessionProvider.future); // seed demo
    await container
        .read(worksheetProvider('ws-x').notifier)
        .run('SELECT * FROM customers');

    final history = await container.read(recentHistoryProvider.future);
    expect(history, isNotEmpty);
    expect(history.first.sql, contains('customers'));
    expect(history.first.status, HistoryStatus.ok);
    expect(history.first.rowCount, 4);
  });
}
