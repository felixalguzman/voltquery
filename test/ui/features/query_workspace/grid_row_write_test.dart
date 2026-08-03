import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltquery/data/services/local_store.dart';
import 'package:voltquery/domain/drivers/result.dart';
import 'package:voltquery/domain/models/column_editor.dart';
import 'package:voltquery/domain/models/history_entry.dart';
import 'package:voltquery/domain/sql/editable_result.dart';
import 'package:voltquery/domain/sql/sql_statement_splitter.dart';
import 'package:voltquery/ui/features/history/history_providers.dart';
import 'package:voltquery/ui/features/query_workspace/grid_edit_buffer.dart';
import 'package:voltquery/ui/features/query_workspace/grid_editability.dart';
import 'package:voltquery/ui/features/query_workspace/result_grid.dart';
import 'package:voltquery/ui/features/query_workspace/worksheet_providers.dart';
import 'package:voltquery/ui/features/query_workspace/worksheet_state.dart';

/// Writing whole rows from the grid — and the row-identity rule the writes
/// depend on.
const _gridId = 'g';

const _editability = GridEditability(
  target: EditableTarget(table: 'customers'),
  primaryKey: ['id'],
  editors: {
    'id': ColumnEditor(kind: ColumnEditorKind.integer, nullable: false),
    'name': ColumnEditor(kind: ColumnEditorKind.text, nullable: true),
  },
);

/// Names deliberately out of id order, so sorting by name reorders the view:
/// row 0 is `c`, row 1 is `a`, row 2 is `b`.
final _rows = WorksheetRows(
  fields: const [
    ResultField(name: 'id', dataType: 'INTEGER', ordinal: 0),
    ResultField(name: 'name', dataType: 'TEXT', ordinal: 1),
  ],
  rows: const [
    ResultRow([1, 'c']),
    ResultRow([2, 'a']),
    ResultRow([3, 'b']),
  ],
  durationMs: 1,
  capped: false,
  editability: _editability,
);

Future<ProviderContainer> _pumpGrid(WidgetTester tester,
    {double width = 1000}) async {
  tester.view.physicalSize = Size(width, 700);
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
            rows: _rows,
            worksheetId: 'ws',
            gridId: _gridId,
            sourceSql: 'SELECT * FROM customers',
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

GridEditBuffer _buffer(ProviderContainer c) =>
    c.read(gridEditsProvider(_gridId));

List<String> _sqlOf(GridEditBuffer b) => b.toSql(
      editability: _editability,
      dialect: SqlDialect.sqlite,
      // Row i holds id i+1, exactly like the seeded rows above.
      pkValuesFor: (i) => i < 3 ? {'id': i + 1} : null,
    );

/// Right-clicks the cell whose rendered text is [cellText], then picks [action]
/// from the menu that opens.
Future<void> _rowAction(
  WidgetTester tester,
  String cellText,
  String action,
) async {
  await tester.tap(find.text(cellText).first, buttons: kSecondaryButton);
  await tester.pumpAndSettle();
  await tester.tap(find.text(action));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a staged edit follows the ROW, not the sorted view position',
      (tester) async {
    final container = await _pumpGrid(tester);

    // Unsorted, the view matches the result: c, a, b.
    expect(
      tester.getTopLeft(find.text('c')).dy,
      lessThan(tester.getTopLeft(find.text('a')).dy),
    );

    // Sort by name. pluto reorders its rows in place and from here on reports
    // *view* indices — which is exactly what used to be staged.
    await tester.tap(find.text('name'));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('a')).dy,
      lessThan(tester.getTopLeft(find.text('c')).dy),
      reason: 'the sort must actually reorder, or this test proves nothing',
    );

    // `a` is now the top row on screen but is still result row 1 (id 2).
    await _rowAction(tester, 'a', 'Set NULL');

    final buf = _buffer(container);
    expect(buf.at(1, 'name')?.newValue, isNull);
    expect(buf.at(1, 'name')?.oldValue, 'a');
    expect(buf.at(0, 'name'), isNull,
        reason: 'row 0 is `c` — it was never touched');
    expect(_sqlOf(buf).single,
        'UPDATE "customers" SET "name" = NULL WHERE "id" = 2;');
  });

  testWidgets('deleting a row stages a PK-qualified DELETE and strikes it out',
      (tester) async {
    final container = await _pumpGrid(tester);

    await _rowAction(tester, 'a', 'Delete Row');

    expect(_buffer(container).isDeleted(1), isTrue);
    expect(_sqlOf(_buffer(container)).single,
        'DELETE FROM "customers" WHERE "id" = 2;');

    // The row is still readable — you should be able to see what you are about
    // to drop — but struck through.
    final struck = tester.widget<Text>(find.text('a').first);
    expect(struck.style?.decoration, TextDecoration.lineThrough);

    // And the action reverses.
    await _rowAction(tester, 'a', 'Keep Row');
    expect(_buffer(container).isEmpty, isTrue);
  });

  testWidgets('a deleted row drops the cell edits already staged on it',
      (tester) async {
    final container = await _pumpGrid(tester);

    await _rowAction(tester, 'a', 'Set NULL');
    expect(_buffer(container).edits, hasLength(1));

    // Via the id cell: `a` is no longer on screen, the staged NULL replaced it.
    // Delete Row is offered there too — a PK cell refuses *cell* edits, not row
    // ones.
    await _rowAction(tester, '2', 'Delete Row');
    // Only the DELETE survives: an UPDATE ordered after it would match nothing.
    expect(_buffer(container).edits, isEmpty);
    expect(_sqlOf(_buffer(container)), hasLength(1));
  });

  testWidgets('Add Row appends an editable row that starts at engine defaults',
      (tester) async {
    final container = await _pumpGrid(tester);

    await tester.tap(find.text('Add Row'));
    await tester.pumpAndSettle();

    expect(_buffer(container).inserts, hasLength(1));
    // Every cell of the new row reads `default`, not NULL — the column is left
    // out of the INSERT, which is not the same as writing NULL into it.
    expect(find.text('default'), findsNWidgets(_rows.fields.length));
    // Nothing to run yet: an empty row is more likely a stray click.
    expect(_sqlOf(_buffer(container)), isEmpty);

    // Giving it one value is enough to make it an INSERT.
    final id = _buffer(container).inserts.single.id;
    container
        .read(gridEditsProvider(_gridId).notifier)
        .setPendingValue(id, 'name', 'Grace');
    await tester.pumpAndSettle();

    expect(_sqlOf(_buffer(container)).single,
        '''INSERT INTO "customers" ("name") VALUES ('Grace');''');

    // Discarding takes the row back off the grid, not just out of the buffer.
    await _rowAction(tester, 'Grace', 'Discard New Row');
    expect(_buffer(container).inserts, isEmpty);
    expect(find.text('default'), findsNothing);
  });

  testWidgets('Duplicate Row copies the row without its primary key',
      (tester) async {
    final container = await _pumpGrid(tester);

    await _rowAction(tester, 'a', 'Duplicate Row');

    final pending = _buffer(container).inserts.single;
    expect(pending.values['name'], 'a');
    // The PK is deliberately absent: copying it collides on the first INSERT,
    // and leaving it unset lets a sequence assign the next one.
    expect(pending.has('id'), isFalse);
    expect(_sqlOf(_buffer(container)).single,
        '''INSERT INTO "customers" ("name") VALUES ('a');''');
  });

  testWidgets('a narrow results pane keeps every action reachable',
      (tester) async {
    // Found by driving the live app: the results pane is user-resizable, and
    // at ~217px the status bar overflowed by 69px — which does not throw in
    // release, it just lays the buttons out past the edge and never paints
    // them. Add Row became untappable.
    final container = await _pumpGrid(tester, width: 260);

    // Staged through the notifier rather than the row menus: at this width the
    // grid's own cells are scrolled off horizontally, and the subject here is
    // the status bar, not how the changes got there.
    final edits = container.read(gridEditsProvider(_gridId).notifier);
    edits.stage(const StagedEdit(
      rowIndex: 1,
      column: 'name',
      oldValue: 'a',
      newValue: 'z',
    ));
    edits.toggleDelete(0);
    edits.addRow();
    await tester.pumpAndSettle();
    expect(_buffer(container).count, 3, reason: 'bar is in its widest state');

    // By key, not tooltip: `find.byTooltip` matches material's Tooltip and this
    // app is on fluent's, a different class entirely. The label is gone at this
    // width anyway, which is the whole point.
    Finder barButton(String label) =>
        find.byKey(ValueKey(gridActionKey(label)));

    for (final label in ['Add Row', 'Discard', 'Review & Apply']) {
      final button = barButton(label);
      expect(button, findsOneWidget, reason: '$label is missing');
      // Past the right edge is exactly what an overflow does — the child is
      // still laid out, just never painted and never hit-testable.
      expect(tester.getBottomRight(button).dx, lessThanOrEqualTo(260.5),
          reason: '$label runs off the 260px pane');
    }

    // Labels are dropped at this width — the icon plus its tooltip is what
    // fits, and losing a word beats losing the button.
    expect(find.text('Review & Apply'), findsNothing);

    // And it is genuinely tappable, which is the thing that broke.
    await tester.tap(barButton('Discard'));
    await tester.pumpAndSettle();
    expect(_buffer(container).isEmpty, isTrue);
  });

  testWidgets('the status bar names the three kinds of pending change',
      (tester) async {
    final container = await _pumpGrid(tester);

    await _rowAction(tester, 'a', 'Set NULL');
    await _rowAction(tester, 'c', 'Delete Row');
    await tester.tap(find.text('Add Row'));
    await tester.pumpAndSettle();

    // "5 pending changes" reads the same whether or not two of them drop rows.
    expect(find.text('1 edit · 1 new · 1 deleted pending'), findsOneWidget);

    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(_buffer(container).isEmpty, isTrue);
    expect(find.text('default'), findsNothing);
  });
}
