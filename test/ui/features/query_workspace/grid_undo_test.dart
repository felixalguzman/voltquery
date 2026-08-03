import 'package:flutter_test/flutter_test.dart';
import 'package:voltquery/data/drivers/sqlite/sqlite_driver.dart';
import 'package:voltquery/domain/drivers/driver.dart';
import 'package:voltquery/domain/drivers/result.dart';
import 'package:voltquery/domain/models/column_editor.dart';
import 'package:voltquery/domain/models/connection.dart';
import 'package:voltquery/domain/models/engine.dart';
import 'package:voltquery/domain/sql/editable_result.dart';
import 'package:voltquery/domain/sql/sql_statement_splitter.dart';
import 'package:voltquery/ui/features/query_workspace/grid_edit_buffer.dart';
import 'package:voltquery/ui/features/query_workspace/grid_editability.dart';
import 'package:voltquery/ui/features/query_workspace/grid_undo.dart';

/// Undoing an applied batch of grid edits.
///
/// The interesting assertion is not that the SQL looks right — it's that
/// running it puts the table back. So these apply for real against SQLite and
/// compare the whole table before and after.
void main() {
  const editability = GridEditability(
    target: EditableTarget(table: 'customers'),
    primaryKey: ['id'],
    editors: {
      'id': ColumnEditor(kind: ColumnEditorKind.integer, nullable: false),
      'name': ColumnEditor(kind: ColumnEditorKind.text, nullable: true),
      'total': ColumnEditor(kind: ColumnEditorKind.decimal, nullable: true),
    },
  );
  const fields = [
    ResultField(name: 'id', dataType: 'INTEGER', ordinal: 0),
    ResultField(name: 'name', dataType: 'TEXT', ordinal: 1),
    ResultField(name: 'total', dataType: 'REAL', ordinal: 2),
  ];

  late Session session;
  late List<ResultRow> rows;

  Future<List<List<Object?>>> snapshot() async {
    final r = await session.execute('SELECT * FROM customers ORDER BY id')
        as RowsResult;
    final out = await r.cursor.fetch(100);
    await r.cursor.close();
    return [for (final row in out) row.values];
  }

  setUp(() async {
    session = await SqliteDriver().connect(
      const Connection(
        id: 't',
        name: 'mem',
        engine: Engine.sqlite,
        sqlitePath: ':memory:',
      ),
    );
    await session.execute(
      'CREATE TABLE customers (id INTEGER PRIMARY KEY, name TEXT, total REAL)',
    );
    await session.execute(
      "INSERT INTO customers VALUES (1,'Ada',10.5),(2,'Grace',20.0),"
      "(3,NULL,30.25)",
    );
    rows = [for (final v in await snapshot()) ResultRow(v)];
  });

  tearDown(() async => session.close());

  Map<String, Object?>? pk(int i) =>
      i >= 0 && i < rows.length ? {'id': rows[i].values.first} : null;

  GridUndo undoFor(GridEditBuffer buffer) => GridUndo.of(
        buffer: buffer,
        editability: editability,
        dialect: SqlDialect.sqlite,
        fields: fields,
        rows: rows,
        pkValuesFor: pk,
      );

  Future<void> run(List<String> statements) async {
    await session.begin();
    for (final s in statements) {
      await session.execute(s);
    }
    await session.commit();
  }

  /// Apply [buffer], then its undo, and return the table at each point.
  Future<(List<List<Object?>> after, List<List<Object?>> undone)> roundTrip(
    GridEditBuffer buffer,
  ) async {
    final undo = undoFor(buffer); // built before applying, deliberately
    await run(buffer.toSql(
      editability: editability,
      dialect: SqlDialect.sqlite,
      pkValuesFor: pk,
    ));
    final after = await snapshot();
    await run(undo.statements);
    return (after, await snapshot());
  }

  test('an UPDATE round trips back to the values as read', () async {
    final before = await snapshot();
    final buffer = const GridEditBuffer().stage(const StagedEdit(
      rowIndex: 0,
      column: 'name',
      oldValue: 'Ada',
      newValue: 'Ada Lovelace',
    ));

    final (after, undone) = await roundTrip(buffer);
    expect(after[0][1], 'Ada Lovelace');
    expect(undone, before);
  });

  test('a DELETE round trips — the row comes back whole', () async {
    final before = await snapshot();
    final (after, undone) = await roundTrip(const GridEditBuffer().toggleDelete(1));

    expect(after, hasLength(2));
    // Same id, same values, same position in id order.
    expect(undone, before);
  });

  test('a NULL survives the round trip as NULL', () async {
    // Row 3's name is NULL. Re-inserting it as the empty string would be a
    // different row, and the kind of thing nobody notices until a query with
    // `IS NULL` stops matching.
    final before = await snapshot();
    final (_, undone) = await roundTrip(const GridEditBuffer().toggleDelete(2));

    expect(undone, before);
    expect(undone[2][1], isNull);
  });

  test('everything at once round trips', () async {
    final before = await snapshot();
    var buffer = const GridEditBuffer().stage(const StagedEdit(
      rowIndex: 0,
      column: 'total',
      oldValue: 10.5,
      newValue: 99.0,
    ));
    buffer = buffer.toggleDelete(1);

    final (after, undone) = await roundTrip(buffer);
    expect(after, hasLength(2));
    expect(undone, before);
  });

  test('a re-edited cell goes back to what was READ, not the interim value',
      () async {
    // A→B→C must undo to A. `StagedEdit` keeps the original oldValue across
    // re-edits precisely so this works.
    final before = await snapshot();
    var buffer = const GridEditBuffer().stage(const StagedEdit(
      rowIndex: 0, column: 'name', oldValue: 'Ada', newValue: 'B'));
    buffer = buffer.stage(const StagedEdit(
      rowIndex: 0, column: 'name', oldValue: 'B', newValue: 'C'));

    final (after, undone) = await roundTrip(buffer);
    expect(after[0][1], 'C');
    expect(undone, before);
  });

  group('what cannot be undone', () {
    test('an applied INSERT is reported, not silently skipped', () {
      // Its key was assigned by the engine and we never saw it; deleting by the
      // values we did supply could match somebody else's row.
      final undo = undoFor(
        const GridEditBuffer().addRow({'name': 'Katherine'}),
      );
      expect(undo.complete, isFalse);
      expect(undo.insertCount, 1);
      expect(undo.statements, isEmpty);
      expect(undo.summary, contains('cannot be removed'));
    });

    test('a new row that produced no INSERT does not count against it', () {
      // Added, never typed into — it never reached the database.
      final undo = undoFor(const GridEditBuffer().addRow());
      expect(undo.complete, isTrue);
      expect(undo.insertCount, 0);
    });

    test('a mixed batch still undoes the recoverable half', () async {
      final buffer =
          const GridEditBuffer().toggleDelete(0).addRow({'name': 'New'});
      final undo = undoFor(buffer);

      expect(undo.complete, isFalse);
      expect(undo.statements, hasLength(1)); // the deleted row comes back

      await run(buffer.toSql(
        editability: editability,
        dialect: SqlDialect.sqlite,
        pkValuesFor: pk,
      ));
      await run(undo.statements);

      final names = (await snapshot()).map((r) => r[1]).toList();
      expect(names, contains('Ada'), reason: 'the delete was undone');
      expect(names, contains('New'), reason: 'the insert honestly was not');
    });

    test('a row with no resolvable PK is skipped rather than mis-targeted', () {
      final undo = undoFor(const GridEditBuffer().stage(const StagedEdit(
        rowIndex: 99, column: 'name', oldValue: 'x', newValue: 'y')));
      expect(undo.statements, isEmpty);
    });
  });
}
