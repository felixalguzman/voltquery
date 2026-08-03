import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voltquery/domain/drivers/result.dart';
import 'package:voltquery/domain/export/result_export.dart';
import 'package:voltquery/domain/sql/sql_statement_splitter.dart';

/// Serializing a result set. The formats differ only in how they escape, so
/// that is what these are about: a value that changes meaning on the way out is
/// worse than an export that fails.
void main() {
  const fields = [
    ResultField(name: 'id', dataType: 'INTEGER', ordinal: 0),
    ResultField(name: 'name', dataType: 'TEXT', ordinal: 1),
    ResultField(name: 'total', dataType: 'REAL', ordinal: 2),
  ];

  final rows = [
    const ResultRow([1, 'Ada', 10.5]),
    const ResultRow([2, null, 0]),
  ];

  String render(
    ExportFormat format,
    List<ResultRow> data, {
    ExportOptions options = const ExportOptions(),
    List<ResultField> cols = fields,
  }) =>
      ResultFormatter.of(format, options).formatAll(cols, data);

  group('CSV', () {
    test('header plus one line per row', () {
      expect(render(ExportFormat.csv, rows), '''
id,name,total
1,Ada,10.5
2,,0
''');
    });

    test('the header can be left off, for appending to an existing file', () {
      final out = render(ExportFormat.csv, rows,
          options: const ExportOptions(includeHeader: false));
      expect(out, startsWith('1,Ada'));
    });

    test('a value containing the delimiter, a quote or a newline is quoted', () {
      final out = render(ExportFormat.csv, [
        const ResultRow([1, 'Smith, Ada', 0]),
        const ResultRow([2, 'she said "hi"', 0]),
        const ResultRow([3, 'two\nlines', 0]),
      ]);
      expect(out, contains('"Smith, Ada"'));
      // The RFC escape is a doubled quote, not a backslash.
      expect(out, contains('"she said ""hi"""'));
      expect(out, contains('"two\nlines"'));
    });

    test('surrounding whitespace is quoted so it survives the round trip', () {
      // Plenty of parsers strip unquoted padding, and a value that changes when
      // it comes back is a bug found much later.
      expect(render(ExportFormat.csv, [const ResultRow([1, '  pad  ', 0])]),
          contains('"  pad  "'));
    });

    test('a value needing no quotes gets none', () {
      expect(render(ExportFormat.csv, [const ResultRow([1, 'plain', 0])]),
          contains('\n1,plain,0\n'));
    });

    test('NULL renders as the configured text, empty by default', () {
      expect(render(ExportFormat.csv, rows), contains('\n2,,0\n'));
      expect(
        render(ExportFormat.csv, rows,
            options: const ExportOptions(nullText: 'NULL')),
        contains('\n2,NULL,0\n'),
      );
    });

    test('NULL and the empty string are indistinguishable — by design', () {
      // CSV has no null. Worth pinning so nobody "fixes" it into a round trip
      // the format cannot support.
      final withNull = render(ExportFormat.csv, [const ResultRow([1, null, 0])]);
      final withEmpty = render(ExportFormat.csv, [const ResultRow([1, '', 0])]);
      expect(withNull, withEmpty);
    });
  });

  group('TSV', () {
    test('tab separated, and a value containing a tab is quoted', () {
      expect(render(ExportFormat.tsv, rows), contains('1\tAda\t10.5'));
      expect(
        render(ExportFormat.tsv, [const ResultRow([1, 'a\tb', 0])]),
        contains('"a\tb"'),
      );
    });

    test('a comma is NOT quoted here — it is not the delimiter', () {
      expect(render(ExportFormat.tsv, [const ResultRow([1, 'a,b', 0])]),
          contains('1\ta,b\t0'));
    });
  });

  group('JSON', () {
    test('parses back to a list of objects with types preserved', () {
      final parsed = jsonDecode(render(ExportFormat.json, rows)) as List;
      expect(parsed, hasLength(2));
      expect(parsed[0], {'id': 1, 'name': 'Ada', 'total': 10.5});
      // null stays null and numbers stay numbers — the whole point of JSON
      // over CSV, so stringifying them would throw away its one advantage.
      expect(parsed[1]['name'], isNull);
      expect(parsed[1]['total'], isA<num>());
    });

    test('an empty result is still valid JSON', () {
      expect(jsonDecode(render(ExportFormat.json, const [])), isEmpty);
    });

    test('duplicate column names do not collide', () {
      // `SELECT id, id` — one key would silently drop a column.
      const dup = [
        ResultField(name: 'id', dataType: 'INTEGER', ordinal: 0),
        ResultField(name: 'id', dataType: 'INTEGER', ordinal: 1),
      ];
      final parsed = jsonDecode(
        render(ExportFormat.json, [const ResultRow([1, 2])], cols: dup),
      ) as List;
      expect(parsed.single, {'id': 1, 'id_1': 2});
    });

    test('quotes and newlines are escaped by the encoder, not by us', () {
      final parsed = jsonDecode(
        render(ExportFormat.json, [const ResultRow([1, 'a"b\nc', 0])]),
      ) as List;
      expect(parsed.single['name'], 'a"b\nc');
    });
  });

  group('SQL INSERT', () {
    test('one statement per row, quoted for the dialect', () {
      final out = render(ExportFormat.sqlInsert, rows,
          options: const ExportOptions(
            dialect: SqlDialect.postgres,
            table: 'customers',
          ));
      expect(out, contains('INSERT INTO "customers"'));
      expect(out, contains("VALUES (1, 'Ada', 10.5)"));
      // A real NULL, not the empty string — SQL has one, so use it.
      expect(out, contains('VALUES (2, NULL, 0)'));
    });

    test('MySQL gets backticks', () {
      final out = render(ExportFormat.sqlInsert, rows,
          options: const ExportOptions(dialect: SqlDialect.mysql));
      expect(out, contains('INSERT INTO `exported_rows`'));
    });

    test("a quote in a value cannot end the literal", () {
      // The encoder is the security boundary: these are inlined literals, not
      // bound parameters.
      final out = render(
        ExportFormat.sqlInsert,
        [const ResultRow([1, "O'Brien'); DROP TABLE t; --", 0])],
      );
      expect(out, contains("'O''Brien''); DROP TABLE t; --'"));
    });
  });

  group('Markdown', () {
    test('columns are padded to a readable width', () {
      final out = render(ExportFormat.markdown, [
        const ResultRow([1, 'Ada', 10.5]),
        const ResultRow([2, 'Katherine', 0]),
      ]);
      final lines = out.trimRight().split('\n');
      expect(lines, hasLength(4)); // header, separator, two rows
      // Every line is the same width, which is the only reason to pad at all.
      expect(lines.map((l) => l.length).toSet(), hasLength(1));
      expect(lines[1], matches(RegExp(r'^\|( -+ \|)+$')));
      expect(lines[2], contains('| Ada       |'));
    });

    test('a pipe or a newline in a value cannot reshape the table', () {
      final out = render(
        ExportFormat.markdown,
        [const ResultRow([1, 'a|b', 0])],
      );
      expect(out, contains(r'a\|b'));
      expect(out.trimRight().split('\n'), hasLength(3));

      final multiline =
          render(ExportFormat.markdown, [const ResultRow([1, 'x\ny', 0])]);
      // The newline becomes a space rather than a second, malformed row.
      expect(multiline.trimRight().split('\n'), hasLength(3));
      expect(multiline, contains('x y'));
    });

    test('the separator is a valid table even for a one-character column', () {
      const narrow = [ResultField(name: 'a', dataType: 'TEXT', ordinal: 0)];
      final out =
          render(ExportFormat.markdown, [const ResultRow(['b'])], cols: narrow);
      // Fewer than three dashes is not a Markdown table.
      expect(out, contains('| --- |'));
    });
  });

  group('value coercion', () {
    test('a DateTime is ISO-8601 everywhere', () {
      final ts = DateTime.utc(2026, 8, 2, 13, 5);
      const cols = [ResultField(name: 'at', dataType: 'TIMESTAMP', ordinal: 0)];
      final row = [ResultRow([ts])];

      expect(render(ExportFormat.csv, row, cols: cols),
          contains('2026-08-02T13:05:00.000Z'));
      expect(jsonDecode(render(ExportFormat.json, row, cols: cols)).single['at'],
          '2026-08-02T13:05:00.000Z');
    });

    test('binary is summarized in text formats and base64 in JSON', () {
      // Stuffing bytes into a CSV cell corrupts them silently; saying how many
      // there are is at least true.
      const cols = [ResultField(name: 'blob', dataType: 'BLOB', ordinal: 0)];
      final row = [ResultRow([Uint8List.fromList([1, 2, 3])])];

      expect(render(ExportFormat.csv, row, cols: cols), contains('<3 bytes>'));
      expect(
        jsonDecode(render(ExportFormat.json, row, cols: cols)).single['blob'],
        base64Encode([1, 2, 3]),
      );
    });
  });

  test('every format survives an empty result', () {
    for (final format in ExportFormat.values) {
      expect(() => render(format, const []), returnsNormally,
          reason: '${format.label} threw on zero rows');
    }
  });

  test('only Markdown needs every row before it can write one', () {
    // What decides whether a format can be streamed to a file.
    for (final format in ExportFormat.values) {
      expect(format.streams, format != ExportFormat.markdown,
          reason: format.label);
    }
  });
}
