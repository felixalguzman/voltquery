import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltquery/domain/drivers/result.dart';
import 'package:voltquery/ui/features/query_workspace/worksheet_providers.dart';

/// Validates ADR-0002/0004: each Worksheet owns its **own** Session (distinct
/// connection), while sharing the same backing store (shared-cache demo).
void main() {
  test('per-worksheet sessions are distinct but share the store', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Introspection session seeds + keeps the shared in-memory demo alive.
    await container.read(introspectionSessionProvider.future);

    final sessionA =
        await container.read(worksheetSessionProvider('ws-a').future);
    final sessionB =
        await container.read(worksheetSessionProvider('ws-b').future);

    // Own Session each (tx-isolated) — not the same instance.
    expect(identical(sessionA, sessionB), isFalse);

    // Both see the shared seeded data.
    for (final session in [sessionA, sessionB]) {
      final result =
          await session.execute('SELECT count(*) FROM customers') as RowsResult;
      final rows = await result.cursor.fetch(1);
      expect(rows.first.values.first, 4);
    }
  });
}
