import '../models/engine.dart';

/// Which dialect's lexical quirks the splitter honours. Derived from [Engine].
enum SqlDialect {
  sqlite,
  postgres,
  mysql;

  static SqlDialect of(Engine engine) => switch (engine) {
    Engine.sqlite => SqlDialect.sqlite,
    Engine.postgres => SqlDialect.postgres,
    Engine.mysql => SqlDialect.mysql,
  };

  /// Postgres block comments nest (`/* /* */ */`); MySQL/SQLite do not.
  bool get nestsBlockComments => this == SqlDialect.postgres;

  /// Postgres dollar-quoted strings: `$tag$ … $tag$` / `$$ … $$`.
  bool get hasDollarQuoting => this == SqlDialect.postgres;

  /// MySQL/MariaDB (and SQLite) accept `` `backtick` `` identifiers.
  bool get hasBacktickIdentifiers => this != SqlDialect.postgres;

  /// MySQL `#` line comments and the `DELIMITER` client command.
  bool get isMysql => this == SqlDialect.mysql;

  /// Quote an identifier for this dialect, escaping any embedded quote char.
  ///
  /// MySQL uses backticks unless ANSI_QUOTES is on, so a double-quoted name is
  /// a *string literal* there and `SELECT * FROM "t"` is a syntax error. Any
  /// generated SQL must go through here rather than hardcoding a quote style.
  String quoteIdentifier(String name) => switch (this) {
    SqlDialect.mysql => '`${name.replaceAll('`', '``')}`',
    _ => '"${name.replaceAll('"', '""')}"',
  };

  /// `schema.table`, or the bare table when unqualified.
  String qualify(String name, {String schema = ''}) => schema.isEmpty
      ? quoteIdentifier(name)
      : '${quoteIdentifier(schema)}.${quoteIdentifier(name)}';
}

/// Coarse first-keyword classification — enough to pick grid-vs-message and to
/// drive the schema tree's post-DDL cache eviction (ADR-0008). Best-effort.
enum StatementKind { query, dml, ddl, other }

/// One statement carved out of a Query buffer.
class SqlStatement {
  const SqlStatement({
    required this.sql,
    required this.kind,
    this.start = 0,
    this.end = 0,
  });

  /// The statement text, trimmed, without its trailing delimiter.
  final String sql;
  final StatementKind kind;

  /// Half-open char span `[start, end)` of this statement's region in the
  /// original buffer (delimiter excluded, leading trivia included) — used to map
  /// a caret offset to its statement ("Run at cursor").
  final int start;
  final int end;

  @override
  String toString() => 'SqlStatement(${kind.name}: $sql)';
}

/// Splits a Query buffer into ordered [SqlStatement]s (ADR-0007), a **dialect-
/// aware** lexer that skips `;` inside string/identifier literals, line/block
/// comments, Postgres dollar-quoting, and honours MySQL `DELIMITER`.
///
/// Pure — no engine I/O — so it is unit-tested exhaustively. Best-effort:
/// whitespace/comment-only fragments are dropped, and an unterminated construct
/// is emitted whole rather than mis-split (see [split]).
class SqlStatementSplitter {
  const SqlStatementSplitter(this.dialect);

  final SqlDialect dialect;

  /// Splits [buffer] into statements. Never throws — on any internal error it
  /// falls back to the whole buffer as a single statement.
  List<SqlStatement> split(String buffer) {
    try {
      return _split(buffer);
    } catch (_) {
      final whole = buffer.trim();
      return whole.isEmpty
          ? const []
          : [SqlStatement(sql: whole, kind: _classify(whole))];
    }
  }

  /// The statement whose region contains [offset] (for "Run at cursor"). Caret
  /// in a blank gap rounds forward to the next statement; past the end → the
  /// last. Null only when the buffer has no statements.
  SqlStatement? statementAt(String buffer, int offset) {
    final sts = split(buffer);
    if (sts.isEmpty) return null;
    for (final st in sts) {
      if (offset <= st.end) return st;
    }
    return sts.last;
  }

  List<SqlStatement> _split(String s) {
    final out = <SqlStatement>[];
    var delimiter = ';';
    var start = 0; // start of the current statement
    var i = 0;
    final n = s.length;

    void emit(int to) {
      final raw = s.substring(start, to);
      final sql = raw.substring(_leadingTriviaEnd(raw)).trim(); // drop comments
      if (sql.isNotEmpty) {
        out.add(
          SqlStatement(sql: sql, kind: _classify(sql), start: start, end: to),
        );
      }
    }

    // Is position [i] the start of a statement (only whitespace seen since the
    // last delimiter)? Used to detect a leading MySQL DELIMITER command.
    bool atStatementHead() {
      for (var j = start; j < i; j++) {
        if (!_isSpace(s.codeUnitAt(j))) return false;
      }
      return true;
    }

    while (i < n) {
      final c = s[i];

      // --- MySQL DELIMITER command (consumes its own line, sets delimiter) ---
      if (dialect.isMysql &&
          atStatementHead() &&
          _matchesKeyword(s, i, 'DELIMITER')) {
        var j = i + 'DELIMITER'.length;
        while (j < n && _isSpace(s.codeUnitAt(j)) && s[j] != '\n') {
          j++;
        }
        final tokenStart = j;
        while (j < n && !_isSpace(s.codeUnitAt(j))) {
          j++;
        }
        final token = s.substring(tokenStart, j);
        if (token.isNotEmpty) delimiter = token;
        // Skip to end of line; the DELIMITER line is not a statement.
        while (j < n && s[j] != '\n') {
          j++;
        }
        i = j;
        start = j;
        continue;
      }

      // --- Comments ---
      if (c == '-' && _peek(s, i + 1) == '-') {
        i = _skipToLineEnd(s, i);
        continue;
      }
      if (dialect.isMysql && c == '#') {
        i = _skipToLineEnd(s, i);
        continue;
      }
      if (c == '/' && _peek(s, i + 1) == '*') {
        i = _skipBlockComment(s, i);
        continue;
      }

      // --- Quotes / identifiers ---
      if (c == "'") {
        i = _skipQuoted(s, i, "'");
        continue;
      }
      if (c == '"') {
        i = _skipQuoted(s, i, '"');
        continue;
      }
      if (c == '`' && dialect.hasBacktickIdentifiers) {
        i = _skipQuoted(s, i, '`');
        continue;
      }
      if (c == r'$' && dialect.hasDollarQuoting) {
        final tag = _dollarTag(s, i);
        if (tag != null) {
          i = _skipDollarQuoted(s, i, tag);
          continue;
        }
      }

      // --- Delimiter ---
      if (_matchesAt(s, i, delimiter)) {
        emit(i);
        i += delimiter.length;
        start = i;
        continue;
      }

      i++;
    }

    emit(n); // trailing statement without a delimiter
    return out;
  }

  // --- Lexer helpers ---------------------------------------------------------

  static String? _peek(String s, int i) => i < s.length ? s[i] : null;

  static bool _isSpace(int u) =>
      u == 0x20 || u == 0x09 || u == 0x0A || u == 0x0D || u == 0x0C;

  static int _skipToLineEnd(String s, int i) {
    while (i < s.length && s[i] != '\n') {
      i++;
    }
    return i;
  }

  /// Consumes a `/* … */` block comment, nesting where the dialect allows it.
  int _skipBlockComment(String s, int i) {
    var depth = 0;
    final n = s.length;
    while (i < n) {
      if (s[i] == '/' && _peek(s, i + 1) == '*') {
        depth++;
        i += 2;
      } else if (s[i] == '*' && _peek(s, i + 1) == '/') {
        depth--;
        i += 2;
        if (depth == 0) return i;
        if (!dialect.nestsBlockComments) return i; // first close ends it
      } else {
        i++;
      }
    }
    return i; // unterminated — consumed to EOF
  }

  /// Consumes a quoted run opened by [q] at [i], handling doubled-quote escapes
  /// (`''`, `""`, ``` `` ```) and MySQL backslash escapes inside strings.
  int _skipQuoted(String s, int i, String q) {
    final n = s.length;
    i++; // past opening quote
    while (i < n) {
      final c = s[i];
      if (dialect.isMysql && c == r'\' && q != '`' && i + 1 < n) {
        i += 2; // \' \" \\ etc. — backslash escape
        continue;
      }
      if (c == q) {
        if (_peek(s, i + 1) == q) {
          i += 2; // doubled quote → literal, stay inside
          continue;
        }
        return i + 1; // closing quote
      }
      i++;
    }
    return i; // unterminated — consumed to EOF
  }

  /// If [i] opens a dollar-quote (`$tag$` / `$$`), returns the full tag token
  /// (e.g. `$body$`); else null.
  String? _dollarTag(String s, int i) {
    final n = s.length;
    var j = i + 1;
    while (j < n) {
      final c = s[j];
      final isTagChar =
          c == '_' ||
          (c.codeUnitAt(0) | 0x20) >= 0x61 &&
              (c.codeUnitAt(0) | 0x20) <= 0x7a ||
          (j > i + 1 && c.codeUnitAt(0) >= 0x30 && c.codeUnitAt(0) <= 0x39);
      if (c == r'$') return s.substring(i, j + 1);
      if (!isTagChar) return null; // not a valid dollar-quote opener
      j++;
    }
    return null;
  }

  int _skipDollarQuoted(String s, int i, String tag) {
    final close = s.indexOf(tag, i + tag.length);
    if (close < 0) return s.length; // unterminated — consumed to EOF
    return close + tag.length;
  }

  static bool _matchesAt(String s, int i, String token) {
    if (i + token.length > s.length) return false;
    for (var k = 0; k < token.length; k++) {
      if (s[i + k] != token[k]) return false;
    }
    return true;
  }

  /// Case-insensitive keyword match at [i] with a word boundary after it.
  static bool _matchesKeyword(String s, int i, String kw) {
    if (i + kw.length > s.length) return false;
    for (var k = 0; k < kw.length; k++) {
      if ((s.codeUnitAt(i + k) | 0x20) != (kw.codeUnitAt(k) | 0x20)) {
        return false;
      }
    }
    final after = i + kw.length;
    if (after >= s.length) return true;
    final u = s.codeUnitAt(after);
    final isWord =
        u == 0x5f ||
        (u | 0x20) >= 0x61 && (u | 0x20) <= 0x7a ||
        u >= 0x30 && u <= 0x39;
    return !isWord;
  }

  // --- Classification --------------------------------------------------------

  static const _ddl = {
    'CREATE',
    'ALTER',
    'DROP',
    'TRUNCATE',
    'COMMENT',
    'RENAME',
  };
  static const _dml = {
    'INSERT',
    'UPDATE',
    'DELETE',
    'MERGE',
    'REPLACE',
    'CALL',
  };
  static const _query = {
    'SELECT',
    'WITH',
    'SHOW',
    'EXPLAIN',
    'PRAGMA',
    'DESCRIBE',
    'DESC',
    'VALUES',
    'TABLE',
  };

  static StatementKind _classify(String sql) {
    final word = _firstKeyword(sql);
    if (_ddl.contains(word)) return StatementKind.ddl;
    if (_dml.contains(word)) return StatementKind.dml;
    if (_query.contains(word)) return StatementKind.query;
    return StatementKind.other;
  }

  /// Index of the first significant char — past leading whitespace and
  /// line/block comments (`--`, `#`, `/* … */`).
  static int _leadingTriviaEnd(String sql) {
    var i = 0;
    final n = sql.length;
    while (i < n) {
      final c = sql[i];
      if (_isSpace(sql.codeUnitAt(i))) {
        i++;
      } else if (c == '-' && _peek(sql, i + 1) == '-') {
        i = _skipToLineEnd(sql, i);
      } else if (c == '#') {
        i = _skipToLineEnd(sql, i);
      } else if (c == '/' && _peek(sql, i + 1) == '*') {
        final close = sql.indexOf('*/', i + 2);
        i = close < 0 ? n : close + 2;
      } else {
        break;
      }
    }
    return i;
  }

  /// First bare keyword, skipping leading whitespace and comments.
  static String _firstKeyword(String sql) {
    final n = sql.length;
    var i = _leadingTriviaEnd(sql);
    final startWord = i;
    while (i < n) {
      final u = sql.codeUnitAt(i);
      final isWord = u == 0x5f || (u | 0x20) >= 0x61 && (u | 0x20) <= 0x7a;
      if (!isWord) break;
      i++;
    }
    return sql.substring(startWord, i).toUpperCase();
  }
}
