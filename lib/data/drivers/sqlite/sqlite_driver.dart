import 'package:sqlite3/sqlite3.dart' as sq;

import '../../../domain/drivers/driver.dart';
import '../../../domain/drivers/driver_error.dart';
import '../../../domain/drivers/result.dart';
import '../../../domain/drivers/schema_introspector.dart';
import '../../../domain/models/capabilities.dart';
import '../../../domain/models/connection.dart';
import '../../../domain/models/engine.dart';
import '../../../domain/models/schema.dart';

/// SQLite adapter (ADR-0003) — raw `sqlite3`, not drift: VoltQuery runs
/// arbitrary user SQL against runtime-introspected schemas and needs a row
/// cursor. Behind the [Driver] port; the app never sees `sqlite3` types.
class SqliteDriver implements Driver {
  @override
  Engine get engine => Engine.sqlite;

  @override
  Capabilities get capabilities => const Capabilities(
        hasServer: false,
        hasSchemas: false,
        supportsTls: false,
        supportsQueryCancel: false, // sqlite3_interrupt not exposed
        supportsSavepoints: true, // via raw SAVEPOINT SQL
        supportsNestedTransactions: false,
        paramStyle: ParamStyle.question,
      );

  @override
  Future<Session> connect(Connection config, {String? secret}) async {
    final path = config.sqlitePath;
    final db = switch (path) {
      null || ':memory:' => sq.sqlite3.openInMemory(),
      // `file:...?mode=memory&cache=shared` URIs (shared in-memory) and any
      // other `file:` URI need uri parsing enabled.
      final p when p.startsWith('file:') => sq.sqlite3.open(p, uri: true),
      final p => sq.sqlite3.open(p),
    };
    return SqliteSession(config, db);
  }
}

class SqliteSession implements Session {
  SqliteSession(this._connection, this._db);

  final Connection _connection;
  final sq.Database _db;

  @override
  Connection get connection => _connection;

  @override
  String? get currentDatabase => _connection.defaultDatabase;

  @override
  bool get inTransaction => !_db.autocommit;

  @override
  Future<ExecutionResult> execute(String sql,
      {List<Object?> params = const []}) async {
    try {
      final stmt = _db.prepare(sql);
      final cursor = stmt.selectCursor(params);
      if (cursor.columnNames.isEmpty) {
        // Non-row statement (DML/DDL): step to execute, then report changes.
        while (cursor.moveNext()) {}
        final result = CommandResult(
          affectedRows: _db.updatedRows,
          lastInsertId: _db.lastInsertRowId,
        );
        stmt.dispose();
        return result;
      }
      final fields = <ResultField>[
        for (var i = 0; i < cursor.columnNames.length; i++)
          ResultField(name: cursor.columnNames[i], dataType: '', ordinal: i),
      ];
      return RowsResult(_SqliteResultCursor(stmt, cursor, fields));
    } on sq.SqliteException catch (e) {
      throw _mapSqliteError(e);
    }
  }

  @override
  Future<void> begin() async => _db.execute('BEGIN');
  @override
  Future<void> commit() async => _db.execute('COMMIT');
  @override
  Future<void> rollback() async => _db.execute('ROLLBACK');

  @override
  Future<void> useDatabase(String name) async =>
      throw DriverError(DriverErrorKind.unsupported,
          'SQLite has no server-side database switching');

  @override
  Future<void> cancelActive() async => throw DriverError(
      DriverErrorKind.unsupported, 'SQLite query cancel is not supported');

  @override
  SchemaIntrospector get schema => _SqliteSchemaIntrospector(_db);

  @override
  Future<void> close() async => _db.dispose();
}

/// SQLite introspection — the one place engine-specific catalog queries live
/// (`sqlite_master` + PRAGMA), returning canonical hierarchy nodes (ADR-0001/0008).
class _SqliteSchemaIntrospector implements SchemaIntrospector {
  _SqliteSchemaIntrospector(this._db);

  final sq.Database _db;

  @override
  Future<List<DatabaseInfo>> databases() async => const [DatabaseInfo('main')];

  @override
  Future<List<SchemaInfo>> schemas(DatabaseInfo database) async =>
      const []; // SQLite has no schema level (Capabilities.hasSchemas == false)

  @override
  Future<List<TableInfo>> tables(SchemaInfo schema) async {
    final rs = _db.select(
      "SELECT name, type FROM sqlite_master "
      "WHERE type IN ('table','view') AND name NOT LIKE 'sqlite_%' "
      "ORDER BY name",
    );
    return [
      for (final row in rs)
        TableInfo(
          name: row['name'] as String,
          kind: row['type'] == 'view' ? ObjectKind.view : ObjectKind.table,
        ),
    ];
  }

  @override
  Future<List<ColumnInfo>> columns(TableInfo table) async {
    // PRAGMA can't take bound parameters — interpolate a quoted literal.
    final name = table.name.replaceAll("'", "''");
    final fk = _db.select("PRAGMA foreign_key_list('$name')");
    final fkCols = {for (final r in fk) r['from'] as String};
    final rs = _db.select("PRAGMA table_info('$name')");
    return [
      for (final row in rs)
        ColumnInfo(
          name: row['name'] as String,
          dataType: (row['type'] as String?) ?? '',
          nullable: (row['notnull'] as int) == 0,
          isPrimaryKey: (row['pk'] as int) != 0,
          isForeignKey: fkCols.contains(row['name']),
          ordinal: row['cid'] as int,
          defaultValue: row['dflt_value']?.toString(),
        ),
    ];
  }

  @override
  Future<List<IndexInfo>> indexes(TableInfo table) async {
    final name = table.name.replaceAll("'", "''");
    final list = _db.select("PRAGMA index_list('$name')");
    final result = <IndexInfo>[];
    for (final row in list) {
      final idxName = row['name'] as String;
      final info = _db.select(
          "PRAGMA index_info('${idxName.replaceAll("'", "''")}')");
      result.add(IndexInfo(
        name: idxName,
        // 'name' is null for expression columns — skip those entries.
        columns: [
          for (final c in info)
            if (c['name'] != null) c['name'] as String,
        ],
        unique: (row['unique'] as int) == 1,
      ));
    }
    return result;
  }
}

/// Maps a raw `sqlite3` exception into the normalized [DriverError] taxonomy
/// (ADR-0003) so the UI reacts the same across engines.
DriverError _mapSqliteError(sq.SqliteException e) {
  final msg = e.message.toLowerCase();
  final DriverErrorKind kind;
  if (msg.contains('syntax')) {
    kind = DriverErrorKind.syntaxError;
  } else if (msg.contains('no such table') || msg.contains('no such column')) {
    kind = DriverErrorKind.objectNotFound;
  } else if (msg.contains('constraint')) {
    kind = DriverErrorKind.constraintViolation;
  } else {
    kind = DriverErrorKind.unknown;
  }
  return DriverError(kind, e.message,
      nativeCode: e.resultCode.toString(), cause: e);
}

class _SqliteResultCursor implements ResultCursor {
  _SqliteResultCursor(this._stmt, this._cursor, this.fields);

  final sq.PreparedStatement _stmt;
  final sq.IteratingCursor _cursor;
  bool _hasMore = true;

  @override
  final List<ResultField> fields;

  @override
  bool get hasMore => _hasMore;

  @override
  Future<List<ResultRow>> fetch(int n) async {
    final rows = <ResultRow>[];
    var count = 0;
    while (count < n && _cursor.moveNext()) {
      rows.add(ResultRow(List<Object?>.from(_cursor.current.values)));
      count++;
    }
    if (count < n) _hasMore = false;
    return rows;
  }

  @override
  Future<void> close() async => _stmt.dispose();
}
