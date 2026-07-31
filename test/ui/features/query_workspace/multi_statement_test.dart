import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltquery/data/services/local_store.dart';
import 'package:voltquery/ui/features/history/history_providers.dart';
import 'package:voltquery/ui/features/query_workspace/worksheet_providers.dart';
import 'package:voltquery/ui/features/query_workspace/worksheet_state.dart';
import 'package:voltquery/ui/features/query_workspace/worksheet_view.dart';

List<Override> _memoryStore() => [
      localStoreProvider.overrideWith((ref) {
        final store = LocalStore.memory();
        ref.onDispose(store.close);
        return store;
      }),
    ];

void main() {
  test('runs statements in order, stops on error, splits row vs message',
      () async {
    final container = ProviderContainer(overrides: _memoryStore());
    addTearDown(container.dispose);

    final notifier = container.read(worksheetProvider('ws-x').notifier);
    // 2 row results, 1 successful DDL, then a failing DROP → stop before the
    // final SELECT.
    await notifier.run(
      'SELECT * FROM customers;'
      'SELECT 1 AS n;'
      'CREATE TABLE ms_tmp (id INTEGER);'
      'DROP TABLE does_not_exist;'
      'SELECT 2;',
    );

    final script = container.read(worksheetProvider('ws-x')) as WorksheetScript;
    expect(script.outcomes.length, 4); // 5th (SELECT 2) never ran
    expect(script.outcomes[0].isRows, true);
    expect(script.outcomes[1].isRows, true);
    expect(script.outcomes[2].result, isA<WorksheetMessage>()); // CREATE
    expect(script.outcomes[3].isFailure, true); // DROP → stop-on-error
    expect(script.rowResults.length, 2);
  });

  test('continue-on-error runs every statement despite a failure', () async {
    final container = ProviderContainer(overrides: _memoryStore());
    addTearDown(container.dispose);
    container.read(continueOnErrorProvider.notifier).set(true);

    final notifier = container.read(worksheetProvider('ws-c').notifier);
    await notifier.run(
      'SELECT 1;'
      'DROP TABLE does_not_exist;' // fails, but we continue
      'SELECT 2;',
    );

    final script = container.read(worksheetProvider('ws-c')) as WorksheetScript;
    expect(script.outcomes.length, 3); // none skipped
    expect(script.outcomes[1].isFailure, true);
    expect(script.outcomes[2].isRows, true); // SELECT 2 still ran
  });

  testWidgets('a multi-result script renders result sub-tabs + Messages',
      (tester) async {
    final container = ProviderContainer(overrides: _memoryStore());
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
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

    // The active worksheet runs whatever the sidebar requests.
    container
        .read(requestedQueryProvider.notifier)
        .request('SELECT * FROM customers; SELECT 1 AS n;');
    await tester.pumpAndSettle();

    expect(find.text('Result 1'), findsOneWidget);
    expect(find.text('Result 2'), findsOneWidget);
    expect(find.text('Messages'), findsOneWidget);

    // Switching to Messages shows the per-statement log.
    await tester.tap(find.text('Messages'));
    await tester.pumpAndSettle();
    expect(find.textContaining('row(s)'), findsWidgets);
  });
}
