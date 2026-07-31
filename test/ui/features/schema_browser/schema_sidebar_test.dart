import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltquery/data/services/local_store.dart';
import 'package:voltquery/domain/models/connection.dart';
import 'package:voltquery/domain/models/history_entry.dart';
import 'package:voltquery/ui/core/shell/app_shell.dart';
import 'package:voltquery/ui/features/connections/connection_providers.dart';
import 'package:voltquery/ui/features/history/history_providers.dart';
import 'package:voltquery/ui/features/query_workspace/worksheet_providers.dart';
// requestedQueryProvider drives the active worksheet from the sidebar.

/// Integration for the lazy schema tree (issue #13): the sidebar lists the demo
/// tables, clicking one runs its `SELECT *`, and expanding one lazy-loads its
/// columns.
Future<ProviderContainer> _pumpApp(WidgetTester tester) async {
  final container = ProviderContainer(overrides: [
    localStoreProvider.overrideWith((ref) {
      final store = LocalStore.memory();
      ref.onDispose(store.close);
      return store;
    }),
    // Avoid the drift .watch() streams' pending timers under FakeAsync.
    recentHistoryProvider
        .overrideWith((ref) => Stream.value(const <HistoryEntry>[])),
    savedConnectionsProvider
        .overrideWith((ref) => Stream.value(const <Connection>[])),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: FluentApp(
        debugShowCheckedModeBanner: false,
        home: ScaffoldPage(
          padding: EdgeInsets.zero,
          content: Consumer(builder: (context, ref, _) {
            return ref.watch(introspectionSessionProvider).when(
                  loading: () => const ProgressRing(),
                  error: (e, _) => Text('$e'),
                  data: (_) => const AppShell(),
                );
          }),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('clicking a sidebar table opens it in a NEW tab and runs it',
      (tester) async {
    await _pumpApp(tester);

    // Demo seeds a 'customers' table — the sidebar shows it (SQLite has no
    // schema level, so objects sit at the tree root).
    expect(find.text('customers'), findsOneWidget);
    expect(find.text('Query 2'), findsNothing); // only the default tab so far

    await tester.tap(find.text('customers'));
    await tester.pumpAndSettle();

    // A new worksheet tab opened + ran SELECT * FROM customers → 4 seeded rows,
    // without clobbering the original tab.
    expect(find.text('Query 2'), findsOneWidget);
    expect(find.textContaining('4 row(s)'), findsOneWidget);
  });

  testWidgets('expanding a table lazy-loads its columns', (tester) async {
    await _pumpApp(tester);

    // Columns are not fetched until the node is expanded.
    expect(find.text('email'), findsNothing);
    expect(find.text('total'), findsNothing);

    // Only 'customers' is expandable at the root → its chevron.
    await tester.tap(find.byIcon(FluentIcons.chevron_right));
    await tester.pumpAndSettle();

    // The seeded columns now render (name + type), and expanding did NOT run a
    // query.
    expect(find.text('email'), findsOneWidget);
    expect(find.text('total'), findsOneWidget);
    expect(find.textContaining('row(s)'), findsNothing);
  });

  testWidgets('a multi-statement script with DDL refreshes the tree',
      (tester) async {
    final container = await _pumpApp(tester);

    expect(find.text('ddl_made_me'), findsNothing);

    // The exact shape a user runs: CREATE + INSERT + SELECTs. A successful DDL
    // anywhere in the script evicts the schema cache (ADR-0008), so the sidebar
    // re-introspects and the new table appears — no manual refresh.
    container.read(requestedQueryProvider.notifier).request(
          'CREATE TABLE ddl_made_me (id INTEGER, name TEXT);'
          "INSERT INTO ddl_made_me VALUES (1, 'x');"
          'SELECT * FROM customers;'
          'SELECT * FROM ddl_made_me;',
        );
    await tester.pumpAndSettle();

    expect(find.text('ddl_made_me'), findsOneWidget);
  });
}
