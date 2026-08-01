import 'package:flutter_test/flutter_test.dart';
import 'package:voltquery/data/drivers/sqlite/sqlite_driver.dart';

/// SQLite has no ENUM type — `CHECK (col IN (...))` is the idiom. Reading those
/// value lists out of the stored DDL is what lets the grid offer the same
/// validating dropdown it gives a Postgres enum or a MySQL `enum(...)`.
void main() {
  test('extracts a simple check-enum', () {
    expect(
      parseSqliteCheckEnums(
        "CREATE TABLE orders (status TEXT "
        "CHECK (status IN ('pending','shipped','cancelled')))",
      ),
      {
        'status': ['pending', 'shipped', 'cancelled'],
      },
    );
  });

  test('tolerates spacing and case variations', () {
    expect(
      parseSqliteCheckEnums("CREATE TABLE t (a TEXT check(a in( 'x' , 'y' )))"),
      {
        'a': ['x', 'y'],
      },
    );
  });

  test('handles quoted and bracketed column names', () {
    expect(
      parseSqliteCheckEnums(
          'CREATE TABLE t ("odd name" TEXT CHECK ("odd name" IN (\'a\')))'),
      {
        'odd name': ['a'],
      },
    );
    expect(
      parseSqliteCheckEnums(
          "CREATE TABLE t (`b` TEXT CHECK (`b` IN ('a')))"),
      {
        'b': ['a'],
      },
    );
  });

  test('escaped quotes inside a value are unescaped', () {
    expect(
      parseSqliteCheckEnums("CREATE TABLE t (a TEXT CHECK (a IN ('it''s')))"),
      {
        'a': ["it's"],
      },
    );
  });

  test('several constrained columns in one table', () {
    final out = parseSqliteCheckEnums(
      "CREATE TABLE t ("
      "a TEXT CHECK (a IN ('x','y')), "
      "b TEXT, "
      "c TEXT CHECK (c IN ('1')))",
    );
    expect(out.keys, ['a', 'c']);
    expect(out['a'], ['x', 'y']);
  });

  test('constraints that are not value lists are ignored', () {
    // A dropdown built from a misread constraint would silently omit legal
    // values, so anything that is not a plain IN-list is left alone.
    expect(parseSqliteCheckEnums('CREATE TABLE t (n INT CHECK (n > 0))'),
        isEmpty);
    expect(
      parseSqliteCheckEnums(
          'CREATE TABLE t (n INT CHECK (n BETWEEN 1 AND 5))'),
      isEmpty,
    );
  });

  test('a table with no CHECK yields nothing, and never throws', () {
    expect(parseSqliteCheckEnums('CREATE TABLE t (a TEXT)'), isEmpty);
    expect(parseSqliteCheckEnums(''), isEmpty);
    expect(parseSqliteCheckEnums('not sql at all'), isEmpty);
  });
}
