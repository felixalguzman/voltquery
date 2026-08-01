import 'package:flutter_test/flutter_test.dart';
import 'package:voltquery/data/drivers/mysql/mysql_driver.dart';

/// MySQL reports an enum's permitted values only inside `column_type`
/// ("enum('a','b')") — parsing it is what lets the grid offer a validating
/// dropdown instead of free text.
void main() {
  test('parses a simple enum', () {
    expect(parseMysqlEnumOptions("enum('small','medium','large')"),
        ['small', 'medium', 'large']);
  });

  test('parses a set the same way', () {
    expect(parseMysqlEnumOptions("set('read','write')"), ['read', 'write']);
  });

  test('handles escaped quotes inside a label', () {
    // MySQL escapes by doubling.
    expect(parseMysqlEnumOptions("enum('it''s','ok')"), ["it's", 'ok']);
  });

  test('handles commas and spaces inside labels', () {
    expect(parseMysqlEnumOptions("enum('a, b','c')"), ['a, b', 'c']);
    expect(parseMysqlEnumOptions("enum('one', 'two')"), ['one', 'two']);
  });

  test('an empty-string member is preserved', () {
    expect(parseMysqlEnumOptions("enum('','x')"), ['', 'x']);
  });

  test('case of the type keyword is irrelevant', () {
    expect(parseMysqlEnumOptions("ENUM('a')"), ['a']);
  });

  test('non-enum column types yield nothing', () {
    expect(parseMysqlEnumOptions('varchar(255)'), isEmpty);
    expect(parseMysqlEnumOptions('int unsigned'), isEmpty);
    expect(parseMysqlEnumOptions('tinyint(1)'), isEmpty);
    expect(parseMysqlEnumOptions(null), isEmpty);
    expect(parseMysqlEnumOptions(''), isEmpty);
  });

  test('malformed input never throws', () {
    expect(parseMysqlEnumOptions('enum('), isEmpty);
    expect(parseMysqlEnumOptions('enum()'), isEmpty);
    expect(parseMysqlEnumOptions("enum('unterminated"), isEmpty);
  });
}
