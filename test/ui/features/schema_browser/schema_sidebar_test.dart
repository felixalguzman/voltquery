import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltquery/data/services/local_store.dart';
import 'package:voltquery/domain/models/connection.dart';
import 'package:voltquery/domain/models/history_entry.dart';
import 'package:voltquery/ui/core/shell/app_shell.dart';
import 'package:voltquery/ui/features/connections/connection_providers.dart';
import 'package:voltquery/ui/features/history/history_providers.dart';
import 'package:voltquery/ui/features/query_workspace/worksheet_providers.dart';
import 'package:voltquery/ui/features/schema_browser/schema_providers.dart';
import 'package:voltquery/ui/features/settings/settings_providers.dart';
// requestedQueryProvider drives the active worksheet from the sidebar.

/// Integration for the lazy schema tree (issue #13): the sidebar lists the demo
/// tables, clicking one runs its `SELECT *`, and expanding one lazy-loads its
/// columns.
Future<ProviderContainer> _pumpApp(WidgetTester tester) async {
  // The default 800x600 test surface is too short for the demo schema once a
  // table is expanded — nodes below the fold simply aren't built, so finders
  // miss them. Give the tree room instead of scrolling in every test.
  tester.view.physicalSize = const Size(1400, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

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

    // The demo now has several tables. They render tables-then-views, each
    // group in name order (`sqlite_master … ORDER BY name`), so the roots are:
    //   0 audit_log · 1 customers · 2 order_items · 3 orders · 4 products
    //   5 customer_orders (view)
    // Guard that assumption, then tap `customers`' own chevron.
    expect(find.text('audit_log'), findsOneWidget);
    expect(find.text('customers'), findsOneWidget);
    await tester.tap(find.byIcon(FluentIcons.chevron_right).at(1));
    await tester.pumpAndSettle();

    // The seeded columns now render (name + type), and expanding did NOT run a
    // query.
    expect(find.text('email'), findsOneWidget);
    expect(find.text('total'), findsOneWidget);
    expect(find.textContaining('row(s)'), findsNothing);
    // An Indexes group hangs under the table (lazy).
    expect(find.text('Indexes'), findsOneWidget);
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
          run: true,
        );
    await tester.pumpAndSettle();

    expect(find.text('ddl_made_me'), findsOneWidget);
  });

  testWidgets('right-click a table → context menu; Open in Editor seeds, no run',
      (tester) async {
    await _pumpApp(tester);
    expect(find.text('customers'), findsOneWidget);
    expect(find.text('Query 2'), findsNothing);

    // Right-click the node → the #53 context menu.
    await tester.tap(find.text('customers'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    expect(find.text('Copy CREATE'), findsOneWidget);
    expect(find.text('Open in Editor'), findsOneWidget);
    expect(find.text('Preview Data'), findsOneWidget);

    // "Open in Editor" opens a new tab but does NOT auto-run (unlike a row-tap).
    await tester.tap(find.text('Open in Editor'));
    await tester.pumpAndSettle();
    expect(find.text('Query 2'), findsOneWidget);
    expect(find.textContaining('row(s)'), findsNothing);
  });

  testWidgets('clicking the same table returns to its tab, not a new one',
      (tester) async {
    await _pumpApp(tester);

    // First click opens a worksheet for it.
    await tester.tap(find.text('customers'));
    await tester.pumpAndSettle();
    expect(find.text('Query 2'), findsOneWidget);
    expect(find.text('Query 3'), findsNothing);

    // Clicking it again should go back to that worksheet rather than spawning
    // another — otherwise a few clicks leave a dozen identical tabs.
    await tester.tap(find.text('customers'));
    await tester.pumpAndSettle();
    expect(find.text('Query 3'), findsNothing);

    // A *different* table still gets its own.
    await tester.tap(find.text('products'));
    await tester.pumpAndSettle();
    expect(find.text('Query 3'), findsOneWidget);
  });

  testWidgets('the filter narrows the tree to matching tables', (tester) async {
    final container = await _pumpApp(tester);

    expect(find.text('customers'), findsOneWidget);
    expect(find.text('orders'), findsOneWidget);

    // Substring, not prefix: "der" sits inside "orders" and "order_items".
    container.read(schemaFilterProvider.notifier).set('der');
    await tester.pumpAndSettle();

    // Scoped to hit titles: a column hit also prints its owning table as the
    // trailing label, so a bare find.text would count that too.
    Finder hitTitled(String name) => find.descendant(
          of: find.byType(HoverButton),
          matching: find.text(name),
        );
    expect(hitTitled('orders'), findsWidgets);
    expect(hitTitled('order_items'), findsWidgets);
    expect(find.text('customers'), findsNothing);
    expect(find.text('products'), findsNothing);

    // Clearing restores the tree — including whatever was expanded, since
    // filtering renders a separate list rather than rebuilding the tree.
    container.read(schemaFilterProvider.notifier).set('');
    await tester.pumpAndSettle();
    expect(find.text('customers'), findsOneWidget);
  });

  testWidgets('a filter with no local match says so once the catalog agrees',
      (tester) async {
    final container = await _pumpApp(tester);

    container.read(schemaFilterProvider.notifier).set('no_such_table');
    await tester.pumpAndSettle();

    expect(find.textContaining('No match'), findsOneWidget);
  });

  testWidgets('the filter escalates to the catalog for unloaded columns',
      (tester) async {
    final container = await _pumpApp(tester);

    // `sku` lives on `products`, which has never been expanded — so it is not
    // in the tree's loaded model and the local pass finds nothing. The catalog
    // leg is the only thing that can answer, which is the whole point: the
    // filter used to dead-end at "no match in what is loaded".
    container.read(schemaFilterProvider.notifier).set('sku');
    await tester.pumpAndSettle();

    expect(find.text('ELSEWHERE IN DB'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(HoverButton),
        matching: find.text('sku'),
      ),
      findsWidgets,
    );
  });

  testWidgets('a filtered column hit opens its table', (tester) async {
    final container = await _pumpApp(tester);

    // Columns only enter the index once their table is expanded.
    await tester.tap(find.byIcon(FluentIcons.chevron_right).at(1));
    await tester.pumpAndSettle();
    expect(find.text('email'), findsOneWidget);

    container.read(schemaFilterProvider.notifier).set('email');
    await tester.pumpAndSettle();

    // Scoped to the results list — the filter box itself now contains the
    // word "email" too.
    final hit = find.descendant(
      of: find.byType(ListView),
      matching: find.text('email'),
    );
    expect(hit, findsOneWidget);
    await tester.tap(hit);
    await tester.pumpAndSettle();

    expect(find.text('Query 2'), findsOneWidget);
  });

  testWidgets('an expanded table is still expanded after a reconnect',
      (tester) async {
    // The whole point: the tree is lazy, so without this every launch starts
    // collapsed and you re-open the same four tables every morning.
    final container = await _pumpApp(tester);

    await tester.tap(find.byIcon(FluentIcons.chevron_right).at(1));
    await tester.pumpAndSettle();
    expect(find.text('email'), findsOneWidget);

    // Persisted against the connection, not the widget.
    final saved = await container
        .read(uiStateRepositoryProvider)
        .readTreeExpansion('demo');
    expect(saved.paths, contains('customers'));

    // Rebuild the sidebar from scratch — the same thing a reconnect does.
    container.invalidate(schemaRepositoryProvider);
    await tester.pumpAndSettle();

    expect(find.text('email'), findsOneWidget,
        reason: 'the expansion should have been restored');
  });

  testWidgets('collapsing forgets it again', (tester) async {
    final container = await _pumpApp(tester);

    await tester.tap(find.byIcon(FluentIcons.chevron_right).at(1));
    await tester.pumpAndSettle();
    // Scoped to the tree: the section headers and the Run dropdown use
    // chevron_down too, so an unscoped `.first` collapses a whole panel.
    await tester.tap(find.descendant(
      of: find.byType(TreeView),
      matching: find.byIcon(FluentIcons.chevron_down),
    ).first);
    await tester.pumpAndSettle();

    final saved = await container
        .read(uiStateRepositoryProvider)
        .readTreeExpansion('demo');
    expect(saved.paths, isNot(contains('customers')));
  });

  testWidgets('the table preview LIMIT comes from settings', (tester) async {
    final container = await _pumpApp(tester);

    // `customers` has 4 seeded rows; asserting on the row count proves the
    // setting reached the generated SQL, not merely the editor buffer.
    await container
        .read(settingsProvider.notifier)
        .edit((s) => s.copyWith(tablePreviewLimit: 2));
    await tester.pumpAndSettle();

    await tester.tap(find.text('customers'));
    await tester.pumpAndSettle();

    expect(find.textContaining('2 row(s)'), findsOneWidget);
  });
}
