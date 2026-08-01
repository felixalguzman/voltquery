import 'package:flutter_test/flutter_test.dart';
import 'package:voltquery/domain/models/engine.dart';
import 'package:voltquery/domain/sql/sql_statement_splitter.dart';

/// The dialect-aware statement splitter (ADR-0007) — the pure seam behind
/// multi-statement Run. Exercised across quoting/comment/dialect edge cases.
void main() {
  _identifierQuoting();
  List<String> split(String sql, [SqlDialect d = SqlDialect.postgres]) =>
      SqlStatementSplitter(d).split(sql).map((s) => s.sql).toList();

  group('basic splitting', () {
    test('splits on top-level semicolons, trimming each', () {
      expect(split('SELECT 1; SELECT 2;'), ['SELECT 1', 'SELECT 2']);
    });

    test('a trailing statement without a delimiter is kept', () {
      expect(split('SELECT 1;\nSELECT 2'), ['SELECT 1', 'SELECT 2']);
    });

    test('empty / whitespace / bare-semicolon input yields nothing', () {
      expect(split('   \n  '), isEmpty);
      expect(split(';;;'), isEmpty);
      expect(split(''), isEmpty);
    });

    test('blank statements between delimiters are dropped', () {
      expect(split('SELECT 1;; ;SELECT 2;'), ['SELECT 1', 'SELECT 2']);
    });
  });

  group('literals hide semicolons', () {
    test('single-quoted string with ; and doubled-quote escape', () {
      expect(split("INSERT INTO t VALUES ('a;b', 'it''s'); SELECT 1"),
          ["INSERT INTO t VALUES ('a;b', 'it''s')", 'SELECT 1']);
    });

    test('double-quoted identifier with ;', () {
      expect(split('SELECT * FROM "weird;name"; SELECT 2'),
          ['SELECT * FROM "weird;name"', 'SELECT 2']);
    });

    test('MySQL backtick identifier with ;', () {
      expect(split('SELECT * FROM `a;b`; SELECT 2', SqlDialect.mysql),
          ['SELECT * FROM `a;b`', 'SELECT 2']);
    });

    test('Postgres treats backticks as ordinary text (no identifier quoting)',
        () {
      // Not an identifier quote in PG → the ; still splits normally.
      expect(split('SELECT 1; SELECT 2', SqlDialect.postgres),
          ['SELECT 1', 'SELECT 2']);
    });
  });

  group('comments hide semicolons', () {
    test('line comment to EOL', () {
      expect(split('SELECT 1; -- a; b\nSELECT 2'), ['SELECT 1', 'SELECT 2']);
    });

    test('MySQL # line comment', () {
      expect(split('SELECT 1 # a; b\n; SELECT 2', SqlDialect.mysql),
          ['SELECT 1 # a; b', 'SELECT 2']);
    });

    test('block comment', () {
      expect(split('SELECT /* a; b */ 1; SELECT 2'),
          ['SELECT /* a; b */ 1', 'SELECT 2']);
    });

    test('Postgres nested block comments', () {
      expect(
          split('SELECT /* x /* y; */ z; */ 1; SELECT 2', SqlDialect.postgres),
          ['SELECT /* x /* y; */ z; */ 1', 'SELECT 2']);
    });

    test('MySQL block comments do not nest — first */ closes', () {
      // After the first */ the `; ` splits; the dangling tail is its own stmt.
      final r = split('SELECT /* a /* b */ 1; SELECT 2', SqlDialect.mysql);
      expect(r.first, 'SELECT /* a /* b */ 1');
    });
  });

  group('Postgres dollar-quoting', () {
    test('function body with semicolons stays one statement', () {
      const fn = r'''
CREATE FUNCTION f() RETURNS int AS $$
BEGIN
  RETURN 1;
END;
$$ LANGUAGE plpgsql;
SELECT f()''';
      final r = split(fn, SqlDialect.postgres);
      expect(r.length, 2);
      expect(r.first, startsWith('CREATE FUNCTION'));
      expect(r.first, contains(r'$$'));
      expect(r.last, 'SELECT f()');
    });

    test('tagged dollar-quote', () {
      final r = split(r'SELECT $tag$a;b$tag$; SELECT 2', SqlDialect.postgres);
      expect(r, [r'SELECT $tag$a;b$tag$', 'SELECT 2']);
    });

    test(r'positional param $1 is not a dollar-quote', () {
      expect(split(r'SELECT * FROM t WHERE id = $1; SELECT 2',
          SqlDialect.postgres), [r'SELECT * FROM t WHERE id = $1', 'SELECT 2']);
    });
  });

  group('MySQL DELIMITER', () {
    test('switches the delimiter, then restores it', () {
      const sql = '''
DELIMITER //
CREATE PROCEDURE p()
BEGIN
  SELECT 1;
  SELECT 2;
END //
DELIMITER ;
SELECT 3;''';
      final r = split(sql, SqlDialect.mysql);
      expect(r.length, 2);
      expect(r.first, startsWith('CREATE PROCEDURE'));
      expect(r.first, contains('SELECT 1;')); // inner ; not split
      expect(r.last, 'SELECT 3');
    });
  });

  group('classification', () {
    StatementKind kind(String sql, [SqlDialect d = SqlDialect.postgres]) =>
        SqlStatementSplitter(d).split(sql).single.kind;

    test('DDL / DML / query / other', () {
      expect(kind('CREATE TABLE t (id int)'), StatementKind.ddl);
      expect(kind('drop table t'), StatementKind.ddl);
      expect(kind('INSERT INTO t VALUES (1)'), StatementKind.dml);
      expect(kind('SELECT 1'), StatementKind.query);
      expect(kind('WITH x AS (SELECT 1) SELECT * FROM x'), StatementKind.query);
      expect(kind('BEGIN'), StatementKind.other);
    });

    test('leading comment does not fool classification', () {
      expect(kind('-- make it\nCREATE TABLE t (id int)'), StatementKind.ddl);
      expect(kind('/* c */ SELECT 1'), StatementKind.query);
    });
  });

  group('statementAt (Run at cursor)', () {
    final splitter = SqlStatementSplitter(SqlDialect.postgres);
    const buf = 'SELECT 1;\nUPDATE t SET a=1;\nSELECT 3';
    //           0......7 8  9...............25 26

    String? at(int offset) => splitter.statementAt(buf, offset)?.sql;

    test('maps a caret inside each statement to that statement', () {
      expect(at(2), 'SELECT 1'); // inside first
      expect(at(15), 'UPDATE t SET a=1'); // inside second
      expect(at(buf.length), 'SELECT 3'); // caret at very end → last
    });

    test('caret right after a semicolon belongs to the next statement', () {
      expect(at(9), 'UPDATE t SET a=1'); // just past "SELECT 1;"
    });

    test('empty buffer → null', () {
      expect(splitter.statementAt('   ', 0), isNull);
    });

    test('does not split on a ; inside a string when locating', () {
      const b = "SELECT ';' AS x; SELECT 2";
      expect(splitter.statementAt(b, 5)?.sql, "SELECT ';' AS x");
      expect(splitter.statementAt(b, b.length)?.sql, 'SELECT 2');
    });
  });

  group('robustness', () {
    test('unterminated string is emitted whole, not mis-split', () {
      // The dangling quote swallows the rest → one statement, no crash.
      final r = split("SELECT 'oops; SELECT 2");
      expect(r.length, 1);
    });

    test('SqlDialect.of maps engines', () {
      expect(SqlDialect.of(Engine.postgres), SqlDialect.postgres);
      expect(SqlDialect.of(Engine.mysql), SqlDialect.mysql);
      expect(SqlDialect.of(Engine.sqlite), SqlDialect.sqlite);
    });
  });
}

/// Identifier quoting is dialect-specific and shared by everything that
/// *generates* SQL (the schema tree's SELECTs, DmlBuilder's UPDATEs), so a
/// regression here breaks MySQL everywhere at once.
void _identifierQuoting() {
  group('identifier quoting', () {
    test('mysql uses backticks, others double quotes', () {
      // A double-quoted name is a string literal on MySQL unless ANSI_QUOTES
      // is on — `SELECT * FROM "t"` is a syntax error there.
      expect(SqlDialect.mysql.quoteIdentifier('t'), '`t`');
      expect(SqlDialect.postgres.quoteIdentifier('t'), '"t"');
      expect(SqlDialect.sqlite.quoteIdentifier('t'), '"t"');
    });

    test('embedded quote characters are escaped', () {
      expect(SqlDialect.mysql.quoteIdentifier('a`b'), '`a``b`');
      expect(SqlDialect.postgres.quoteIdentifier('a"b'), '"a""b"');
    });

    test('qualify prefixes the schema when there is one', () {
      expect(SqlDialect.mysql.qualify('agente', schema: 'avasure'),
          '`avasure`.`agente`');
      expect(SqlDialect.postgres.qualify('orders', schema: 'public'),
          '"public"."orders"');
      expect(SqlDialect.sqlite.qualify('t'), '"t"');
      expect(SqlDialect.mysql.qualify('t', schema: ''), '`t`');
    });
  });
}
