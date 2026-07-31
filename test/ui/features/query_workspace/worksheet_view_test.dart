import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltquery/data/drivers/sqlite/sqlite_driver.dart';
import 'package:voltquery/domain/models/connection.dart';
import 'package:voltquery/domain/models/engine.dart';
import 'package:voltquery/ui/features/query_workspace/worksheet_providers.dart';
import 'package:voltquery/ui/features/query_workspace/worksheet_view.dart';

/// End-to-end wiring smoke test: editor → SQLite driver → grid, with the demo
/// session overridden by a seeded in-memory one. Asserts on the result pane's
/// own status bar (pluto_grid renders cells via a custom renderer).
void main() {
  testWidgets('running the seeded query produces a rows result', (tester) async {
    final session = await SqliteDriver().connect(
      const Connection(
          id: 'd', name: 'd', engine: Engine.sqlite, sqlitePath: ':memory:'),
    );
    await session.execute('CREATE TABLE customers (id INTEGER, name TEXT)');
    await session.execute(
        "INSERT INTO customers VALUES (1, 'Ada'), (2, 'Grace')");

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith((ref) async => session)],
        child: FluentApp(
          debugShowCheckedModeBanner: false,
          home: ScaffoldPage(
            padding: EdgeInsets.zero,
            // Mirror _Home: watch the session so it resolves before Run.
            content: Consumer(builder: (context, ref, _) {
              return ref.watch(sessionProvider).when(
                    loading: () => const ProgressRing(),
                    error: (e, _) => Text('$e'),
                    data: (_) => const WorksheetView(),
                  );
            }),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('▶ Run'), findsOneWidget); // editor pane rendered

    await tester.tap(find.text('▶ Run'));
    await tester.pumpAndSettle();

    // Result pane status bar proves connect → query → grid ran (2 seeded rows).
    expect(find.textContaining('2 row(s)'), findsOneWidget);
  });
}
