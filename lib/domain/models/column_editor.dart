import 'engine.dart';

/// How a single column should be *edited* in the result grid.
///
/// Derived from the column's engine-declared type (schema `ColumnInfo.dataType`,
/// **not** the projection's `ResultField.dataType` — SQLite and MySQL leave that
/// empty). Picking a real editor per type is what makes inline editing feel
/// better than hand-writing SQL: a date picker beats typing
/// `2026-08-01 14:30:00+00`, a toggle beats guessing between `t`/`true`/`1`.
enum ColumnEditorKind {
  /// Free text — the fallback.
  text,

  /// Whole numbers; the editor rejects non-integers.
  integer,

  /// Fractional numbers (numeric/decimal/real/float).
  decimal,

  /// Two-state toggle. Engines disagree on the wire value, so [DmlBuilder]
  /// re-encodes per dialect.
  boolean,

  /// Calendar picker, no time component.
  date,

  /// Calendar + clock.
  dateTime,

  /// Clock only.
  time,

  /// Multi-line editor with JSON validation.
  json,

  /// Fixed value list (Postgres enum types, MySQL `enum(...)`), rendered as a
  /// dropdown. The allowed values live on [ColumnEditor.options].
  enumeration,

  /// Binary — shown, never edited inline (needs the BLOB viewer, a later slice).
  binary,
}

/// The resolved editor for one column: its [kind], whether NULL is allowed, and
/// the value list for [ColumnEditorKind.enumeration].
class ColumnEditor {
  const ColumnEditor({
    required this.kind,
    required this.nullable,
    this.options = const [],
  });

  final ColumnEditorKind kind;

  /// Drives the explicit "set NULL" affordance. A nullable text column has to
  /// distinguish NULL from `''` — conflating them is a classic inline-edit bug.
  final bool nullable;

  /// Allowed values when [kind] is [ColumnEditorKind.enumeration].
  final List<String> options;

  /// Binary columns are displayed but not editable inline (yet).
  bool get isReadOnly => kind == ColumnEditorKind.binary;

  /// Why [value] can't be stored in this column, or null when it's fine.
  ///
  /// Checked before an edit is staged so a bad value is refused at the cell,
  /// where the user can still see what they typed — rather than becoming SQL
  /// that the engine rejects at apply time with a less obvious message.
  String? validate(Object? value) {
    if (value == null) {
      return nullable ? null : 'This column is NOT NULL.';
    }
    final text = '$value'.trim();
    switch (kind) {
      case ColumnEditorKind.integer:
        if (int.tryParse(text) == null) return 'Expected a whole number.';
      case ColumnEditorKind.decimal:
        if (num.tryParse(text) == null) return 'Expected a number.';
      case ColumnEditorKind.boolean:
        const ok = {'true', 'false', 't', 'f', '0', '1', 'yes', 'no'};
        if (!ok.contains(text.toLowerCase())) return 'Expected true or false.';
      case ColumnEditorKind.date:
      case ColumnEditorKind.dateTime:
        if (DateTime.tryParse(text.replaceFirst(' ', 'T')) == null) {
          return 'Expected a date like 2026-08-01'
              '${kind == ColumnEditorKind.dateTime ? ' 14:30:00' : ''}.';
        }
      case ColumnEditorKind.enumeration:
        if (options.isNotEmpty && !options.contains(text)) {
          return 'Must be one of: ${options.join(', ')}.';
        }
      case ColumnEditorKind.json:
        if (!_looksLikeJson(text)) return 'Expected JSON.';
      case ColumnEditorKind.text:
      case ColumnEditorKind.time:
      case ColumnEditorKind.binary:
        break; // the engine is the better judge
    }
    return null;
  }

  /// A cheap structural check — balanced brackets and quotes. Deliberately not
  /// a full parse: the engine validates properly, this just catches typos
  /// before they become a failed statement.
  static bool _looksLikeJson(String text) {
    if (text.isEmpty) return false;
    final first = text[0];
    if (first != '{' && first != '[' && first != '"') {
      // Scalars are valid JSON too.
      return num.tryParse(text) != null ||
          text == 'true' ||
          text == 'false' ||
          text == 'null';
    }
    var depth = 0;
    var inString = false;
    var escaped = false;
    for (final c in text.split('')) {
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (c == r'\') {
          escaped = true;
        } else if (c == '"') {
          inString = false;
        }
        continue;
      }
      if (c == '"') inString = true;
      if (c == '{' || c == '[') depth++;
      if (c == '}' || c == ']') depth--;
      if (depth < 0) return false;
    }
    return depth == 0 && !inString;
  }

  @override
  bool operator ==(Object other) =>
      other is ColumnEditor &&
      other.kind == kind &&
      other.nullable == nullable &&
      other.options.length == options.length &&
      Iterable<int>.generate(
        options.length,
      ).every((i) => other.options[i] == options[i]);

  @override
  int get hashCode => Object.hash(kind, nullable, Object.hashAll(options));

  @override
  String toString() =>
      'ColumnEditor($kind, nullable: $nullable'
      '${options.isEmpty ? '' : ', options: $options'})';
}

/// Maps an engine's declared column type onto a [ColumnEditor].
///
/// Each engine reports types differently:
/// - **Postgres** `information_schema.columns.data_type` — spelled-out names
///   (`character varying`, `timestamp with time zone`, `USER-DEFINED` for enums).
/// - **MySQL** `data_type` — the bare name (`varchar`, `datetime`, `tinyint`);
///   `enum`/`set` need `column_type` for their value list.
/// - **SQLite** — whatever was *declared* (`INTEGER`, `VARCHAR(50)`, or nothing
///   at all), since the engine is dynamically typed. We read the declared
///   affinity and fall back to text.
class ColumnEditorResolver {
  const ColumnEditorResolver(this.engine);

  final Engine engine;

  /// [dataType] is the engine's declared type. [enumOptions] carries the value
  /// list when the caller already knows it (Postgres `pg_enum`, MySQL
  /// `column_type`); when it's non-empty the column is treated as an enum.
  ColumnEditor resolve(
    String dataType, {
    required bool nullable,
    List<String> enumOptions = const [],
  }) {
    if (enumOptions.isNotEmpty) {
      return ColumnEditor(
        kind: ColumnEditorKind.enumeration,
        nullable: nullable,
        options: enumOptions,
      );
    }
    return ColumnEditor(kind: _kind(dataType), nullable: nullable);
  }

  ColumnEditorKind _kind(String raw) {
    // Normalize: lowercase, drop any length/precision suffix — `VARCHAR(50)`,
    // `numeric(10,2)`, `int unsigned`, `timestamp(3) with time zone`.
    final t = raw.toLowerCase().trim();
    final base = t.split('(').first.trim();

    // Binary first — it outranks the text/number heuristics below.
    if (_isBinary(base)) return ColumnEditorKind.binary;
    if (_isJson(base)) return ColumnEditorKind.json;
    if (_isBoolean(t, base)) return ColumnEditorKind.boolean;

    // Order matters: `timestamp`/`datetime` contain neither `date` nor `time`
    // as a prefix in every engine, so check the compound forms first.
    if (base.contains('timestamp') || base == 'datetime') {
      return ColumnEditorKind.dateTime;
    }
    if (base == 'date') return ColumnEditorKind.date;
    if (base.startsWith('time')) return ColumnEditorKind.time;

    if (_isInteger(base)) return ColumnEditorKind.integer;
    if (_isDecimal(base)) return ColumnEditorKind.decimal;

    return ColumnEditorKind.text;
  }

  bool _isBinary(String base) => const {
    'bytea', 'blob', 'binary', 'varbinary', 'tinyblob', 'mediumblob',
    'longblob', 'image', //
  }.contains(base);

  bool _isJson(String base) => base == 'json' || base == 'jsonb';

  bool _isBoolean(String full, String base) {
    if (base == 'boolean' || base == 'bool') return true;
    // MySQL has no real BOOL: `tinyint(1)` is the idiom. Width matters — a
    // plain `tinyint` is a small integer, so only the (1) form is a toggle.
    if (engine == Engine.mysql && full.replaceAll(' ', '') == 'tinyint(1)') {
      return true;
    }
    // SQLite is dynamically typed; a column *declared* BOOLEAN stores 0/1.
    return engine == Engine.sqlite && base == 'boolean';
  }

  bool _isInteger(String base) =>
      const {
        'smallint', 'integer', 'int', 'bigint', 'int2', 'int4', 'int8',
        'tinyint', 'mediumint', 'serial', 'bigserial', 'smallserial',
        'int unsigned', 'bigint unsigned', //
      }.contains(base) ||
      base.startsWith('int ') || // `int unsigned`
      base.startsWith('bigint ') ||
      base.startsWith('smallint ') ||
      base.startsWith('tinyint ') ||
      base.startsWith('mediumint ');

  bool _isDecimal(String base) =>
      const {
        'numeric', 'decimal', 'real', 'double precision', 'double', 'float',
        'float4', 'float8', 'money', 'dec', //
      }.contains(base) ||
      base.startsWith('double ') ||
      base.startsWith('float ') ||
      base.startsWith('decimal ') ||
      base.startsWith('numeric ');
}
