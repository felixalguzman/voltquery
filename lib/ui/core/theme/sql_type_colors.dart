import 'package:fluent_ui/fluent_ui.dart';

import '../../../domain/models/column_editor.dart';

/// Colours for SQL data types, keyed by **semantic kind** rather than by the
/// type name the engine happens to use.
///
/// That indirection is what makes this provider-correct for free:
/// `ColumnEditorResolver` already normalises `int4` / `bigint` / `INTEGER` to
/// one kind, so Postgres, MySQL and SQLite colour consistently without a
/// per-engine table to keep in sync.
///
/// A [SqlTypeColors] instance is a plain value, so a future theme (#7) can
/// supply its own without touching call sites.
@immutable
class SqlTypeColors {
  const SqlTypeColors({
    required this.text,
    required this.number,
    required this.boolean,
    required this.temporal,
    required this.json,
    required this.enumeration,
    required this.binary,
  });

  final Color text;
  final Color number;
  final Color boolean;
  final Color temporal;
  final Color json;
  final Color enumeration;
  final Color binary;

  /// The Clean Dev-Tool palette. Hues are chosen so the categories stay
  /// distinguishable rather than merely decorative — numbers and dates in
  /// particular are what you scan a wide table for.
  static const dark = SqlTypeColors(
    text: Color(0xFF8FB8D8),
    number: Color(0xFF6FE39A),
    boolean: Color(0xFFE8B84B),
    temporal: Color(0xFF2FE6FF),
    json: Color(0xFFB98CFF),
    enumeration: Color(0xFFFF9E64),
    binary: Color(0xFF7A828F),
  );

  Color of(ColumnEditorKind kind) => switch (kind) {
        ColumnEditorKind.text => text,
        ColumnEditorKind.integer || ColumnEditorKind.decimal => number,
        ColumnEditorKind.boolean => boolean,
        ColumnEditorKind.date ||
        ColumnEditorKind.dateTime ||
        ColumnEditorKind.time =>
          temporal,
        ColumnEditorKind.json => json,
        ColumnEditorKind.enumeration => enumeration,
        ColumnEditorKind.binary => binary,
      };
}
