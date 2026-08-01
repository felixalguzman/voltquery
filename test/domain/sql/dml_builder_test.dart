import 'package:flutter_test/flutter_test.dart';
import 'package:voltquery/domain/models/column_editor.dart';
import 'package:voltquery/domain/sql/dml_builder.dart';
import 'package:voltquery/domain/sql/editable_result.dart';
import 'package:voltquery/domain/sql/sql_statement_splitter.dart';

/// Removes every single-quoted literal (honouring `''` escapes) so assertions
/// can look at just the SQL *structure*. Content inside a literal is data; only
/// what survives this strip can actually execute.
String _stripLiterals(String sql) {
  final out = StringBuffer();
  var i = 0;
  while (i < sql.length) {
    if (sql[i] != "'") {
      out.write(sql[i]);
      i++;
      continue;
    }
    i++; // opening quote
    while (i < sql.length) {
      if (sql[i] == "'") {
        if (i + 1 < sql.length && sql[i + 1] == "'") {
          i += 2; // escaped quote, still inside
          continue;
        }
        i++; // closing quote
        break;
      }
      i++;
    }
  }
  return out.toString();
}

/// The DML a staged grid edit turns into. Values are inlined (the user reviews
/// the literal SQL before it runs), so the encoders here are the security
/// boundary — hence the injection cases.
void main() {
  const pg = DmlBuilder(SqlDialect.postgres);
  const mysql = DmlBuilder(SqlDialect.mysql);
  const sqlite = DmlBuilder(SqlDialect.sqlite);

  const t = EditableTarget(table: 'customers');
  const qualified = EditableTarget(table: 'orders', schema: 'public');
  const id = RowIdentity({'id': 7});

  ColumnEditor ed(ColumnEditorKind k) =>
      ColumnEditor(kind: k, nullable: true);

  group('UPDATE', () {
    test('single column, PK-qualified', () {
      expect(
        pg.update(t, [CellEdit('name', 'Ada', ed(ColumnEditorKind.text))], id),
        '''UPDATE "customers" SET "name" = 'Ada' WHERE "id" = 7;''',
      );
    });

    test('multiple columns keep their staged order', () {
      expect(
        pg.update(t, [
          CellEdit('name', 'Ada', ed(ColumnEditorKind.text)),
          CellEdit('total', 12.5, ed(ColumnEditorKind.decimal)),
        ], id),
        '''UPDATE "customers" SET "name" = 'Ada', "total" = 12.5 WHERE "id" = 7;''',
      );
    });

    test('schema-qualified target', () {
      expect(
        pg.update(qualified, [CellEdit('n', 1, ed(ColumnEditorKind.integer))],
            id),
        'UPDATE "public"."orders" SET "n" = 1 WHERE "id" = 7;',
      );
    });

    test('composite primary key ANDs every column', () {
      expect(
        pg.update(t, [CellEdit('v', 1, ed(ColumnEditorKind.integer))],
            const RowIdentity({'a': 1, 'b': 'x'})),
        '''UPDATE "customers" SET "v" = 1 WHERE "a" = 1 AND "b" = 'x';''',
      );
    });

    test('nothing staged → no statement', () {
      expect(pg.update(t, const [], id), isNull);
    });

    test('refuses to build without a primary key', () {
      // An unqualified UPDATE would rewrite the whole table.
      expect(
        () => pg.update(t, [CellEdit('n', 1, ed(ColumnEditorKind.integer))],
            const RowIdentity({})),
        throwsArgumentError,
      );
    });
  });

  group('INSERT', () {
    test('only the columns the user filled in', () {
      // Omitted columns keep engine defaults / sequences.
      expect(
        pg.insert(t, [
          CellEdit('name', 'Grace', ed(ColumnEditorKind.text)),
          CellEdit('total', 0, ed(ColumnEditorKind.decimal)),
        ]),
        '''INSERT INTO "customers" ("name", "total") VALUES ('Grace', 0);''',
      );
    });

    test('empty row stages nothing', () {
      expect(pg.insert(t, const []), isNull);
    });
  });

  group('DELETE', () {
    test('PK-qualified', () {
      expect(pg.delete(t, id), 'DELETE FROM "customers" WHERE "id" = 7;');
    });

    test('refuses without a primary key', () {
      expect(() => pg.delete(t, const RowIdentity({})), throwsArgumentError);
    });
  });

  group('identifier quoting per dialect', () {
    test('mysql uses backticks, others double quotes', () {
      expect(
        mysql.update(t, [CellEdit('n', 1, ed(ColumnEditorKind.integer))], id),
        'UPDATE `customers` SET `n` = 1 WHERE `id` = 7;',
      );
      expect(
        sqlite.update(t, [CellEdit('n', 1, ed(ColumnEditorKind.integer))], id),
        'UPDATE "customers" SET "n" = 1 WHERE "id" = 7;',
      );
    });

    test('embedded quote chars in identifiers are escaped', () {
      expect(
        pg.update(const EditableTarget(table: 'we"ird'),
            [CellEdit('c"c', 1, ed(ColumnEditorKind.integer))], id),
        'UPDATE "we""ird" SET "c""c" = 1 WHERE "id" = 7;',
      );
      expect(
        mysql.update(const EditableTarget(table: 'back`tick'),
            [CellEdit('n', 1, ed(ColumnEditorKind.integer))], id),
        'UPDATE `back``tick` SET `n` = 1 WHERE `id` = 7;',
      );
    });
  });

  group('value encoding', () {
    test('NULL is a keyword, not the string "null"', () {
      expect(
        pg.update(t, [CellEdit('name', null, ed(ColumnEditorKind.text))], id),
        'UPDATE "customers" SET "name" = NULL WHERE "id" = 7;',
      );
    });

    test('empty string stays a string — distinct from NULL', () {
      expect(
        pg.update(t, [CellEdit('name', '', ed(ColumnEditorKind.text))], id),
        '''UPDATE "customers" SET "name" = '' WHERE "id" = 7;''',
      );
    });

    test('booleans: TRUE/FALSE on postgres, 1/0 elsewhere', () {
      String upd(DmlBuilder b, Object? v) =>
          b.update(t, [CellEdit('ok', v, ed(ColumnEditorKind.boolean))], id)!;
      expect(upd(pg, true), contains('"ok" = TRUE'));
      expect(upd(pg, false), contains('"ok" = FALSE'));
      expect(upd(mysql, true), contains('`ok` = 1'));
      expect(upd(sqlite, false), contains('"ok" = 0'));
      // Text coming back from a toggle widget still resolves.
      expect(upd(pg, 'true'), contains('"ok" = TRUE'));
      expect(upd(pg, 't'), contains('"ok" = TRUE'));
      expect(upd(pg, 0), contains('"ok" = FALSE'));
    });

    test('numbers are emitted bare', () {
      expect(
        pg.update(t, [CellEdit('n', 42, ed(ColumnEditorKind.integer))], id),
        contains('"n" = 42'),
      );
      expect(
        pg.update(t, [CellEdit('n', '42', ed(ColumnEditorKind.integer))], id),
        contains('"n" = 42'),
      );
      expect(
        pg.update(t, [CellEdit('d', '-3.5', ed(ColumnEditorKind.decimal))], id),
        contains('"d" = -3.5'),
      );
    });

    test('a non-numeric value in a number column is quoted, never inlined', () {
      // The unquoted path must not become an injection vector.
      final sql = pg.update(
        t,
        [CellEdit('n', '1; DROP TABLE users', ed(ColumnEditorKind.integer))],
        id,
      )!;
      expect(sql, contains("""'1; DROP TABLE users'"""));
      expect(sql, isNot(contains('= 1; DROP')));
    });

    test('dates and json travel as quoted strings', () {
      expect(
        pg.update(t, [
          CellEdit('at', '2026-08-01 14:30:00+00', ed(ColumnEditorKind.dateTime))
        ], id),
        contains("""'2026-08-01 14:30:00+00'"""),
      );
      expect(
        pg.update(
            t, [CellEdit('doc', '{"a": 1}', ed(ColumnEditorKind.json))], id),
        contains("""'{"a": 1}'"""),
      );
    });
  });

  group('string escaping is the security boundary', () {
    test("single quotes are doubled", () {
      expect(
        pg.update(
            t, [CellEdit('name', "O'Brien", ed(ColumnEditorKind.text))], id),
        '''UPDATE "customers" SET "name" = 'O''Brien' WHERE "id" = 7;''',
      );
    });

    test('a quote-and-statement payload cannot break out', () {
      final sql = pg.update(
        t,
        [CellEdit('name', "x'; DROP TABLE users; --", ed(ColumnEditorKind.text))],
        id,
      )!;
      expect(sql, contains("'x''; DROP TABLE users; --'"));
      // The payload's semicolons are *inside* the literal, so they're data.
      // What must hold is that none escape it: exactly one terminator outside
      // quotes — the one we appended.
      expect(';'.allMatches(_stripLiterals(sql)).length, 1);
      expect(_stripLiterals(sql).toUpperCase(), isNot(contains('DROP')));
    });

    test('mysql additionally escapes backslashes', () {
      // MySQL treats \\ as an escape by default, so \\' would re-open the string.
      expect(
        mysql.update(
            t, [CellEdit('p', r"C:\path\'", ed(ColumnEditorKind.text))], id),
        contains(r"'C:\\path\\'''"),
      );
      // Postgres standard_conforming_strings leaves backslashes literal.
      expect(
        pg.update(t, [CellEdit('p', r'C:\path', ed(ColumnEditorKind.text))], id),
        contains(r"'C:\path'"),
      );
    });

    test('PK values are escaped too', () {
      expect(
        pg.delete(t, const RowIdentity({'code': "a'b"})),
        '''DELETE FROM "customers" WHERE "code" = 'a''b';''',
      );
    });

    test('a NULL primary key uses IS NULL, not = NULL', () {
      expect(
        pg.delete(t, const RowIdentity({'a': 1, 'b': null})),
        'DELETE FROM "customers" WHERE "a" = 1 AND "b" IS NULL;',
      );
    });
  });
}
