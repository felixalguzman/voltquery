import 'sql_statement_splitter.dart';

/// The table a result grid can write back to, resolved from the SELECT that
/// produced it (#53 follow-up: the grid write-path).
///
/// A result is only editable when every displayed row maps 1:1 to a row of one
/// real table — so we accept a plain single-table SELECT and reject anything
/// that breaks that mapping (joins, aggregates, DISTINCT, GROUP BY, set
/// operations, subqueries in FROM). Column *expressions* aren't rejected here;
/// the caller pairs each result field with a real [ColumnInfo] by name and
/// treats the unmatched ones as read-only.
class EditableTarget {
  const EditableTarget({required this.table, this.schema = ''});

  /// Unquoted table name as written in the SQL.
  final String table;

  /// Unquoted schema/qualifier, empty when the SQL didn't qualify the table.
  final String schema;

  @override
  bool operator ==(Object other) =>
      other is EditableTarget && other.table == table && other.schema == schema;

  @override
  int get hashCode => Object.hash(table, schema);

  @override
  String toString() =>
      'EditableTarget(${schema.isEmpty ? '' : '$schema.'}$table)';
}

/// Decides whether a result grid is writable, and against which table.
///
/// Deliberately conservative: **when in doubt, return null** (read-only). A
/// false negative costs the user a hand-written UPDATE; a false positive writes
/// to the wrong row. Uses the same lexer conventions as [SqlStatementSplitter]
/// (quoted identifiers, comments) rather than a full parser — we only need to
/// answer "single plain table?".
class EditableResultAnalyzer {
  const EditableResultAnalyzer(this.dialect);

  final SqlDialect dialect;

  /// Clauses that break the one-row-per-table-row mapping. `JOIN` also covers
  /// `INNER`/`LEFT`/`CROSS` etc. since the keyword itself always appears.
  static const _disqualifying = {
    'join',
    'union',
    'intersect',
    'except',
    'group',
    'distinct',
    'having',
    'values',
  };

  /// Aggregate functions. A bare `SELECT count(*) FROM t` has no GROUP BY yet
  /// still collapses the table to a single row that corresponds to no row of
  /// it — so the clause check above can't catch this on its own.
  ///
  /// Rejecting windowed aggregates (`count(*) OVER ()`, which *is* 1:1) as
  /// collateral is the safe direction to be wrong in.
  static const _aggregates = {
    'count', 'sum', 'avg', 'min', 'max', 'total', 'group_concat', 'string_agg',
    'array_agg', 'json_agg', 'jsonb_agg', 'stddev', 'stddev_pop', 'stddev_samp',
    'variance', 'var_pop', 'var_samp', 'bool_and', 'bool_or', 'every', //
  };

  /// Returns the writable target for [sql], or null when the result must stay
  /// read-only.
  EditableTarget? analyze(String sql) {
    final tokens = _tokenize(sql);
    if (tokens.isEmpty) return null;

    // Must be a bare SELECT (not `WITH …`, not INSERT/UPDATE/…).
    if (tokens.first.text.toLowerCase() != 'select') return null;

    // A comma at depth 0 between FROM and the next clause means multiple tables
    // (old-style join); any disqualifying keyword at depth 0 rules it out too.
    var fromIndex = -1;
    for (var i = 1; i < tokens.length; i++) {
      final t = tokens[i];
      if (t.depth != 0) continue; // inside parens → a scalar subquery, fine
      final word = t.text.toLowerCase();
      if (_disqualifying.contains(word)) return null;
      if (word == 'from' && fromIndex == -1) fromIndex = i;
    }
    if (fromIndex == -1) return null; // `SELECT 1` — nothing to write back to

    // An aggregate in the projection collapses the result set — but only at
    // depth 0: `SELECT id, (SELECT count(*) FROM o) FROM c` aggregates *inside*
    // a scalar subquery and still yields one row per row of `c`.
    for (var i = 1; i < fromIndex; i++) {
      if (tokens[i].depth != 0) continue;
      if (!_aggregates.contains(tokens[i].text.toLowerCase())) continue;
      // Only a *call* aggregates — a column merely named `count` does not.
      if (i + 1 < tokens.length && tokens[i + 1].isOpenParen) return null;
    }

    // The FROM entry: an optionally-qualified identifier, then either the end,
    // an alias, or a clause keyword. A `(` right after FROM is a derived table.
    final rest = tokens.skip(fromIndex + 1).toList();
    if (rest.isEmpty) return null;
    if (rest.first.isOpenParen) return null;

    final parts = <String>[];
    var i = 0;
    while (i < rest.length) {
      final t = rest[i];
      if (t.isOpenParen) return null; // table-valued function → not a table
      parts.add(t.raw);
      final next = i + 1 < rest.length ? rest[i + 1] : null;
      if (next != null && next.text == '.') {
        i += 2; // qualifier separator — keep collecting
        continue;
      }
      break;
    }
    if (parts.isEmpty) return null;
    // More than schema.table (e.g. db.schema.table) — beyond what we model.
    if (parts.length > 2) return null;

    // Whatever follows must start a clause we tolerate, or be an alias. An
    // alias is fine (the DML targets the real table); a comma means a second
    // table, and a `(` means we matched a table-valued function, not a table.
    final after = rest.length > (parts.length * 2 - 1)
        ? rest[parts.length * 2 - 1]
        : null;
    if (after != null && (after.text == ',' || after.isOpenParen)) return null;

    final table = _unquote(parts.last);
    final schema = parts.length == 2 ? _unquote(parts.first) : '';
    if (table.isEmpty) return null;
    return EditableTarget(table: table, schema: schema);
  }

  String _unquote(String raw) {
    if (raw.length < 2) return raw;
    final first = raw[0], last = raw[raw.length - 1];
    if (first == '"' && last == '"') {
      return raw.substring(1, raw.length - 1).replaceAll('""', '"');
    }
    if (first == '`' && last == '`') {
      return raw.substring(1, raw.length - 1).replaceAll('``', '`');
    }
    if (first == '[' && last == ']') return raw.substring(1, raw.length - 1);
    return raw;
  }

  /// Words, quoted identifiers, and the punctuation we care about — with the
  /// paren depth each was seen at. Strings and comments are skipped entirely.
  List<_Tok> _tokenize(String sql) {
    final out = <_Tok>[];
    var depth = 0;
    var i = 0;
    while (i < sql.length) {
      final c = sql[i];

      // -- line comment
      if (c == '-' && i + 1 < sql.length && sql[i + 1] == '-') {
        while (i < sql.length && sql[i] != '\n') {
          i++;
        }
        continue;
      }
      // # line comment (MySQL)
      if (c == '#' && dialect.isMysql) {
        while (i < sql.length && sql[i] != '\n') {
          i++;
        }
        continue;
      }
      // /* block comment */
      if (c == '/' && i + 1 < sql.length && sql[i + 1] == '*') {
        i += 2;
        var nest = 1;
        while (i < sql.length && nest > 0) {
          if (dialect.nestsBlockComments &&
              sql[i] == '/' &&
              i + 1 < sql.length &&
              sql[i + 1] == '*') {
            nest++;
            i += 2;
            continue;
          }
          if (sql[i] == '*' && i + 1 < sql.length && sql[i + 1] == '/') {
            nest--;
            i += 2;
            continue;
          }
          i++;
        }
        continue;
      }
      // '…' string literal (skipped — can't contain an identifier we need)
      if (c == "'") {
        i++;
        while (i < sql.length) {
          if (sql[i] == "'") {
            if (i + 1 < sql.length && sql[i + 1] == "'") {
              i += 2;
              continue;
            }
            i++;
            break;
          }
          i++;
        }
        continue;
      }
      // Quoted identifiers keep their quotes so _unquote can strip them.
      if (c == '"' || (c == '`' && dialect.hasBacktickIdentifiers)) {
        final start = i;
        i++;
        while (i < sql.length) {
          if (sql[i] == c) {
            if (i + 1 < sql.length && sql[i + 1] == c) {
              i += 2;
              continue;
            }
            i++;
            break;
          }
          i++;
        }
        out.add(_Tok(sql.substring(start, i), depth));
        continue;
      }
      if (c == '(') {
        out.add(_Tok('(', depth));
        depth++;
        i++;
        continue;
      }
      if (c == ')') {
        depth--;
        if (depth < 0) depth = 0;
        out.add(_Tok(')', depth));
        i++;
        continue;
      }
      if (c == ',' || c == '.' || c == '*' || c == ';') {
        out.add(_Tok(c, depth));
        i++;
        continue;
      }
      if (_isWordChar(c)) {
        final start = i;
        while (i < sql.length && _isWordChar(sql[i])) {
          i++;
        }
        out.add(_Tok(sql.substring(start, i), depth));
        continue;
      }
      i++; // whitespace / operators we don't care about
    }
    return out;
  }

  static bool _isWordChar(String c) {
    final u = c.codeUnitAt(0);
    return (u >= 48 && u <= 57) || // 0-9
        (u >= 65 && u <= 90) || // A-Z
        (u >= 97 && u <= 122) || // a-z
        c == '_' ||
        c == r'$' ||
        u > 127; // unicode identifiers
  }
}

class _Tok {
  _Tok(this.raw, this.depth);

  /// As written, quotes included.
  final String raw;
  final int depth;

  /// Quote-stripped for keyword comparison.
  String get text => raw;

  bool get isOpenParen => raw == '(';
}
