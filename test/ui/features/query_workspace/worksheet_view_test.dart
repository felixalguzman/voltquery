import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltquery/data/services/local_store.dart';
import 'package:voltquery/ui/features/history/history_providers.dart';
import 'package:voltquery/ui/features/query_workspace/worksheet_view.dart';

/// History persists to a real file via path_provider — use an in-memory store.
final _memoryStore = <Override>[
  localStoreProvider.overrideWith((ref) {
    final store = LocalStore.memory();
    ref.onDispose(store.close);
    return store;
  }),
];

/// End-to-end: a Worksheet runs its editor SQL against its own Session and
/// renders rows. Uses the real (shared-cache in-memory) demo — 4 seeded rows.
void main() {
  testWidgets('running the default query renders the demo rows', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _memoryStore,
        child: const FluentApp(
          debugShowCheckedModeBanner: false,
          home: ScaffoldPage(
            padding: EdgeInsets.zero,
            content: WorksheetView(worksheetId: 'ws-0'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('▶ Run'));
    await tester.pumpAndSettle();

    // Editor default 'SELECT * FROM customers;' → 4 seeded rows.
    expect(find.textContaining('4 row(s)'), findsOneWidget);
  });

  testWidgets('Run at cursor runs the statement under the caret', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _memoryStore,
        child: const FluentApp(
          debugShowCheckedModeBanner: false,
          home: ScaffoldPage(
            padding: EdgeInsets.zero,
            content: WorksheetView(worksheetId: 'ws-0'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Open the Run-mode menu → "Run at cursor". Caret sits at offset 0, so the
    // statement under it is the default 'SELECT * FROM customers'.
    await tester.tap(find.byType(DropDownButton));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Run at cursor'));
    await tester.pumpAndSettle();

    expect(find.textContaining('4 row(s)'), findsOneWidget);
  });
}
