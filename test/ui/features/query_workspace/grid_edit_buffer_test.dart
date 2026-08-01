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
