import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltquery/ui/core/shell/app_shell.dart';
import 'package:voltquery/ui/features/query_workspace/worksheet_providers.dart';

/// Integration: the schema sidebar lists the demo tables, and clicking one
/// loads + runs its query in the worksheet.
void main() {
  testWidgets('clicking a sidebar table runs SELECT * for it', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: FluentApp(
          debugShowCheckedModeBanner: false,
          home: ScaffoldPage(
            padding: EdgeInsets.zero,
            content: Consumer(builder: (context, ref, _) {
              return ref.watch(sessionProvider).when(
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

    // Demo seeds a 'customers' table — the sidebar shows it.
    expect(find.text('customers'), findsOneWidget);

    await tester.tap(find.text('customers'));
    await tester.pumpAndSettle();

    // Worksheet ran SELECT * FROM customers → 4 seeded rows.
    expect(find.textContaining('4 row(s)'), findsOneWidget);
  });
}
