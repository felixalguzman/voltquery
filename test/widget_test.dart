import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:voltquery/main.dart';

void main() {
  testWidgets('VoltQuery scaffold builds', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: VoltQueryApp()));
    expect(find.text('VoltQuery — scaffold. Build the SQLite slice next.'),
        findsOneWidget);
  });
}
