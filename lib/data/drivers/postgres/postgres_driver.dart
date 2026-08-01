import 'dart:io';
import 'package:postgres/postgres.dart' as pg;

import '../../../domain/drivers/driver.dart';
import '../../../domain/drivers/driver_error.dart';
import '../../../domain/drivers/result.dart';
import '../../../domain/drivers/schema_introspector.dart';
import '../../../domain/models/capabilities.dart';
import '../../../domain/models/connection.dart';
import '../../../domain/models/engine.dart';
import '../../../domain/models/ssl_mode.dart';
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
        verifiesTlsCertificates: true,
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
        settings: pg.ConnectionSettings(
          sslMode: switch (config.sslMode) {
            SslMode.disable => pg.SslMode.disable,
            SslMode.require => pg.SslMode.require,
            SslMode.verifyFull => pg.SslMode.verifyFull,
          },
          // A caller-supplied CA covers self-signed / private-CA servers that
          // the system trust store doesn't know; null falls back to the system
          // roots.
          securityContext: _securityContext(config),
        ),
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

/// Trust roots for [SslMode.verifyFull] when a CA file is configured.
SecurityContext? _securityContext(Connection config) {
  final ca = config.caCertPath;
  if (ca == null || ca.isEmpty) return null;
  return SecurityContext(withTrustedRoots: true)..setTrustedCertificates(ca);
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
          schema: schemaName,
        ),
    ];
  }

  @override
  Future<List<ColumnInfo>> columns(TableInfo table) async {
    // Qualify by schema — same table name can exist in many schemas.
    final schemaName = table.schema.isEmpty ? 'public' : table.schema;
    final keys = await _keyColumns(schemaName, table.name);
    final r = await _conn.execute(
      pg.Sql.named(
          'SELECT column_name, data_type, is_nullable, ordinal_position, '
          '       column_default, udt_name '
          'FROM information_schema.columns WHERE table_schema = @s AND table_name = @t '
          'ORDER BY ordinal_position'),
      parameters: {'s': schemaName, 't': table.name},
    );
    // `data_type` is 'USER-DEFINED' for enums; the real type name is udt_name.
    final enumTypes = {
      for (final row in r)
        if (row[1] == 'USER-DEFINED' && row[5] != null) row[5] as String,
    };
    final enums = await _enumValues(enumTypes);
    return [
      for (final row in r)
        ColumnInfo(
          name: row[0] as String,
          dataType: row[1] as String,
          nullable: (row[2] as String) == 'YES',
          isPrimaryKey: keys.pk.contains(row[0]),
          isForeignKey: keys.fk.containsKey(row[0]),
          references: keys.fk[row[0]],
          ordinal: (row[3] as int) - 1,
          defaultValue: row[4]?.toString(),
          enumOptions: enums[row[5]] ?? const [],
        ),
    ];
  }

  /// Label lists for the given enum type names, in declared sort order — the
  /// permitted values a grid dropdown offers. One round-trip for all of them.
  Future<Map<String, List<String>>> _enumValues(Set<String> typeNames) async {
    if (typeNames.isEmpty) return const {};
    final r = await _conn.execute(
      pg.Sql.named(
        // string_agg, not array_agg — the postgres package hands back array_agg
        // as UndecodedBytes (same trap as indexes()).
        "SELECT t.typname, string_agg(e.enumlabel, ',' ORDER BY e.enumsortorder) "
        'FROM pg_type t JOIN pg_enum e ON e.enumtypid = t.oid '
        'WHERE t.typname = ANY(@names) GROUP BY t.typname',
      ),
      parameters: {'names': typeNames.toList()},
    );
    return {
      for (final row in r)
        row[0] as String: (row[1] as String).split(','),
    };
  }

  /// PK + FK column-name sets for a table (one round-trip via the constraint
  /// catalog). Powers the key glyphs in the schema tree.
  Future<({Set<String> pk, Map<String, ColumnRef> fk})> _keyColumns(
      String schema, String table) async {
    final r = await _conn.execute(
      pg.Sql.named(
        'SELECT kcu.column_name, tc.constraint_type, '
        '       ccu.table_schema, ccu.table_name, ccu.column_name '
        'FROM information_schema.table_constraints tc '
        'JOIN information_schema.key_column_usage kcu '
        '  ON kcu.constraint_name = tc.constraint_name '
        '  AND kcu.constraint_schema = tc.constraint_schema '
        // constraint_column_usage names the *referenced* column of a FK; it's
        // absent (hence the LEFT JOIN) for a primary key.
        'LEFT JOIN information_schema.constraint_column_usage ccu '
        '  ON ccu.constraint_name = tc.constraint_name '
        '  AND ccu.constraint_schema = tc.constraint_schema '
        "  AND tc.constraint_type = 'FOREIGN KEY' "
        "WHERE tc.constraint_type IN ('PRIMARY KEY','FOREIGN KEY') "
        'AND tc.table_schema = @s AND tc.table_name = @t',
      ),
      parameters: {'s': schema, 't': table},
    );
    final pk = <String>{};
    final fk = <String, ColumnRef>{};
    for (final row in r) {
      final col = row[0] as String;
      if (row[1] == 'PRIMARY KEY') {
        pk.add(col);
      } else if (row[3] != null) {
        fk[col] = ColumnRef(
          table: row[3]! as String,
          column: (row[4] as String?) ?? '',
          schema: (row[2] as String?) ?? '',
        );
      }
    }
    return (pk: pk, fk: fk);
  }

  @override
  Future<List<IndexInfo>> indexes(TableInfo table) async {
    final schemaName = table.schema.isEmpty ? 'public' : table.schema;
    final r = await _conn.execute(
      pg.Sql.named(
        // string_agg (not array_agg) — the postgres pkg returns array_agg as
        // UndecodedBytes; a delimited text is decoded to a plain String. attname
        // is null for expression columns; string_agg skips NULLs.
        "SELECT i.relname AS name, ix.indisunique AS is_unique, "
        "string_agg(a.attname, ',' ORDER BY x.ordinality) AS cols "
        'FROM pg_class t '
        'JOIN pg_namespace n ON n.oid = t.relnamespace '
        'JOIN pg_index ix ON ix.indrelid = t.oid '
        'JOIN pg_class i ON i.oid = ix.indexrelid '
        'JOIN LATERAL unnest(ix.indkey) WITH ORDINALITY AS x(attnum, ordinality) '
        '  ON true '
        'LEFT JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = x.attnum '
        'WHERE t.relname = @t AND n.nspname = @s '
        'GROUP BY i.relname, ix.indisunique ORDER BY i.relname',
      ),
      parameters: {'s': schemaName, 't': table.name},
    );
    return [
      for (final row in r)
        IndexInfo(
          name: row[0] as String,
          unique: row[1] as bool,
          columns: (row[2] as String?)?.isNotEmpty ?? false
              ? (row[2] as String).split(',')
              : const [],
        ),
    ];
  }

  @override
  Future<String> tableDdl(TableInfo table) async {
    final schemaName = table.schema.isEmpty ? 'public' : table.schema;
    final qualified = '${_ident(schemaName)}.${_ident(table.name)}';

    if (table.kind == ObjectKind.view) {
      // Postgres reprints the view body verbatim; wrap it as a CREATE.
      final r = await _conn.execute(
        pg.Sql.named('SELECT pg_get_viewdef(@r::regclass, true)'),
        parameters: {'r': qualified},
      );
      final body = (r.first[0] as String).trimRight();
      return 'CREATE OR REPLACE VIEW $qualified AS\n$body';
    }

    // No pg_get_tabledef exists — reconstruct from the catalog: columns with
    // exact types (format_type keeps length/precision), NOT NULL, defaults, PK.
    final cols = await _conn.execute(
      pg.Sql.named(
        'SELECT a.attname, pg_catalog.format_type(a.atttypid, a.atttypmod), '
        '       a.attnotnull, pg_get_expr(ad.adbin, ad.adrelid) '
        'FROM pg_attribute a '
        'LEFT JOIN pg_attrdef ad ON ad.adrelid = a.attrelid AND ad.adnum = a.attnum '
        'WHERE a.attrelid = @r::regclass AND a.attnum > 0 AND NOT a.attisdropped '
        'ORDER BY a.attnum',
      ),
      parameters: {'r': qualified},
    );
    final pk = await _conn.execute(
      pg.Sql.named(
        'SELECT a.attname FROM pg_index i '
        'JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY(i.indkey) '
        'WHERE i.indrelid = @r::regclass AND i.indisprimary '
        'ORDER BY array_position(i.indkey, a.attnum)',
      ),
      parameters: {'r': qualified},
    );

    final lines = <String>[
      for (final c in cols)
        '  ${_ident(c[0] as String)} ${c[1] as String}'
            '${(c[2] as bool) ? ' NOT NULL' : ''}'
            '${c[3] != null ? ' DEFAULT ${c[3]}' : ''}',
    ];
    if (pk.isNotEmpty) {
      final keyCols = pk.map((r) => _ident(r[0] as String)).join(', ');
      lines.add('  PRIMARY KEY ($keyCols)');
    }
    return '-- Reconstructed from the catalog (columns, types, defaults, PK).\n'
        '-- Other constraints, indexes and triggers are not included.\n'
        'CREATE TABLE $qualified (\n${lines.join(',\n')}\n);';
  }

  @override
  Future<String> indexDdl(TableInfo table, IndexInfo index) async {
    final schemaName = table.schema.isEmpty ? 'public' : table.schema;
    final qualified = '${_ident(schemaName)}.${_ident(index.name)}';
    final r = await _conn.execute(
      pg.Sql.named('SELECT pg_get_indexdef(@i::regclass)'),
      parameters: {'i': qualified},
    );
    return '${(r.first[0] as String).trimRight()};';
  }

  /// Double-quote a Postgres identifier (escaping embedded quotes).
  String _ident(String id) => '"${id.replaceAll('"', '""')}"';
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
