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

/// Integration for the lazy schema tree (issue #13): the sidebar lists the demo
/// tables, clicking one runs its `SELECT *`, and expanding one lazy-loads its
/// columns.
Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
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
      ],
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
}

void main() {
  testWidgets('clicking a sidebar table runs SELECT * for it', (tester) async {
    await _pumpApp(tester);

    // Demo seeds a 'customers' table — the sidebar shows it (SQLite has no
    // schema level, so objects sit at the tree root).
    expect(find.text('customers'), findsOneWidget);

    await tester.tap(find.text('customers'));
    await tester.pumpAndSettle();

    // Worksheet ran SELECT * FROM customers → 4 seeded rows.
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
}
