import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:voltquery/data/services/local_store.dart';
import 'package:voltquery/domain/models/history_entry.dart';
import 'package:voltquery/main.dart';
import 'package:voltquery/ui/features/history/history_providers.dart';

void main() {
  testWidgets('VoltQuery boots to the query workspace', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStoreProvider.overrideWith((ref) {
            final store = LocalStore.memory();
            ref.onDispose(store.close);
            return store;
          }),
          recentHistoryProvider
              .overrideWith((ref) => Stream.value(const <HistoryEntry>[])),
        ],
        child: const VoltQueryApp(),
      ),
    );
    await tester.pumpAndSettle();
    // Demo session seeds an in-memory DB, then the worksheet renders.
    expect(find.text('▶ Run'), findsOneWidget);
  });
}
