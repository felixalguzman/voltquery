import 'package:flutter_test/flutter_test.dart';
import 'package:voltquery/domain/sql/editable_result.dart';
import 'package:voltquery/domain/sql/sql_statement_splitter.dart';

/// The grid write-path's safety gate: a result is editable only when every row
/// maps 1:1 to a row of one real table. False negatives just cost the user a
/// hand-written UPDATE; a false positive writes to the wrong row — so these
/// tests lean hard on the reject cases.
void main() {
  const pg = EditableResultAnalyzer(SqlDialect.postgres);
  const mysql = EditableResultAnalyzer(SqlDialect.mysql);
  const sqlite = EditableResultAnalyzer(SqlDialect.sqlite);

  group('accepts plain single-table selects', () {
    test('SELECT * FROM t', () {
      expect(pg.analyze('SELECT * FROM customers'),
          const EditableTarget(table: 'customers'));
    });

    test('trailing clauses do not disqualify', () {
      expect(
        pg.analyze('SELECT id, name FROM customers WHERE total > 10 '
            'ORDER BY name LIMIT 200'),
        const EditableTarget(table: 'customers'),
      );
    });

    test('schema-qualified', () {
      expect(pg.analyze('SELECT * FROM public.orders'),
          const EditableTarget(table: 'orders', schema: 'public'));
    });

    test('quoted identifiers are unquoted', () {
      expect(pg.analyze('SELECT * FROM "Odd Name"'),
          const EditableTarget(table: 'Odd Name'));
      expect(pg.analyze('SELECT * FROM "s"."t"'),
          const EditableTarget(table: 't', schema: 's'));
      expect(mysql.analyze('SELECT * FROM `back ticked`'),
          const EditableTarget(table: 'back ticked'));
    });

    test('escaped quotes inside an identifier', () {
      expect(pg.analyze('SELECT * FROM "we""ird"'),
          const EditableTarget(table: 'we"ird'));
    });

    test('an alias is fine — DML targets the real table', () {
      expect(pg.analyze('SELECT c.id FROM customers c'),
          const EditableTarget(table: 'customers'));
      expect(pg.analyze('SELECT c.id FROM customers AS c'),
          const EditableTarget(table: 'customers'));
    });

    test('case and whitespace are irrelevant', () {
      expect(sqlite.analyze('  select\n  *\n  from\n  t  '),
          const EditableTarget(table: 't'));
      expect(pg.analyze('SeLeCt * FrOm t'), const EditableTarget(table: 't'));
    });

    test('a scalar subquery in the projection is still editable', () {
      expect(
        pg.analyze('SELECT id, (SELECT count(*) FROM orders) FROM customers'),
        const EditableTarget(table: 'customers'),
      );
    });

    test('comments are ignored', () {
      expect(pg.analyze('SELECT * -- pick everything\nFROM customers'),
          const EditableTarget(table: 'customers'));
      expect(pg.analyze('/* lead */ SELECT * FROM customers'),
          const EditableTarget(table: 'customers'));
      expect(mysql.analyze('SELECT * # trailing\nFROM customers'),
          const EditableTarget(table: 'customers'));
    });

    test('a trailing semicolon is harmless', () {
      expect(pg.analyze('SELECT * FROM customers;'),
          const EditableTarget(table: 'customers'));
    });
  });

  group('rejects anything that breaks the 1:1 row mapping', () {
    test('joins', () {
      expect(pg.analyze('SELECT * FROM a JOIN b ON a.id = b.a_id'), isNull);
      expect(pg.analyze('SELECT * FROM a LEFT JOIN b ON a.id = b.a_id'), isNull);
      expect(pg.analyze('SELECT * FROM a CROSS JOIN b'), isNull);
    });

    test('old-style comma joins', () {
      expect(pg.analyze('SELECT * FROM a, b WHERE a.id = b.a_id'), isNull);
    });

    test('aggregates and grouping', () {
      expect(pg.analyze('SELECT c, count(*) FROM t GROUP BY c'), isNull);
      expect(pg.analyze('SELECT c FROM t GROUP BY c HAVING count(*) > 1'),
          isNull);
      expect(pg.analyze('SELECT DISTINCT c FROM t'), isNull);
    });

    test('a bare aggregate with no GROUP BY still collapses the result', () {
      // Regression: these have no disqualifying *clause*, but the single row
      // they return corresponds to no row of the table.
      expect(pg.analyze('SELECT count(*) FROM t'), isNull);
      expect(pg.analyze('SELECT count(*) AS n FROM customers'), isNull);
      expect(pg.analyze('SELECT sum(total), avg(total) FROM orders'), isNull);
      expect(pg.analyze('SELECT max(id) FROM t WHERE a = 1'), isNull);
      expect(sqlite.analyze('SELECT total(x) FROM t'), isNull);
    });

    test('a column merely NAMED like an aggregate is fine', () {
      // `count` as an identifier, not a call.
      expect(pg.analyze('SELECT count FROM t'), const EditableTarget(table: 't'));
      expect(pg.analyze('SELECT "max", min FROM t'),
          const EditableTarget(table: 't'));
    });

    test('set operations', () {
      expect(pg.analyze('SELECT * FROM a UNION SELECT * FROM b'), isNull);
      expect(pg.analyze('SELECT * FROM a INTERSECT SELECT * FROM b'), isNull);
      expect(pg.analyze('SELECT * FROM a EXCEPT SELECT * FROM b'), isNull);
    });

    test('derived tables and CTEs', () {
      expect(pg.analyze('SELECT * FROM (SELECT * FROM t) x'), isNull);
      expect(pg.analyze('WITH x AS (SELECT 1) SELECT * FROM x'), isNull);
    });

    test('no FROM at all', () {
      expect(pg.analyze('SELECT 1'), isNull);
      expect(pg.analyze("SELECT now(), 'hi'"), isNull);
    });

    test('non-SELECT statements', () {
      expect(pg.analyze('UPDATE t SET a = 1'), isNull);
      expect(pg.analyze('INSERT INTO t VALUES (1)'), isNull);
      expect(pg.analyze('DELETE FROM t'), isNull);
      expect(pg.analyze('CREATE TABLE t (id int)'), isNull);
    });

    test('a table-valued function is not a table', () {
      expect(pg.analyze('SELECT * FROM generate_series(1, 10)'), isNull);
    });

    test('more qualifiers than schema.table', () {
      expect(pg.analyze('SELECT * FROM db.schema.tbl'), isNull);
    });

    test('empty / garbage input never throws', () {
      expect(pg.analyze(''), isNull);
      expect(pg.analyze('   '), isNull);
      expect(pg.analyze('!!!'), isNull);
      expect(pg.analyze('SELECT * FROM'), isNull);
    });

    test('a disqualifying keyword inside a string literal is not seen', () {
      // 'join' here is data, not a clause — the statement is still editable.
      expect(pg.analyze("SELECT * FROM t WHERE note = 'join us'"),
          const EditableTarget(table: 't'));
    });

    test('a keyword as a quoted identifier is not a clause', () {
      expect(pg.analyze('SELECT "union" FROM t'),
          const EditableTarget(table: 't'));
    });
  });
}
