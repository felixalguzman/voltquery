import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltquery/data/services/local_store.dart';
import 'package:voltquery/domain/models/connection.dart';
import 'package:voltquery/domain/models/history_entry.dart';
import 'package:voltquery/ui/core/shell/app_shell.dart';
import 'package:voltquery/ui/core/widgets/section_header.dart';
import 'package:voltquery/ui/features/connections/connection_providers.dart';
import 'package:voltquery/ui/features/history/history_panel.dart';
import 'package:voltquery/ui/features/history/history_providers.dart';
import 'package:voltquery/ui/features/query_workspace/worksheet_tabs.dart';
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

  // `panes` keeps a hidden or collapsed pane's subtree built and clips it to
  // the allotted size, so these assert geometry rather than presence — a finder
  // would happily find a widget the user cannot see.
  testWidgets('collapsing a sidebar section shrinks it to its header',
      (tester) async {
    await pump(tester);

    expect(tester.getSize(find.byType(HistoryPanel)).height,
        greaterThan(kSectionHeaderHeight));

    // Tapping the header collapses the section. The title stays on screen, so
    // collapsing is never a one-way trip.
    await tester.tap(find.text('HISTORY'));
    await tester.pumpAndSettle();

    expect(find.text('HISTORY'), findsOneWidget);
    expect(tester.getSize(find.byType(HistoryPanel)).height,
        kSectionHeaderHeight);

    await tester.tap(find.text('HISTORY'));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(HistoryPanel)).height,
        greaterThan(kSectionHeaderHeight));
  });

  testWidgets('the menu-bar layout buttons toggle the same panes as the menu',
      (tester) async {
    await pump(tester);
    expect(tester.getSize(find.byType(HistoryPanel)).height,
        greaterThan(kSectionHeaderHeight));

    // The History toggle is the last button in the bar's layout cluster.
    await tester.tap(find.byIcon(FluentIcons.history).last);
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(HistoryPanel)).height,
        kSectionHeaderHeight);
  });

  testWidgets('View → Toggle Sidebar gives the workspace the whole width',
      (tester) async {
    await pump(tester);
    final full = tester.getSize(find.byType(AppShell)).width;
    expect(tester.getRect(find.byType(WorksheetTabBar)).left, greaterThan(0));

    Future<void> toggle() async {
      await tester.tap(find.text('View'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Toggle Sidebar'));
      await tester.pumpAndSettle();
    }

    await toggle();
    // Not exactly 0: the sidebar is an `autoHide` pane, so `panes` keeps its
    // 1px resizer on screen as a grab strip to drag the sidebar back out.
    expect(tester.getRect(find.byType(WorksheetTabBar)).left,
        lessThanOrEqualTo(1));
    expect(tester.getSize(find.byType(WorksheetTabBar)).width,
        greaterThanOrEqualTo(full - 1));

    await toggle();
    expect(tester.getRect(find.byType(WorksheetTabBar)).left, greaterThan(1));
  });
}
