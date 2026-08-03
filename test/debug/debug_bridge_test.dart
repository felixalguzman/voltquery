import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltquery/debug/debug_bridge.dart';

/// What the debug bridge reports back for a Flutter error.
///
/// The extension plumbing needs a live VM service, but the part that can
/// actually be *wrong* is this: turning an error into a summary and a file:line
/// you can act on. An overflow's message names the pixel count and nothing
/// else, so without the location it says a Row is too wide and leaves you to
/// find which one — across a codebase with a lot of Rows.
void main() {
  testWidgets('a real overflow arrives with a usable summary', (tester) async {
    final captured = <CapturedError>[];
    final previous = FlutterError.onError;
    // Chained, exactly as the bridge does it — and necessarily so here: the
    // test binding installs its own handler, and swallowing it hangs the test
    // rather than failing it.
    FlutterError.onError = (details) {
      captured.add(CapturedError(details));
      previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        // Center first: the root hands down *tight* constraints, so a bare
        // SizedBox never actually shrinks and nothing overflows.
        child: Center(
          child: SizedBox(
            width: 50,
            child: Row(children: [SizedBox(width: 400, height: 10)]),
          ),
        ),
      ),
    );
    // Consume it, or the binding fails the test for an unhandled exception.
    expect(tester.takeException(), isNotNull);

    expect(captured, hasLength(1));
    expect(captured.single.summary, contains('overflowed by 350 pixels'));
    expect(captured.single.library, contains('rendering'));
    // `location` is deliberately not asserted here: the source position comes
    // from widget-creation tracking, which `flutter run` enables and
    // `flutter test` does not. The parsing is covered below instead.
  });

  test('the source location is lifted out of the error diagnostics', () {
    // The shape `flutter run --track-widget-creation` produces: the offending
    // widget and where it was built. Under `flutter test` this block is absent,
    // so it is reproduced rather than provoked.
    final error = CapturedError(FlutterErrorDetails(
      exception: FlutterError('A RenderFlex overflowed by 83 pixels.'),
      library: 'rendering library',
      informationCollector: () => [
        DiagnosticsNode.message('The relevant error-causing widget was:'),
        DiagnosticsNode.message(
          'Row Row:file:///home/x/lib/ui/query_workspace/worksheet_view.dart:274:14',
        ),
      ],
    ));

    expect(error.location, 'worksheet_view.dart:274:14');
    expect(error.toJson()['location'], 'worksheet_view.dart:274:14');
  });

  test('an error with no diagnostics still reports its summary', () {
    // Not every error carries an information collector; losing the summary too
    // would leave the bridge reporting nothing at all.
    final error = CapturedError(FlutterErrorDetails(
      exception: StateError('boom'),
      library: 'voltquery',
    ));

    expect(error.summary, contains('boom'));
    expect(error.library, 'voltquery');
    expect(error.location, isNull);
    expect(error.toJson().containsKey('location'), isFalse);
  });
}
