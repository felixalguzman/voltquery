import 'package:flutter_test/flutter_test.dart';
import 'package:voltquery/domain/models/column_editor.dart';
import 'package:voltquery/domain/models/engine.dart';

/// Engine type -> editor mapping. Renderer-agnostic on purpose: this says
/// "wants a date picker", never which widget draws it, so the grid layer can
/// swap pluto_grid's editors for custom/fluent ones without touching this.
void main() {
  const pg = ColumnEditorResolver(Engine.postgres);
  const mysql = ColumnEditorResolver(Engine.mysql);
  const sqlite = ColumnEditorResolver(Engine.sqlite);

  ColumnEditorKind kindOf(ColumnEditorResolver r, String type) =>
      r.resolve(type, nullable: true).kind;

  group('postgres', () {
    test('information_schema spellings map correctly', () {
      expect(kindOf(pg, 'integer'), ColumnEditorKind.integer);
      expect(kindOf(pg, 'bigint'), ColumnEditorKind.integer);
      expect(kindOf(pg, 'smallint'), ColumnEditorKind.integer);
      expect(kindOf(pg, 'numeric'), ColumnEditorKind.decimal);
      expect(kindOf(pg, 'double precision'), ColumnEditorKind.decimal);
      expect(kindOf(pg, 'real'), ColumnEditorKind.decimal);
      expect(kindOf(pg, 'boolean'), ColumnEditorKind.boolean);
      expect(kindOf(pg, 'date'), ColumnEditorKind.date);
      expect(kindOf(pg, 'timestamp with time zone'),
          ColumnEditorKind.dateTime);
      expect(kindOf(pg, 'timestamp without time zone'),
          ColumnEditorKind.dateTime);
      expect(kindOf(pg, 'time without time zone'), ColumnEditorKind.time);
      expect(kindOf(pg, 'jsonb'), ColumnEditorKind.json);
      expect(kindOf(pg, 'json'), ColumnEditorKind.json);
      expect(kindOf(pg, 'bytea'), ColumnEditorKind.binary);
      expect(kindOf(pg, 'character varying'), ColumnEditorKind.text);
      expect(kindOf(pg, 'text'), ColumnEditorKind.text);
      expect(kindOf(pg, 'uuid'), ColumnEditorKind.text);
    });

    test('precision suffixes are stripped', () {
      expect(kindOf(pg, 'numeric(10,2)'), ColumnEditorKind.decimal);
      expect(kindOf(pg, 'character varying(255)'), ColumnEditorKind.text);
    });
  });

  group('mysql', () {
    test('bare data_type names map correctly', () {
      expect(kindOf(mysql, 'int'), ColumnEditorKind.integer);
      expect(kindOf(mysql, 'bigint'), ColumnEditorKind.integer);
      expect(kindOf(mysql, 'mediumint'), ColumnEditorKind.integer);
      expect(kindOf(mysql, 'decimal'), ColumnEditorKind.decimal);
      expect(kindOf(mysql, 'double'), ColumnEditorKind.decimal);
      expect(kindOf(mysql, 'datetime'), ColumnEditorKind.dateTime);
      expect(kindOf(mysql, 'timestamp'), ColumnEditorKind.dateTime);
      expect(kindOf(mysql, 'date'), ColumnEditorKind.date);
      expect(kindOf(mysql, 'time'), ColumnEditorKind.time);
      expect(kindOf(mysql, 'json'), ColumnEditorKind.json);
      expect(kindOf(mysql, 'blob'), ColumnEditorKind.binary);
      expect(kindOf(mysql, 'longblob'), ColumnEditorKind.binary);
      expect(kindOf(mysql, 'varchar'), ColumnEditorKind.text);
    });

    test('tinyint(1) is a toggle but a plain tinyint is a number', () {
      // MySQL has no real BOOL — tinyint(1) is the idiom. Width matters.
      expect(kindOf(mysql, 'tinyint(1)'), ColumnEditorKind.boolean);
      expect(kindOf(mysql, 'tinyint'), ColumnEditorKind.integer);
      expect(kindOf(mysql, 'tinyint(4)'), ColumnEditorKind.integer);
    });

    test('unsigned variants stay numeric', () {
      expect(kindOf(mysql, 'int unsigned'), ColumnEditorKind.integer);
      expect(kindOf(mysql, 'bigint unsigned'), ColumnEditorKind.integer);
    });
  });

  group('sqlite (declared affinity, dynamically typed)', () {
    test('declared types map, unknown falls back to text', () {
      expect(kindOf(sqlite, 'INTEGER'), ColumnEditorKind.integer);
      expect(kindOf(sqlite, 'REAL'), ColumnEditorKind.decimal);
      expect(kindOf(sqlite, 'TEXT'), ColumnEditorKind.text);
      expect(kindOf(sqlite, 'BLOB'), ColumnEditorKind.binary);
      expect(kindOf(sqlite, 'BOOLEAN'), ColumnEditorKind.boolean);
      expect(kindOf(sqlite, 'VARCHAR(50)'), ColumnEditorKind.text);
      expect(kindOf(sqlite, 'DATETIME'), ColumnEditorKind.dateTime);
      // A column with no declared type at all — SQLite allows this.
      expect(kindOf(sqlite, ''), ColumnEditorKind.text);
    });

    test('a bare tinyint is NOT a bool outside MySQL', () {
      expect(kindOf(sqlite, 'tinyint(1)'), ColumnEditorKind.integer);
    });
  });

  group('enums and nullability', () {
    test('an explicit option list wins over the type name', () {
      final e = mysql.resolve('enum',
          nullable: false, enumOptions: ['small', 'large']);
      expect(e.kind, ColumnEditorKind.enumeration);
      expect(e.options, ['small', 'large']);
      expect(e.nullable, isFalse);
    });

    test('postgres USER-DEFINED with options resolves to a dropdown', () {
      final e =
          pg.resolve('USER-DEFINED', nullable: true, enumOptions: ['a', 'b']);
      expect(e.kind, ColumnEditorKind.enumeration);
      expect(e.options, ['a', 'b']);
    });

    test('USER-DEFINED without options degrades to text, not a crash', () {
      expect(kindOf(pg, 'USER-DEFINED'), ColumnEditorKind.text);
    });

    test('nullability is carried through for the set-NULL affordance', () {
      expect(pg.resolve('text', nullable: true).nullable, isTrue);
      expect(pg.resolve('text', nullable: false).nullable, isFalse);
    });
  });

  test('binary columns are read-only inline', () {
    expect(pg.resolve('bytea', nullable: true).isReadOnly, isTrue);
    expect(pg.resolve('text', nullable: true).isReadOnly, isFalse);
  });

  group('validation', () {
    ColumnEditor ed(ColumnEditorKind k,
            {bool nullable = true, List<String> options = const []}) =>
        ColumnEditor(kind: k, nullable: nullable, options: options);

    test('NOT NULL is enforced, nullable accepts null', () {
      expect(ed(ColumnEditorKind.text, nullable: false).validate(null),
          isNotNull);
      expect(ed(ColumnEditorKind.text).validate(null), isNull);
    });

    test('numbers reject non-numeric input', () {
      expect(ed(ColumnEditorKind.integer).validate('42'), isNull);
      expect(ed(ColumnEditorKind.integer).validate('abc'), isNotNull);
      expect(ed(ColumnEditorKind.integer).validate('4.5'), isNotNull);
      expect(ed(ColumnEditorKind.decimal).validate('4.5'), isNull);
      expect(ed(ColumnEditorKind.decimal).validate('-3'), isNull);
      expect(ed(ColumnEditorKind.decimal).validate('1; DROP TABLE t'),
          isNotNull);
    });

    test('booleans accept the spellings engines use', () {
      for (final v in ['true', 'false', 't', 'f', '0', '1', 'YES']) {
        expect(ed(ColumnEditorKind.boolean).validate(v), isNull, reason: v);
      }
      expect(ed(ColumnEditorKind.boolean).validate('maybe'), isNotNull);
    });

    test('dates must parse', () {
      expect(ed(ColumnEditorKind.date).validate('2026-08-01'), isNull);
      expect(
          ed(ColumnEditorKind.dateTime).validate('2026-08-01 14:30:00'), isNull);
      expect(ed(ColumnEditorKind.date).validate('01/08/2026'), isNotNull);
      expect(ed(ColumnEditorKind.date).validate('not a date'), isNotNull);
    });

    test('enums are restricted to their options', () {
      final e = ed(ColumnEditorKind.enumeration, options: ['a', 'b']);
      expect(e.validate('a'), isNull);
      expect(e.validate('c'), isNotNull);
      // With no known options we can't judge — let the engine decide.
      expect(ed(ColumnEditorKind.enumeration).validate('anything'), isNull);
    });

    test('json is structurally checked, not fully parsed', () {
      expect(ed(ColumnEditorKind.json).validate('{"a": 1}'), isNull);
      expect(ed(ColumnEditorKind.json).validate('[1, 2]'), isNull);
      expect(ed(ColumnEditorKind.json).validate('"str"'), isNull);
      expect(ed(ColumnEditorKind.json).validate('42'), isNull);
      expect(ed(ColumnEditorKind.json).validate('{"a": 1'), isNotNull);
      expect(ed(ColumnEditorKind.json).validate('nonsense'), isNotNull);
      // A brace inside a string must not be counted as structure.
      expect(ed(ColumnEditorKind.json).validate('{"a": "}"}'), isNull);
    });

    test('text defers to the engine', () {
      expect(ed(ColumnEditorKind.text).validate('anything at all'), isNull);
    });
  });

  test('case and padding are irrelevant', () {
    expect(kindOf(pg, '  BOOLEAN  '), ColumnEditorKind.boolean);
    expect(kindOf(mysql, 'DateTime'), ColumnEditorKind.dateTime);
  });
}
