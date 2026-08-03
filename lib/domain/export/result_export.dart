import 'dart:convert';
import 'dart:typed_data';

import '../drivers/result.dart';
import '../models/column_editor.dart';
import '../sql/dml_builder.dart';
import '../sql/editable_result.dart';
import '../sql/sql_statement_splitter.dart';

/// The shapes a result set can leave the app in.
///
/// Each answers a different question. CSV and TSV are for a spreadsheet — TSV
/// because that is what a paste into one actually expects. JSON is for a
/// script. `INSERT` is for moving rows to another database. Markdown is for a
/// pull request or a ticket.
enum ExportFormat {
  csv('CSV', 'csv'),
  tsv('TSV', 'tsv'),
  json('JSON', 'json'),
  sqlInsert('SQL INSERT', 'sql'),
  markdown('Markdown', 'md');

  const ExportFormat(this.label, this.extension);

  final String label;
  final String extension;

  /// Markdown aligns its columns, so it has to see every row before it can
  /// write the first one. The rest can be written as rows arrive, which is what
  /// makes exporting a result larger than memory possible.
  bool get streams => this != ExportFormat.markdown;
}

/// Everything about an export that is a choice rather than a format rule.
class ExportOptions {
  const ExportOptions({
    this.includeHeader = true,
    this.nullText = '',
    this.dialect = SqlDialect.sqlite,
    this.table = 'exported_rows',
  });

  /// Column names as the first line. Off is for appending to an existing file.
  final bool includeHeader;

  /// What a SQL NULL becomes in the text formats.
  ///
  /// Empty by default, which is the spreadsheet convention — and the reason
  /// CSV cannot round-trip the difference between NULL and `''`. JSON and
  /// `INSERT` ignore this: both have a real null and lose nothing.
  final String nullText;

  /// Identifier quoting and literal encoding for [ExportFormat.sqlInsert].
  final SqlDialect dialect;

  /// Table name the generated `INSERT`s target. The result's own table when we
  /// know it; otherwise a placeholder the user is expected to edit.
  final String table;

  ExportOptions copyWith({
    bool? includeHeader,
    String? nullText,
    SqlDialect? dialect,
    String? table,
  }) => ExportOptions(
    includeHeader: includeHeader ?? this.includeHeader,
    nullText: nullText ?? this.nullText,
    dialect: dialect ?? this.dialect,
    table: table ?? this.table,
  );
}

/// Serializes a result set.
///
/// Split into [header] / [row] / [footer] rather than one `format(rows)` so the
/// same code serves a clipboard copy and a streamed file — a result set worth
/// exporting is frequently larger than one worth holding in a string.
abstract class ResultFormatter {
  const ResultFormatter(this.options);

  factory ResultFormatter.of(ExportFormat format, ExportOptions options) =>
      switch (format) {
        ExportFormat.csv => _DelimitedFormatter(options, delimiter: ','),
        ExportFormat.tsv => _DelimitedFormatter(options, delimiter: '\t'),
        ExportFormat.json => _JsonFormatter(options),
        ExportFormat.sqlInsert => _InsertFormatter(options),
        ExportFormat.markdown => _MarkdownFormatter(options),
      };

  final ExportOptions options;

  /// Emitted once before any row; null when the format has no preamble.
  String? header(List<ResultField> fields);

  /// One row. [index] is its position, which the JSON formatter needs to know
  /// where the commas go.
  String row(List<ResultField> fields, ResultRow row, int index);

  /// Emitted once after the last row. [rowCount] is how many were written.
  String? footer(int rowCount);

  /// The whole thing as one string — the clipboard path, and the only path a
  /// non-streaming format has.
  String formatAll(List<ResultField> fields, List<ResultRow> rows) {
    final out = StringBuffer();
    final head = header(fields);
    if (head != null) out.writeln(head);
    for (var i = 0; i < rows.length; i++) {
      out.writeln(row(fields, rows[i], i));
    }
    final foot = footer(rows.length);
    if (foot != null) out.writeln(foot);
    return out.toString();
  }

  /// A cell as display text, before any format-specific quoting.
  String text(Object? value) => switch (value) {
    null => options.nullText,
    // Binary is not text and pretending otherwise corrupts it silently.
    // Length is the honest summary; a real BLOB export is its own feature.
    Uint8List b => '<${b.length} bytes>',
    DateTime d => d.toIso8601String(),
    _ => '$value',
  };
}

/// CSV and TSV. One class because they differ only in the delimiter and in
/// which characters therefore force a quote.
class _DelimitedFormatter extends ResultFormatter {
  const _DelimitedFormatter(super.options, {required this.delimiter});

  final String delimiter;

  @override
  String? header(List<ResultField> fields) => options.includeHeader
      ? fields.map((f) => _quote(f.name)).join(delimiter)
      : null;

  @override
  String row(List<ResultField> fields, ResultRow row, int index) =>
      row.values.map((v) => _quote(text(v))).join(delimiter);

  @override
  String? footer(int rowCount) => null;

  /// RFC 4180: quote only when the value would otherwise break the parse, and
  /// escape an embedded quote by doubling it.
  ///
  /// A leading or trailing space is also quoted — some parsers strip it, and a
  /// value that changes when it round-trips is a bug you find much later.
  String _quote(String value) {
    final needsQuote =
        value.contains(delimiter) ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r') ||
        value != value.trim();
    if (!needsQuote) return value;
    return '"${value.replaceAll('"', '""')}"';
  }
}

/// A JSON array of objects, one per row.
class _JsonFormatter extends ResultFormatter {
  const _JsonFormatter(super.options);

  @override
  String? header(List<ResultField> fields) => '[';

  @override
  String row(List<ResultField> fields, ResultRow row, int index) {
    final object = <String, Object?>{};
    for (var i = 0; i < fields.length; i++) {
      // Duplicate projections (`SELECT id, id`) would collide on one key, so
      // the second gets its position appended rather than silently winning.
      final key = object.containsKey(fields[i].name)
          ? '${fields[i].name}_$i'
          : fields[i].name;
      object[key] = _jsonValue(row.values[i]);
    }
    // Comma before rather than after, so the last row needs no fixup and the
    // stream never has to look ahead.
    return '${index == 0 ? '  ' : '  ,'}${jsonEncode(object)}';
  }

  @override
  String? footer(int rowCount) => ']';

  /// Null stays null and numbers stay numbers — JSON has both, so stringifying
  /// them would throw away the one advantage this format has.
  Object? _jsonValue(Object? value) => switch (value) {
    null => null,
    num() || bool() || String() => value,
    DateTime d => d.toIso8601String(),
    Uint8List b => base64Encode(b),
    _ => '$value',
  };
}

/// One `INSERT` per row, quoted for the target dialect.
class _InsertFormatter extends ResultFormatter {
  const _InsertFormatter(super.options);

  @override
  String? header(List<ResultField> fields) => null;

  @override
  String row(List<ResultField> fields, ResultRow row, int index) {
    final builder = DmlBuilder(options.dialect);
    return builder.insert(EditableTarget(table: options.table), [
          for (var i = 0; i < fields.length; i++)
            CellEdit(
              fields[i].name,
              _literalValue(row.values[i]),
              _editorFor(row.values[i]),
            ),
        ]) ??
        '';
  }

  @override
  String? footer(int rowCount) => null;

  /// [DmlBuilder] encodes a value by the *editor* it is handed, and an export
  /// has no schema behind it to supply one. Choosing by runtime type is what
  /// keeps `10.5` a number instead of the string `'10.5'` — which would still
  /// insert on most engines, and compare and sort wrongly forever after.
  ColumnEditor _editorFor(Object? value) => switch (value) {
    int() => const ColumnEditor(kind: ColumnEditorKind.integer, nullable: true),
    num() => const ColumnEditor(kind: ColumnEditorKind.decimal, nullable: true),
    bool() => const ColumnEditor(
      kind: ColumnEditorKind.boolean,
      nullable: true,
    ),
    _ => const ColumnEditor(kind: ColumnEditorKind.text, nullable: true),
  };

  /// Only the values with no SQL literal of their own need converting.
  Object? _literalValue(Object? value) => switch (value) {
    DateTime d => d.toIso8601String(),
    Uint8List b => base64Encode(b),
    _ => value,
  };
}

/// A pipe table with aligned columns.
///
/// The only format that buffers: the column widths are not known until every
/// row has been seen. That is acceptable precisely because nobody streams a
/// million rows into a Markdown table — this is the paste-into-a-ticket format.
class _MarkdownFormatter extends ResultFormatter {
  const _MarkdownFormatter(super.options);

  @override
  String? header(List<ResultField> fields) => null;

  @override
  String row(List<ResultField> fields, ResultRow row, int index) =>
      _line([for (final v in row.values) _escape(text(v))]);

  @override
  String? footer(int rowCount) => null;

  @override
  String formatAll(List<ResultField> fields, List<ResultRow> rows) {
    final names = [for (final f in fields) _escape(f.name)];
    final cells = [
      for (final r in rows) [for (final v in r.values) _escape(text(v))],
    ];

    final widths = [
      for (var i = 0; i < names.length; i++)
        [
          names[i].length,
          for (final row in cells)
            if (i < row.length) row[i].length,
          // The separator needs three dashes to be a table at all.
          3,
        ].reduce((a, b) => a > b ? a : b),
    ];

    String pad(List<String> row) => _line([
      for (var i = 0; i < names.length; i++)
        (i < row.length ? row[i] : '').padRight(widths[i]),
    ]);

    final out = StringBuffer();
    if (options.includeHeader) {
      out.writeln(pad(names));
      out.writeln(_line([for (final w in widths) '-' * w]));
    }
    for (final row in cells) {
      out.writeln(pad(row));
    }
    return out.toString();
  }

  String _line(List<String> cells) => '| ${cells.join(' | ')} |';

  /// A pipe inside a cell ends the cell; a newline ends the row. Both have to
  /// go, or one value silently rewrites the table's shape.
  String _escape(String value) => value
      .replaceAll(r'\', r'\\')
      .replaceAll('|', r'\|')
      .replaceAll('\r\n', ' ')
      .replaceAll('\n', ' ')
      .replaceAll('\r', ' ');
}
