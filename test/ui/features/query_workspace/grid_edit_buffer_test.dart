import 'package:flutter_test/flutter_test.dart';
import 'package:voltquery/domain/models/column_editor.dart';
import 'package:voltquery/domain/sql/editable_result.dart';
import 'package:voltquery/domain/sql/sql_statement_splitter.dart';
import 'package:voltquery/ui/features/query_workspace/grid_edit_buffer.dart';
import 'package:voltquery/ui/features/query_workspace/grid_editability.dart';

/// Staged edits: nothing reaches the database until the generated SQL has been
/// reviewed and committed.
void main() {
  const editability = GridEditability(
    target: EditableTarget(table: 'customers'),
    primaryKey: ['id'],
    editors: {
      // The resolver emits an editor for *every* column including the PK —
      // read-only on an existing row, but a new row has to be able to supply
      // one where the table has no sequence.
      'id': ColumnEditor(kind: ColumnEditorKind.integer, nullable: false),
      'name': ColumnEditor(kind: ColumnEditorKind.text, nullable: true),
      'total': ColumnEditor(kind: ColumnEditorKind.decimal, nullable: true),
      'active': ColumnEditor(kind: ColumnEditorKind.boolean, nullable: false),
    },
  );

  // Row 0 -> id 1, row 1 -> id 2; row 9 has no identity.
  Map<String, Object?>? pk(int rowIndex) =>
      switch (rowIndex) { 0 => {'id': 1}, 1 => {'id': 2}, _ => null };

  List<String> sqlOf(GridEditBuffer b) => b.toSql(
        editability: editability,
        dialect: SqlDialect.postgres,
        pkValuesFor: pk,
      );

  GridEditBuffer stage(
    GridEditBuffer b,
    int row,
    String col,
    Object? oldV,
    Object? newV,
  ) =>
      b.stage(StagedEdit(
          rowIndex: row, column: col, oldValue: oldV, newValue: newV));

  test('starts empty', () {
    const b = GridEditBuffer();
    expect(b.isEmpty, isTrue);
    expect(b.count, 0);
    expect(sqlOf(b), isEmpty);
  });

  test('staging a change marks the cell dirty', () {
    final b = stage(const GridEditBuffer(), 0, 'name', 'Ada', 'Grace');
    expect(b.count, 1);
    expect(b.isDirty(0, 'name'), isTrue);
    expect(b.isDirty(0, 'total'), isFalse);
    expect(b.at(0, 'name')!.newValue, 'Grace');
  });

  test('re-editing the same cell replaces, keeping the ORIGINAL old value', () {
    var b = stage(const GridEditBuffer(), 0, 'name', 'Ada', 'Grace');
    b = stage(b, 0, 'name', 'Grace', 'Katherine');
    expect(b.count, 1);
    // oldValue must still be what was read from the DB, not the interim edit —
    // otherwise an undo-to-original wouldn't be recognised.
    expect(b.at(0, 'name')!.oldValue, 'Ada');
    expect(b.at(0, 'name')!.newValue, 'Katherine');
  });

  test('editing back to the original value drops the edit (no no-op UPDATE)',
      () {
    var b = stage(const GridEditBuffer(), 0, 'name', 'Ada', 'Grace');
    b = stage(b, 0, 'name', 'Grace', 'Ada');
    expect(b.isEmpty, isTrue);
    expect(sqlOf(b), isEmpty);
  });

  test('NULL and empty string are different values', () {
    // '' -> NULL is a real change...
    var b = stage(const GridEditBuffer(), 0, 'name', '', null);
    expect(b.count, 1);
    // ...and NULL -> NULL is not.
    b = stage(const GridEditBuffer(), 0, 'name', null, null);
    expect(b.isEmpty, isTrue);
    // '' -> '' is not either.
    b = stage(const GridEditBuffer(), 0, 'name', '', '');
    expect(b.isEmpty, isTrue);
  });

  test('discardCell removes one edit, clear removes all', () {
    var b = stage(const GridEditBuffer(), 0, 'name', 'Ada', 'Grace');
    b = stage(b, 1, 'name', 'Alan', 'Turing');
    expect(b.count, 2);
    b = b.discardCell(0, 'name');
    expect(b.count, 1);
    expect(b.isDirty(1, 'name'), isTrue);
    expect(b.clear().isEmpty, isTrue);
  });

  group('toSql', () {
    test('one UPDATE per row, PK-qualified', () {
      final b = stage(const GridEditBuffer(), 0, 'name', 'Ada', 'Grace');
      expect(sqlOf(b), [
        '''UPDATE "customers" SET "name" = 'Grace' WHERE "id" = 1;''',
      ]);
    });

    test('edits to the same row collapse into ONE statement', () {
      var b = stage(const GridEditBuffer(), 0, 'name', 'Ada', 'Grace');
      b = stage(b, 0, 'total', 1, 2.5);
      final sql = sqlOf(b);
      expect(sql, hasLength(1));
      expect(sql.single, contains('"name" = \'Grace\''));
      expect(sql.single, contains('"total" = 2.5'));
    });

    test('rows come out in row order', () {
      var b = stage(const GridEditBuffer(), 1, 'name', 'Alan', 'Turing');
      b = stage(b, 0, 'name', 'Ada', 'Grace');
      final sql = sqlOf(b);
      expect(sql, hasLength(2));
      expect(sql[0], contains('"id" = 1'));
      expect(sql[1], contains('"id" = 2'));
    });

    test('editor kind drives encoding', () {
      final b = stage(const GridEditBuffer(), 0, 'active', false, true);
      expect(sqlOf(b).single, contains('"active" = TRUE'));
    });

    test('a row with no resolvable PK is skipped, not mis-targeted', () {
      final b = stage(const GridEditBuffer(), 9, 'name', 'x', 'y');
      expect(sqlOf(b), isEmpty);
    });

    test('a column with no editor (an expression) is not written back', () {
      final b = stage(const GridEditBuffer(), 0, 'computed', 1, 2);
      expect(sqlOf(b), isEmpty);
    });

    test('dialect is honoured', () {
      final b = stage(const GridEditBuffer(), 0, 'name', 'Ada', 'Grace');
      final mysql = b.toSql(
        editability: editability,
        dialect: SqlDialect.mysql,
        pkValuesFor: pk,
      );
      expect(mysql.single, startsWith('UPDATE `customers`'));
    });
  });

  group('deleting rows', () {
    test('toggleDelete marks and unmarks', () {
      var b = const GridEditBuffer().toggleDelete(0);
      expect(b.isDeleted(0), isTrue);
      expect(b.isDeleted(1), isFalse);
      expect(b.count, 1);
      b = b.toggleDelete(0);
      expect(b.isDeleted(0), isFalse);
      expect(b.isEmpty, isTrue);
    });

    test('a DELETE is PK-qualified', () {
      final b = const GridEditBuffer().toggleDelete(1);
      expect(sqlOf(b), ['DELETE FROM "customers" WHERE "id" = 2;']);
    });

    test('a row with no resolvable PK is skipped, not mis-targeted', () {
      // The dangerous failure mode is an unqualified DELETE; skipping is the
      // only safe answer when the row can't be addressed.
      final b = const GridEditBuffer().toggleDelete(9);
      expect(sqlOf(b), isEmpty);
    });

    test('deleting a row discards its staged cell edits', () {
      var b = stage(const GridEditBuffer(), 0, 'name', 'Ada', 'Grace');
      b = stage(b, 1, 'name', 'Alan', 'Turing');
      b = b.toggleDelete(0);

      // Row 0's UPDATE is gone — it would have run *after* the DELETE and
      // silently matched nothing. Row 1's survives.
      expect(b.edits.length, 1);
      final sql = sqlOf(b);
      expect(sql, hasLength(2));
      expect(sql[0], startsWith('DELETE'));
      expect(sql[1], contains('"id" = 2'));
    });
  });

  group('inserting rows', () {
    test('a new row with no values produces no statement', () {
      // `INSERT ... DEFAULT VALUES` is spelled three ways across our engines,
      // and an empty row is far more likely to be a stray click.
      final b = const GridEditBuffer().addRow();
      expect(b.count, 1);
      expect(b.isEmpty, isFalse);
      expect(sqlOf(b), isEmpty);
    });

    test('only the columns the user set appear in the INSERT', () {
      var b = const GridEditBuffer().addRow();
      final id = b.inserts.single.id;
      b = b.setPendingValue(id, 'name', 'Grace');
      // `total` is deliberately left alone so its default still applies.
      expect(sqlOf(b), [
        '''INSERT INTO "customers" ("name") VALUES ('Grace');''',
      ]);
    });

    test('a column set to NULL is different from one never touched', () {
      var b = const GridEditBuffer().addRow();
      final id = b.inserts.single.id;
      b = b.setPendingValue(id, 'name', null);
      expect(b.pendingCell(id, 'name'), (true, null));
      expect(b.pendingCell(id, 'total'), (false, null));
      expect(sqlOf(b).single, contains('("name") VALUES (NULL)'));

      // ...and clearing it takes the column back out of the statement.
      b = b.clearPendingValue(id, 'name');
      expect(b.pendingCell(id, 'name'), (false, null));
      expect(sqlOf(b), isEmpty);
    });

    test('editor kind drives encoding, PK included', () {
      var b = const GridEditBuffer().addRow();
      final id = b.inserts.single.id;
      b = b.setPendingValue(id, 'id', '7');
      b = b.setPendingValue(id, 'active', true);
      final sql = sqlOf(b).single;
      expect(sql, contains('"id"'));
      expect(sql, contains('7')); // integer editor → bare literal
      expect(sql, contains('TRUE')); // boolean on Postgres
    });

    test('a seeded row is how "duplicate" arrives', () {
      final b = const GridEditBuffer().addRow({'name': 'Ada', 'total': 3});
      expect(sqlOf(b).single,
          '''INSERT INTO "customers" ("name", "total") VALUES ('Ada', 3);''');
    });

    test('discarding one new row leaves the others addressable', () {
      var b = const GridEditBuffer().addRow({'name': 'a'});
      b = b.addRow({'name': 'b'});
      b = b.addRow({'name': 'c'});
      final second = b.inserts[1].id;
      b = b.removePendingRow(second);

      expect(b.inserts.map((r) => r.values['name']), ['a', 'c']);
      // Ids are never reused, so the row that shifted into slot 1 is still
      // reached by its own id — the whole reason rows aren't keyed by position.
      expect(b.pending(second), isNull);
      b = b.setPendingValue(b.inserts[1].id, 'name', 'c2');
      expect(b.inserts[1].values['name'], 'c2');
      expect(b.inserts[0].values['name'], 'a');
    });

    test('a new row id is never reused, even after clear', () {
      var b = const GridEditBuffer().addRow();
      final first = b.inserts.single.id;
      b = b.clear().addRow();
      expect(b.inserts.single.id, isNot(first));
    });
  });

  test('statement order is DELETE, then UPDATE, then INSERT', () {
    // The order that survives a unique index: freeing a key before something
    // else claims it. Reversing any pair breaks a case the other doesn't.
    var b = stage(const GridEditBuffer(), 0, 'name', 'Ada', 'Grace');
    b = b.toggleDelete(1);
    b = b.addRow({'name': 'Katherine'});

    final sql = sqlOf(b);
    expect(sql, hasLength(3));
    expect(sql[0], startsWith('DELETE'));
    expect(sql[1], startsWith('UPDATE'));
    expect(sql[2], startsWith('INSERT'));
  });

  test('count separates the three kinds', () {
    var b = stage(const GridEditBuffer(), 0, 'name', 'Ada', 'Grace');
    b = b.toggleDelete(1).addRow();
    expect(b.edits.length, 1);
    expect(b.deletes.length, 1);
    expect(b.inserts.length, 1);
    expect(b.count, 3);
    expect(b.clear().isEmpty, isTrue);
  });

  test('primary-key columns are flagged read-only', () {
    expect(editability.isPrimaryKey('id'), isTrue);
    expect(editability.isPrimaryKey('ID'), isTrue); // case-insensitive
    expect(editability.isPrimaryKey('name'), isFalse);
  });

  test('editorFor matches field names case-insensitively', () {
    expect(editability.editorFor('NAME')?.kind, ColumnEditorKind.text);
    expect(editability.editorFor('nope'), isNull);
  });
}
