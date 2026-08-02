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
import 'package:voltquery/ui/features/schema_browser/schema_providers.dart';

/// A filtered hit row splits its width between the object name and the schema
/// label beside it. Those were both `Flexible`, so each took half the row —
/// and long table names ellipsised while the short schema label sat in space it
/// never needed. Real names on a real schema are long
/// (`cli_orden_medica_recien_nacido`), so this was most of them.
void main() {
  testWidgets('a long name uses the space the schema label does not',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(overrides: [
      localStoreProvider.overrideWith((ref) {
        final store = LocalStore.memory();
        ref.onDispose(store.close);
        return store;
      }),
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

    // A column hit — those are the ones that carry a trailing label (their
    // owning table), which is what competed with the name for width. `sku`
    // lives on `products`, so this also comes back via the catalog leg.
    container.read(schemaFilterProvider.notifier).set('sku');
    await tester.pumpAndSettle();

    // Scoped to the results list: fluent wraps its TextBox in a HoverButton,
    // so a HoverButton-scoped finder matches the filter field's own text too.
    final name = find
        .descendant(
          of: find.byType(ListView),
          matching: find.text('sku'),
        )
        .first;
    expect(name, findsOneWidget);

    // Measured against *this* row, not some other HoverButton on screen.
    final row = find.ancestor(of: name, matching: find.byType(HoverButton));
    final rowWidth = tester.getSize(row.first).width;
    final nameWidth = tester.getSize(name).width;
    final labelWidth = tester
        .getSize(find
            .descendant(of: row.first, matching: find.text('products'))
            .first)
        .width;

    // The two labels together should account for most of the row. With two
    // competing Flexible children each took only its intrinsic width and the
    // leftover went nowhere — so a long name ellipsised while the row had
    // space to spare. The name must also outweigh the schema label: it is the
    // thing you are reading.
    expect(nameWidth + labelWidth, greaterThan(rowWidth * 0.7),
        reason: 'name $nameWidth + label $labelWidth of row $rowWidth');
    expect(nameWidth, greaterThan(labelWidth));
  });
}
