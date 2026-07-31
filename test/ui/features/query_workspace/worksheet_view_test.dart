import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltquery/ui/features/query_workspace/worksheet_view.dart';

/// End-to-end: a Worksheet runs its editor SQL against its own Session and
/// renders rows. Uses the real (shared-cache in-memory) demo — 4 seeded rows.
void main() {
  testWidgets('running the default query renders the demo rows', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: FluentApp(
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
}
