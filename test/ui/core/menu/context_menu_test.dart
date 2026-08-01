import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltquery/ui/core/menu/context_menu.dart';

/// The one context-menu primitive (#53): a right-click opens the actions at the
/// pointer; selecting one fires it and closes the menu. Primary taps pass
/// through untouched.
void main() {
  testWidgets('right-click opens the menu; selecting fires + closes', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    var primaryTaps = 0;
    await tester.pumpWidget(
      FluentApp(
        debugShowCheckedModeBanner: false,
        home: Center(
          child: GestureDetector(
            onTap: () => primaryTaps++,
            child: ContextMenuRegion(
              actions: [
                MenuAction(
                  'Copy Name',
                  () => Clipboard.setData(const ClipboardData(text: 'orders')),
                ),
                MenuAction.divider,
                MenuAction('Preview Data', () {}),
              ],
              child: const Text('node'),
            ),
          ),
        ),
      ),
    );

    // Hidden until a secondary tap; a primary tap passes through to the parent.
    expect(find.text('Copy Name'), findsNothing);
    await tester.tap(find.text('node'));
    await tester.pump();
    expect(primaryTaps, 1);
    expect(find.text('Copy Name'), findsNothing);

    // Right-click reveals the actions.
    await tester.tap(find.text('node'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    expect(find.text('Copy Name'), findsOneWidget);
    expect(find.text('Preview Data'), findsOneWidget);

    // Selecting an action fires it, writes to the clipboard, and closes.
    await tester.tap(find.text('Copy Name'));
    await tester.pumpAndSettle();
    expect(copied, 'orders');
    expect(find.text('Copy Name'), findsNothing);
  });

  testWidgets('no actions → no menu anchor, child renders bare', (
    tester,
  ) async {
    await tester.pumpWidget(
      const FluentApp(
        debugShowCheckedModeBanner: false,
        home: Center(
          child: ContextMenuRegion(actions: [], child: Text('bare')),
        ),
      ),
    );
    expect(find.text('bare'), findsOneWidget);
  });
}
