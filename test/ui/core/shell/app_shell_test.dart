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

/// The shell: menu bar over the sidebar | workspace split.
void main() {
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStoreProvider.overrideWith((ref) {
            final s = LocalStore.memory();
            ref.onDispose(s.close);
            return s;
          }),
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

  testWidgets('File → New Worksheet opens another tab', (tester) async {
    await pump(tester);
    expect(find.text('Query 2'), findsNothing);

    await tester.tap(find.text('File'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('New Worksheet'));
    await tester.pumpAndSettle();

    expect(find.text('Query 2'), findsOneWidget);
  });
}
