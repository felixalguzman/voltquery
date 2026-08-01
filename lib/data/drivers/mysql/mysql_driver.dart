import 'package:mysql_client/exception.dart' as my;
import 'package:mysql_client/mysql_client.dart' as my;

import '../../../domain/drivers/driver.dart';
import '../../../domain/drivers/driver_error.dart';
import '../../../domain/drivers/result.dart';
import '../../../domain/drivers/schema_introspector.dart';
import '../../../domain/models/capabilities.dart';
import '../../../domain/models/connection.dart';
import '../../../domain/models/engine.dart';
import '../../../domain/models/ssl_mode.dart';
import '../../../domain/models/schema.dart';
import '../buffered_cursor.dart';

/// MySQL / MariaDB adapter (ADR-0003) over `mysql_client`. Behind the [Driver]
/// port. MySQL folds Schema into Database, so `hasSchemas` is false.
class MysqlDriver implements Driver {
  @override
  Engine get engine => Engine.mysql;

  @override
  Capabilities get capabilities => const Capabilities(
        hasServer: true,
        // In MySQL, SCHEMA and DATABASE are synonyms — information_schema.
        // schemata *is* the database list. Reporting true means the tree shows
        // databases at the root, so a connection with no default database is
        // still browsable (and any database can be reached, not just the
        // default one).
        hasSchemas: true,
        supportsTls: true,
        // mysql_client hardcodes onBadCertificate: (_) => true.
        verifiesTlsCertificates: false,
        supportsQueryCancel: false, // not exposed by mysql_client
        supportsSavepoints: true,
        supportsNestedTransactions: false,
        paramStyle: ParamStyle.question,
      );

  @override
  Future<Session> connect(Connection config, {String? secret}) async {
    if (config.sslMode == SslMode.verifyFull) {
      // Refusing beats connecting *and reporting* a verified channel we didn't
      // verify — that would be a security claim the driver can't back.
      throw DriverError(
        DriverErrorKind.unsupported,
        'mysql_client cannot verify server certificates (it accepts any '
        'certificate), so "verify full" is not available for MySQL. Use '
        '"required" for an encrypted but unverified connection.',
      );
    }
    try {
      final conn = await my.MySQLConnection.createConnection(
        host: config.host ?? 'localhost',
        port: config.port ?? 3306,
        userName: config.username ?? 'root',
        password: secret ?? '',
        databaseName: config.defaultDatabase,
        // mysql_client's TLS is encrypt-only: it calls SecureSocket.secure
        // with onBadCertificate: (_) => true, so certificates are never
        // checked. `require` is therefore the strongest mode it can honour —
        // verifyFull is refused above rather than silently downgraded.
        secure: config.sslMode.enabled,
      );
      await conn.connect();
      return MysqlSession(config, conn);
    } on my.MySQLServerException catch (e) {
      throw _mapMysqlError(e);
    } catch (e) {
      throw DriverError(DriverErrorKind.connectionFailed, e.toString(),
          cause: e);
    }
  }
}

class MysqlSession implements Session {
  MysqlSession(this._connection, this._conn);

  final Connection _connection;
  final my.MySQLConnection _conn;

  @override
  Connection get connection => _connection;

  @override
  String? get currentDatabase => _connection.defaultDatabase;

  @override
  bool get inTransaction => false; // TODO(exec-model): track tx state

  @override
  Future<ExecutionResult> execute(String sql,
      {List<Object?> params = const []}) async {
    try {
      final rs = await _conn.execute(sql);
      if (rs.numOfColumns == 0) {
        return CommandResult(affectedRows: rs.affectedRows.toInt());
      }
      final cols = rs.cols.toList();
      final fields = <ResultField>[
        for (var i = 0; i < cols.length; i++)
          ResultField(name: cols[i].name, dataType: '', ordinal: i),
      ];
      final rows = [
        for (final r in rs.rows)
          ResultRow([for (var i = 0; i < cols.length; i++) r.colAt(i)]),
      ];
      return RowsResult(BufferedCursor(fields, rows));
    } on my.MySQLServerException catch (e) {
      throw _mapMysqlError(e);
    }
  }

  @override
  Future<void> begin() async => _conn.execute('START TRANSACTION');
  @override
  Future<void> commit() async => _conn.execute('COMMIT');
  @override
  Future<void> rollback() async => _conn.execute('ROLLBACK');

  @override
  Future<void> useDatabase(String name) async =>
      _conn.execute('USE `${name.replaceAll('`', '``')}`');

  @override
  Future<void> cancelActive() async => throw DriverError(
      DriverErrorKind.unsupported, 'mysql_client does not expose query cancel');

  @override
  SchemaIntrospector get schema => _MysqlIntrospector(_conn);

  @override
  Future<void> close() async => _conn.close();
}

/// MySQL introspection via `information_schema`.
///
/// MySQL treats SCHEMA and DATABASE as synonyms, so the schema level *is* the
/// database list — which is what lets a connection with no default database
/// still be browsed, and any database be reached rather than only the default.
/// Lookups fall back to `DATABASE()` when no schema is supplied.
class _MysqlIntrospector implements SchemaIntrospector {
  _MysqlIntrospector(this._conn);

  final my.MySQLConnection _conn;

  @override
  Future<List<DatabaseInfo>> databases() async {
    final rs = await _conn.execute('SELECT schema_name FROM '
        'information_schema.schemata ORDER BY schema_name');
    return [for (final r in rs.rows) DatabaseInfo(r.colAt(0) ?? '')];
  }

  @override
  Future<List<SchemaInfo>> schemas(DatabaseInfo database) async {
    // System databases are listed rather than hidden: filtering them out
    // without a "show system objects" toggle would silently remove the only
    // way to reach them.
    final rs = await _conn.execute('SELECT schema_name FROM '
        'information_schema.schemata ORDER BY schema_name');
    return [for (final r in rs.rows) SchemaInfo(r.colAt(0) ?? '')];
  }

  @override
  Future<List<TableInfo>> tables(SchemaInfo schema) async {
    // COALESCE so an empty schema name still means "the session's database",
    // which keeps a connection that *does* have a default database working.
    final rs = await _conn.execute(
      'SELECT table_name, table_type FROM information_schema.tables '
      'WHERE table_schema = COALESCE(NULLIF(:s, \'\'), DATABASE()) '
      'ORDER BY table_name',
      {'s': schema.name},
    );
    return [
      for (final r in rs.rows)
        TableInfo(
          name: r.colAt(0) ?? '',
          kind: r.colAt(1) == 'VIEW' ? ObjectKind.view : ObjectKind.table,
          // Carried so columns()/indexes() can qualify the lookup — two
          // databases may hold same-named tables.
          schema: schema.name,
        ),
    ];
  }

  @override
  Future<List<ColumnInfo>> columns(TableInfo table) async {
    final keys = await _conn.execute(
      'SELECT column_name, constraint_name, referenced_table_name, '
      '       referenced_column_name, referenced_table_schema '
      'FROM information_schema.key_column_usage '
      'WHERE table_schema = COALESCE(NULLIF(:s, \'\'), DATABASE()) '
      'AND table_name = :t',
      {'s': table.schema, 't': table.name},
    );
    final pk = <String>{};
    final fkRefs = <String, ColumnRef>{};
    for (final r in keys.rows) {
      final col = r.colAt(0) ?? '';
      if (r.colAt(1) == 'PRIMARY') pk.add(col);
      final refTable = r.colAt(2); // set only for a foreign key
      if (refTable != null) {
        fkRefs[col] = ColumnRef(
          table: refTable,
          column: r.colAt(3) ?? '',
          schema: r.colAt(4) ?? '',
        );
      }
    }
    final rs = await _conn.execute(
      'SELECT column_name, data_type, is_nullable, ordinal_position, '
      '       column_default, column_type '
      'FROM information_schema.columns '
      'WHERE table_schema = COALESCE(NULLIF(:s, \'\'), DATABASE()) '
      'AND table_name = :t '
      'ORDER BY ordinal_position',
      {'s': table.schema, 't': table.name},
    );
    return [
      for (final r in rs.rows)
        ColumnInfo(
          name: r.colAt(0) ?? '',
          // data_type is the bare name ('enum'); column_type carries the
          // full declaration ("enum('a','b')") — needed for tinyint(1) too.
          dataType: r.colAt(1) == 'tinyint'
              ? (r.colAt(5) ?? r.colAt(1) ?? '')
              : (r.colAt(1) ?? ''),
          nullable: r.colAt(2) == 'YES',
          isPrimaryKey: pk.contains(r.colAt(0)),
          isForeignKey: fkRefs.containsKey(r.colAt(0)),
          references: fkRefs[r.colAt(0)],
          ordinal: (int.tryParse(r.colAt(3) ?? '') ?? 1) - 1,
          defaultValue: r.colAt(4),
          enumOptions: parseMysqlEnumOptions(r.colAt(5)),
        ),
    ];
  }

  @override
  Future<List<IndexInfo>> indexes(TableInfo table) async {
    final rs = await _conn.execute(
      'SELECT index_name, non_unique, column_name, seq_in_index '
      'FROM information_schema.statistics '
      'WHERE table_schema = COALESCE(NULLIF(:s, \'\'), DATABASE()) '
      'AND table_name = :t '
      'ORDER BY index_name, seq_in_index',
      {'s': table.schema, 't': table.name},
    );
    // Rows are one-per-column; fold them into one IndexInfo per index_name,
    // preserving column order (seq_in_index).
    final byName = <String, ({List<String> cols, bool unique})>{};
    final order = <String>[];
    for (final r in rs.rows) {
      final name = r.colAt(0) ?? '';
      final unique = r.colAt(1) == '0';
      final col = r.colAt(2) ?? '';
      final entry = byName.putIfAbsent(name, () {
        order.add(name);
        return (cols: <String>[], unique: unique);
      });
      entry.cols.add(col);
    }
    return [
      for (final name in order)
        IndexInfo(
            name: name, columns: byName[name]!.cols, unique: byName[name]!.unique),
    ];
  }

  @override
  Future<String> tableDdl(TableInfo table) async {
    // MySQL reprints the full DDL; column 1 is 'Create Table' / 'Create View'.
    final what = table.kind == ObjectKind.view ? 'VIEW' : 'TABLE';
    // Qualify by database — the tree can now browse databases other than the
    // session's default, where an unqualified name would resolve wrongly (or
    // not at all).
    final rs = await _conn.execute('SHOW CREATE $what ${_qualified(table)}');
    final ddl = rs.rows.isEmpty ? null : rs.rows.first.colAt(1);
    if (ddl == null || ddl.isEmpty) {
      return '-- No stored DDL for ${table.name}';
    }
    return '$ddl;';
  }

  @override
  Future<TableStats> tableStats(TableInfo table) async {
    final rs = await _conn.execute(
      'SELECT table_rows, data_length, index_length, table_comment '
      'FROM information_schema.tables '
      "WHERE table_schema = COALESCE(NULLIF(:s, ''), DATABASE()) "
      'AND table_name = :t',
      {'s': table.schema, 't': table.name},
    );
    if (rs.rows.isEmpty) return const TableStats();
    final r = rs.rows.first;
    final rows = int.tryParse(r.colAt(0) ?? '');
    final data = int.tryParse(r.colAt(1) ?? '') ?? 0;
    final index = int.tryParse(r.colAt(2) ?? '') ?? 0;
    final comment = r.colAt(3);
    return TableStats(
      // InnoDB's table_rows is a sampled estimate, not a count — the dialog
      // labels it as such rather than presenting it as exact.
      estimatedRows: rows,
      totalBytes: data + index,
      indexBytes: index,
      comment: (comment == null || comment.isEmpty) ? null : comment,
    );
  }

  @override
  Future<int> rowCount(TableInfo table) async {
    final rs = await _conn.execute(
      'SELECT count(*) FROM ${_qualified(table)}',
    );
    return int.tryParse(rs.rows.first.colAt(0) ?? '') ?? 0;
  }

  @override
  Future<String> indexDdl(TableInfo table, IndexInfo index) async {
    // MySQL has no SHOW CREATE INDEX — reconstruct from the index's columns.
    final cols = index.columns.map(_ident).join(', ');
    if (index.name == 'PRIMARY') {
      return 'ALTER TABLE ${_qualified(table)} ADD PRIMARY KEY ($cols);';
    }
    final unique = index.unique ? 'UNIQUE ' : '';
    return 'CREATE ${unique}INDEX ${_ident(index.name)} '
        'ON ${_qualified(table)} ($cols);';
  }

  /// `db`.`table` when the table carries a database, else the bare name.
  String _qualified(TableInfo table) => table.schema.isEmpty
      ? _ident(table.name)
      : '${_ident(table.schema)}.${_ident(table.name)}';

  /// Backtick-quote a MySQL identifier (escaping embedded backticks).
  String _ident(String id) => '`${id.replaceAll('`', '``')}`';
}

DriverError _mapMysqlError(my.MySQLServerException e) {
  final kind = switch (e.errorCode) {
    1045 => DriverErrorKind.authFailed,
    1064 => DriverErrorKind.syntaxError,
    1146 || 1049 || 1051 || 1054 => DriverErrorKind.objectNotFound,
    1062 || 1451 || 1452 || 1048 => DriverErrorKind.constraintViolation,
    1044 || 1142 || 1143 => DriverErrorKind.permissionDenied,
    _ => DriverErrorKind.serverError,
  };
  return DriverError(kind, e.message,
      nativeCode: e.errorCode.toString(), cause: e);
}

/// `enum('small','large')` / `set('a','b')` -> the permitted values.
/// Doubled quotes inside a label are MySQL's escape (`'it''s'`).
List<String> parseMysqlEnumOptions(String? columnType) {
  if (columnType == null) return const [];
  final lower = columnType.toLowerCase();
  if (!lower.startsWith('enum(') && !lower.startsWith('set(')) {
    return const [];
  }
  final open = columnType.indexOf('(');
  final close = columnType.lastIndexOf(')');
  if (open < 0 || close <= open) return const [];
  final body = columnType.substring(open + 1, close);

  final out = <String>[];
  final buf = StringBuffer();
  var inLiteral = false;
  for (var i = 0; i < body.length; i++) {
    final c = body[i];
    if (!inLiteral) {
      if (c == "'") inLiteral = true;
      continue; // skip separators/whitespace between literals
    }
    if (c == "'") {
      if (i + 1 < body.length && body[i + 1] == "'") {
        buf.write("'"); // escaped quote, still inside
        i++;
        continue;
      }
      out.add(buf.toString());
      buf.clear();
      inLiteral = false;
      continue;
    }
    buf.write(c);
  }
  return out;
}
