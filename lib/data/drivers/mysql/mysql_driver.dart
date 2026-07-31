import 'package:mysql_client/exception.dart' as my;
import 'package:mysql_client/mysql_client.dart' as my;

import '../../../domain/drivers/driver.dart';
import '../../../domain/drivers/driver_error.dart';
import '../../../domain/drivers/result.dart';
import '../../../domain/drivers/schema_introspector.dart';
import '../../../domain/models/capabilities.dart';
import '../../../domain/models/connection.dart';
import '../../../domain/models/engine.dart';
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
        hasSchemas: false, // MySQL: Database == Schema
        supportsTls: true,
        supportsQueryCancel: false, // not exposed by mysql_client
        supportsSavepoints: true,
        supportsNestedTransactions: false,
        paramStyle: ParamStyle.question,
      );

  @override
  Future<Session> connect(Connection config, {String? secret}) async {
    try {
      final conn = await my.MySQLConnection.createConnection(
        host: config.host ?? 'localhost',
        port: config.port ?? 3306,
        userName: config.username ?? 'root',
        password: secret ?? '',
        databaseName: config.defaultDatabase,
        secure: false, // TODO(tls): derive from the connection's TLS setting.
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

/// MySQL introspection via `information_schema` scoped to the current DATABASE().
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
  Future<List<SchemaInfo>> schemas(DatabaseInfo database) async =>
      const []; // MySQL has no schema level (Capabilities.hasSchemas == false)

  @override
  Future<List<TableInfo>> tables(SchemaInfo schema) async {
    final rs = await _conn.execute(
        'SELECT table_name, table_type FROM information_schema.tables '
        'WHERE table_schema = DATABASE() ORDER BY table_name');
    return [
      for (final r in rs.rows)
        TableInfo(
          name: r.colAt(0) ?? '',
          kind: r.colAt(1) == 'VIEW' ? ObjectKind.view : ObjectKind.table,
        ),
    ];
  }

  @override
  Future<List<ColumnInfo>> columns(TableInfo table) async {
    final rs = await _conn.execute(
      'SELECT column_name, data_type, is_nullable, ordinal_position, column_default '
      'FROM information_schema.columns '
      'WHERE table_schema = DATABASE() AND table_name = :t '
      'ORDER BY ordinal_position',
      {'t': table.name},
    );
    return [
      for (final r in rs.rows)
        ColumnInfo(
          name: r.colAt(0) ?? '',
          dataType: r.colAt(1) ?? '',
          nullable: r.colAt(2) == 'YES',
          isPrimaryKey: false, // TODO(slice): key constraints
          isForeignKey: false,
          ordinal: (int.tryParse(r.colAt(3) ?? '') ?? 1) - 1,
          defaultValue: r.colAt(4),
        ),
    ];
  }

  @override
  Future<List<IndexInfo>> indexes(TableInfo table) async =>
      throw UnimplementedError('index introspection — later slice');
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
