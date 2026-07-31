import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:voltquery/main.dart';

void main() {
  testWidgets('VoltQuery boots to the query workspace', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: VoltQueryApp()));
    await tester.pumpAndSettle();
    // Demo session seeds an in-memory DB, then the worksheet renders.
    expect(find.text('▶ Run'), findsOneWidget);
  });
}
