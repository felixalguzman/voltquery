import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltquery/data/services/local_store.dart';
import 'package:voltquery/domain/drivers/result.dart';
import 'package:voltquery/domain/export/result_export.dart';
import 'package:voltquery/domain/models/history_entry.dart';
import 'package:voltquery/ui/features/history/history_providers.dart';
import 'package:voltquery/ui/features/query_workspace/result_grid.dart';
import 'package:voltquery/ui/features/query_workspace/worksheet_state.dart';

/// Exporting from the grid, end to end through the dialog.
///
/// The serializers are tested on their own; this is about the part a user
/// touches — that the button opens the dialog, the choices reach the exporter,
/// and a capped result says so instead of quietly handing over a fraction of
/// the table.
WorksheetRows _rows({bool capped = false}) => WorksheetRows(
      fields: const [
        ResultField(name: 'id', dataType: 'INTEGER', ordinal: 0),
        ResultField(name: 'name', dataType: 'TEXT', ordinal: 1),
      ],
      rows: const [
        ResultRow([1, 'Ada']),
        ResultRow([2, null]),
      ],
      durationMs: 1,
      capped: capped,
    );

Future<List<String>> _pump(
  WidgetTester tester, {
  bool capped = false,
  String? sourceSql,
}) async {
  tester.view.physicalSize = const Size(1100, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  // Clipboard has no implementation under test — capture what it is handed.
  final copied = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map)['text'] as String);
      }
      return null;
    },
  );
  addTearDown(() => tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, null));

  final container = ProviderContainer(overrides: [
    localStoreProvider.overrideWith((ref) {
      final store = LocalStore.memory();
      ref.onDispose(store.close);
      return store;
    }),
    recentHistoryProvider
        .overrideWith((ref) => Stream.value(const <HistoryEntry>[])),
  ]);
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: FluentApp(
        debugShowCheckedModeBanner: false,
        home: ScaffoldPage(
          padding: EdgeInsets.zero,
          content: ResultGrid(
            rows: _rows(capped: capped),
            worksheetId: 'ws',
            gridId: 'g',
            sourceSql: sourceSql,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return copied;
}

Future<void> _openExport(WidgetTester tester) async {
  await tester.tap(find.byKey(ValueKey(gridActionKey('Export'))));
  await tester.pumpAndSettle();
}

/// Confirms the dialog and drains the success InfoBar.
///
/// That toast auto-dismisses on a Timer, and a timer still pending when the
/// tree is torn down fails the test for a reason that has nothing to do with
/// exporting.
Future<void> _confirm(WidgetTester tester) async {
  await tester.tap(find.text('Copy'));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 10));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Export copies the visible rows as CSV', (tester) async {
    final copied = await _pump(tester);

    await _openExport(tester);
    expect(find.text('Export results'), findsOneWidget);

    await _confirm(tester);

    expect(copied, hasLength(1));
    // CSV is the default, header included, NULL as empty.
    expect(copied.single, 'id,name\n1,Ada\n2,\n');
  });

  testWidgets('the chosen format reaches the exporter', (tester) async {
    final copied = await _pump(tester);
    await _openExport(tester);

    await tester.tap(find.byType(ComboBox<ExportFormat>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('JSON').last);
    await tester.pumpAndSettle();
    await _confirm(tester);

    expect(copied.single, startsWith('['));
    expect(copied.single, contains('"name":"Ada"'));
    // JSON has a real null, so it is never replaced with placeholder text.
    expect(copied.single, contains('"name":null'));
  });

  testWidgets('turning the header off drops the column names', (tester) async {
    final copied = await _pump(tester);
    await _openExport(tester);

    await tester.tap(find.text('Include column names'));
    await tester.pumpAndSettle();
    await _confirm(tester);

    expect(copied.single, '1,Ada\n2,\n');
  });

  testWidgets('a capped result warns before it exports a fraction of a table',
      (tester) async {
    // Without the source SQL there is nothing to re-run, so the only honest
    // move is to say the export is partial.
    await _pump(tester, capped: true);
    await _openExport(tester);

    expect(find.textContaining('only the loaded rows'), findsOneWidget);
    expect(find.textContaining('All rows'), findsNothing);
  });

  testWidgets('with the source statement known, all rows is offered — and is '
      'the default when capped', (tester) async {
    await _pump(tester, capped: true, sourceSql: 'SELECT * FROM t');
    await _openExport(tester);

    expect(find.textContaining('All rows'), findsOneWidget);
    // Defaulting to the visible slice on a capped result is the silent-wrong
    // -answer default, so it must not be the one preselected.
    expect(find.textContaining('More rows matched'), findsNothing);
  });

  testWidgets('an uncapped result does not nag about partial exports',
      (tester) async {
    await _pump(tester, sourceSql: 'SELECT * FROM t');
    await _openExport(tester);

    expect(find.textContaining('More rows matched'), findsNothing);
    expect(find.textContaining('only the loaded rows'), findsNothing);
  });
}
