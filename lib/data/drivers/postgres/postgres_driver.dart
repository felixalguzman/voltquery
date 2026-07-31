import 'package:postgres/postgres.dart' as pg;

import '../../../domain/drivers/driver.dart';
import '../../../domain/drivers/driver_error.dart';
import '../../../domain/drivers/result.dart';
import '../../../domain/drivers/schema_introspector.dart';
import '../../../domain/models/capabilities.dart';
import '../../../domain/models/connection.dart';
import '../../../domain/models/engine.dart';
import '../../../domain/models/schema.dart';

/// PostgreSQL adapter (ADR-0003) over the `postgres` v3 package. Behind the
/// [Driver] port — the app never sees `postgres` types.
class PostgresDriver implements Driver {
  @override
  Engine get engine => Engine.postgres;

  @override
  Capabilities get capabilities => const Capabilities(
        hasServer: true,
        hasSchemas: true,
        supportsTls: true,
        // Postgres CAN cancel, but `postgres` v3.5.12 doesn't expose it on the
        // public Connection API (cancelPendingStatement is internal). Gated off
        // honestly until the package surfaces it.
        supportsQueryCancel: false,
        supportsSavepoints: true,
        supportsNestedTransactions: false,
        paramStyle: ParamStyle.dollar,
      );

  @override
  Future<Session> connect(Connection config, {String? secret}) async {
    try {
      final conn = await pg.Connection.open(
        pg.Endpoint(
          host: config.host ?? 'localhost',
          port: config.port ?? 5432,
          database: config.defaultDatabase ?? 'postgres',
          username: config.username,
          password: secret,
        ),
        // TODO(tls): derive sslMode from the connection's TLS setting.
        settings: const pg.ConnectionSettings(sslMode: pg.SslMode.disable),
      );
      return PostgresSession(config, conn);
    } on pg.PgException catch (e) {
      throw _mapPgError(e);
    } catch (e) {
      throw DriverError(DriverErrorKind.connectionFailed, e.toString(),
          cause: e);
    }
  }
}

class PostgresSession implements Session {
  PostgresSession(this._connection, this._conn);

  final Connection _connection;
  final pg.Connection _conn;

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
      // TODO(params): app currently passes literal SQL (no bound params).
      final result = await _conn.execute(sql);
      final cols = result.schema.columns;
      if (cols.isEmpty) {
        return CommandResult(affectedRows: result.affectedRows);
      }
      final fields = <ResultField>[
        for (var i = 0; i < cols.length; i++)
          ResultField(
            name: cols[i].columnName ?? 'column$i',
            dataType: cols[i].type.toString(),
            ordinal: i,
          ),
      ];
      final rows = [for (final r in result) ResultRow(r.toList())];
      return RowsResult(_BufferedCursor(fields, rows));
    } on pg.PgException catch (e) {
      throw _mapPgError(e);
    }
  }

  @override
  Future<void> begin() async => _conn.execute('BEGIN');
  @override
  Future<void> commit() async => _conn.execute('COMMIT');
  @override
  Future<void> rollback() async => _conn.execute('ROLLBACK');

  @override
  Future<void> useDatabase(String name) async => throw DriverError(
      DriverErrorKind.unsupported,
      'Postgres binds a connection to one database; reconnect to switch');

  @override
  Future<void> cancelActive() async => throw DriverError(
      DriverErrorKind.unsupported,
      'Query cancel is not exposed by postgres v3.5.12');

  @override
  SchemaIntrospector get schema => _PostgresIntrospector(_conn);

  @override
  Future<void> close() async => _conn.close();
}

/// Postgres `execute()` buffers all rows; wrap the materialized list in the
/// pull-based cursor the port expects.
class _BufferedCursor implements ResultCursor {
  _BufferedCursor(this.fields, this._rows);

  @override
  final List<ResultField> fields;
  final List<ResultRow> _rows;
  int _pos = 0;

  @override
  bool get hasMore => _pos < _rows.length;

  @override
  Future<List<ResultRow>> fetch(int n) async {
    final end = (_pos + n).clamp(0, _rows.length);
    final batch = _rows.sublist(_pos, end);
    _pos = end;
    return batch;
  }

  @override
  Future<void> close() async {}
}

/// Postgres introspection via `information_schema` / `pg_catalog` (ADR-0001) —
/// the one place `switch(engine)` catalog logic lives.
class _PostgresIntrospector implements SchemaIntrospector {
  _PostgresIntrospector(this._conn);

  final pg.Connection _conn;

  @override
  Future<List<DatabaseInfo>> databases() async {
    final r = await _conn.execute(
        "SELECT datname FROM pg_database WHERE datistemplate = false "
        'ORDER BY datname');
    return [for (final row in r) DatabaseInfo(row[0] as String)];
  }

  @override
  Future<List<SchemaInfo>> schemas(DatabaseInfo database) async {
    final r = await _conn.execute(
        "SELECT schema_name FROM information_schema.schemata "
        "WHERE schema_name NOT LIKE 'pg\\_%' "
        "AND schema_name <> 'information_schema' ORDER BY schema_name");
    return [for (final row in r) SchemaInfo(row[0] as String)];
  }

  @override
  Future<List<TableInfo>> tables(SchemaInfo schema) async {
    final schemaName = schema.name.isEmpty ? 'public' : schema.name;
    final r = await _conn.execute(
      pg.Sql.named('SELECT table_name, table_type FROM information_schema.tables '
          'WHERE table_schema = @s ORDER BY table_name'),
      parameters: {'s': schemaName},
    );
    return [
      for (final row in r)
        TableInfo(
          name: row[0] as String,
          kind: (row[1] as String) == 'VIEW' ? ObjectKind.view : ObjectKind.table,
        ),
    ];
  }

  @override
  Future<List<ColumnInfo>> columns(TableInfo table) async {
    final r = await _conn.execute(
      pg.Sql.named(
          'SELECT column_name, data_type, is_nullable, ordinal_position, column_default '
          'FROM information_schema.columns WHERE table_name = @t '
          'ORDER BY ordinal_position'),
      parameters: {'t': table.name},
    );
    return [
      for (final row in r)
        ColumnInfo(
          name: row[0] as String,
          dataType: row[1] as String,
          nullable: (row[2] as String) == 'YES',
          isPrimaryKey: false, // TODO(slice): key constraints
          isForeignKey: false,
          ordinal: (row[3] as int) - 1,
          defaultValue: row[4]?.toString(),
        ),
    ];
  }

  @override
  Future<List<IndexInfo>> indexes(TableInfo table) async =>
      throw UnimplementedError('index introspection — later slice');
}

/// Maps a Postgres exception into the normalized [DriverError] taxonomy.
DriverError mapPgError(pg.PgException e) => _mapPgError(e);

DriverError _mapPgError(pg.PgException e) {
  final code = e is pg.ServerException ? e.code : null;
  final kind = switch (code) {
    '42601' => DriverErrorKind.syntaxError,
    '28P01' || '28000' => DriverErrorKind.authFailed,
    '42P01' || '42703' || '3D000' => DriverErrorKind.objectNotFound,
    '23505' || '23503' || '23502' || '23514' =>
      DriverErrorKind.constraintViolation,
    '42501' => DriverErrorKind.permissionDenied,
    '57014' => DriverErrorKind.canceled,
    _ => DriverErrorKind.serverError,
  };
  return DriverError(kind, e.message, nativeCode: code, cause: e);
}
