// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_store.dart';

// ignore_for_file: type=lint
class $HistoryRowsTable extends HistoryRows
    with TableInfo<$HistoryRowsTable, HistoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HistoryRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _connectionNameMeta = const VerificationMeta(
    'connectionName',
  );
  @override
  late final GeneratedColumn<String> connectionName = GeneratedColumn<String>(
    'connection_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _engineMeta = const VerificationMeta('engine');
  @override
  late final GeneratedColumn<String> engine = GeneratedColumn<String>(
    'engine',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _databaseNameMeta = const VerificationMeta(
    'databaseName',
  );
  @override
  late final GeneratedColumn<String> databaseName = GeneratedColumn<String>(
    'database_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sqlMeta = const VerificationMeta('sql');
  @override
  late final GeneratedColumn<String> sql = GeneratedColumn<String>(
    'sql',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rowCountMeta = const VerificationMeta(
    'rowCount',
  );
  @override
  late final GeneratedColumn<int> rowCount = GeneratedColumn<int>(
    'row_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorKindMeta = const VerificationMeta(
    'errorKind',
  );
  @override
  late final GeneratedColumn<String> errorKind = GeneratedColumn<String>(
    'error_kind',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorMessageMeta = const VerificationMeta(
    'errorMessage',
  );
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
    'error_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    connectionName,
    engine,
    databaseName,
    sql,
    startedAt,
    durationMs,
    status,
    rowCount,
    errorKind,
    errorMessage,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'history_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<HistoryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('connection_name')) {
      context.handle(
        _connectionNameMeta,
        connectionName.isAcceptableOrUnknown(
          data['connection_name']!,
          _connectionNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_connectionNameMeta);
    }
    if (data.containsKey('engine')) {
      context.handle(
        _engineMeta,
        engine.isAcceptableOrUnknown(data['engine']!, _engineMeta),
      );
    } else if (isInserting) {
      context.missing(_engineMeta);
    }
    if (data.containsKey('database_name')) {
      context.handle(
        _databaseNameMeta,
        databaseName.isAcceptableOrUnknown(
          data['database_name']!,
          _databaseNameMeta,
        ),
      );
    }
    if (data.containsKey('sql')) {
      context.handle(
        _sqlMeta,
        sql.isAcceptableOrUnknown(data['sql']!, _sqlMeta),
      );
    } else if (isInserting) {
      context.missing(_sqlMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    } else if (isInserting) {
      context.missing(_durationMsMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('row_count')) {
      context.handle(
        _rowCountMeta,
        rowCount.isAcceptableOrUnknown(data['row_count']!, _rowCountMeta),
      );
    }
    if (data.containsKey('error_kind')) {
      context.handle(
        _errorKindMeta,
        errorKind.isAcceptableOrUnknown(data['error_kind']!, _errorKindMeta),
      );
    }
    if (data.containsKey('error_message')) {
      context.handle(
        _errorMessageMeta,
        errorMessage.isAcceptableOrUnknown(
          data['error_message']!,
          _errorMessageMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HistoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HistoryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      connectionName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}connection_name'],
      )!,
      engine: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}engine'],
      )!,
      databaseName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}database_name'],
      ),
      sql: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sql'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      rowCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}row_count'],
      ),
      errorKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_kind'],
      ),
      errorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_message'],
      ),
    );
  }

  @override
  $HistoryRowsTable createAlias(String alias) {
    return $HistoryRowsTable(attachedDatabase, alias);
  }
}

class HistoryRow extends DataClass implements Insertable<HistoryRow> {
  final int id;
  final String connectionName;
  final String engine;
  final String? databaseName;
  final String sql;
  final DateTime startedAt;
  final int durationMs;
  final String status;
  final int? rowCount;
  final String? errorKind;
  final String? errorMessage;
  const HistoryRow({
    required this.id,
    required this.connectionName,
    required this.engine,
    this.databaseName,
    required this.sql,
    required this.startedAt,
    required this.durationMs,
    required this.status,
    this.rowCount,
    this.errorKind,
    this.errorMessage,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['connection_name'] = Variable<String>(connectionName);
    map['engine'] = Variable<String>(engine);
    if (!nullToAbsent || databaseName != null) {
      map['database_name'] = Variable<String>(databaseName);
    }
    map['sql'] = Variable<String>(sql);
    map['started_at'] = Variable<DateTime>(startedAt);
    map['duration_ms'] = Variable<int>(durationMs);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || rowCount != null) {
      map['row_count'] = Variable<int>(rowCount);
    }
    if (!nullToAbsent || errorKind != null) {
      map['error_kind'] = Variable<String>(errorKind);
    }
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    return map;
  }

  HistoryRowsCompanion toCompanion(bool nullToAbsent) {
    return HistoryRowsCompanion(
      id: Value(id),
      connectionName: Value(connectionName),
      engine: Value(engine),
      databaseName: databaseName == null && nullToAbsent
          ? const Value.absent()
          : Value(databaseName),
      sql: Value(sql),
      startedAt: Value(startedAt),
      durationMs: Value(durationMs),
      status: Value(status),
      rowCount: rowCount == null && nullToAbsent
          ? const Value.absent()
          : Value(rowCount),
      errorKind: errorKind == null && nullToAbsent
          ? const Value.absent()
          : Value(errorKind),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
    );
  }

  factory HistoryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HistoryRow(
      id: serializer.fromJson<int>(json['id']),
      connectionName: serializer.fromJson<String>(json['connectionName']),
      engine: serializer.fromJson<String>(json['engine']),
      databaseName: serializer.fromJson<String?>(json['databaseName']),
      sql: serializer.fromJson<String>(json['sql']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      status: serializer.fromJson<String>(json['status']),
      rowCount: serializer.fromJson<int?>(json['rowCount']),
      errorKind: serializer.fromJson<String?>(json['errorKind']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'connectionName': serializer.toJson<String>(connectionName),
      'engine': serializer.toJson<String>(engine),
      'databaseName': serializer.toJson<String?>(databaseName),
      'sql': serializer.toJson<String>(sql),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'durationMs': serializer.toJson<int>(durationMs),
      'status': serializer.toJson<String>(status),
      'rowCount': serializer.toJson<int?>(rowCount),
      'errorKind': serializer.toJson<String?>(errorKind),
      'errorMessage': serializer.toJson<String?>(errorMessage),
    };
  }

  HistoryRow copyWith({
    int? id,
    String? connectionName,
    String? engine,
    Value<String?> databaseName = const Value.absent(),
    String? sql,
    DateTime? startedAt,
    int? durationMs,
    String? status,
    Value<int?> rowCount = const Value.absent(),
    Value<String?> errorKind = const Value.absent(),
    Value<String?> errorMessage = const Value.absent(),
  }) => HistoryRow(
    id: id ?? this.id,
    connectionName: connectionName ?? this.connectionName,
    engine: engine ?? this.engine,
    databaseName: databaseName.present ? databaseName.value : this.databaseName,
    sql: sql ?? this.sql,
    startedAt: startedAt ?? this.startedAt,
    durationMs: durationMs ?? this.durationMs,
    status: status ?? this.status,
    rowCount: rowCount.present ? rowCount.value : this.rowCount,
    errorKind: errorKind.present ? errorKind.value : this.errorKind,
    errorMessage: errorMessage.present ? errorMessage.value : this.errorMessage,
  );
  HistoryRow copyWithCompanion(HistoryRowsCompanion data) {
    return HistoryRow(
      id: data.id.present ? data.id.value : this.id,
      connectionName: data.connectionName.present
          ? data.connectionName.value
          : this.connectionName,
      engine: data.engine.present ? data.engine.value : this.engine,
      databaseName: data.databaseName.present
          ? data.databaseName.value
          : this.databaseName,
      sql: data.sql.present ? data.sql.value : this.sql,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      status: data.status.present ? data.status.value : this.status,
      rowCount: data.rowCount.present ? data.rowCount.value : this.rowCount,
      errorKind: data.errorKind.present ? data.errorKind.value : this.errorKind,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HistoryRow(')
          ..write('id: $id, ')
          ..write('connectionName: $connectionName, ')
          ..write('engine: $engine, ')
          ..write('databaseName: $databaseName, ')
          ..write('sql: $sql, ')
          ..write('startedAt: $startedAt, ')
          ..write('durationMs: $durationMs, ')
          ..write('status: $status, ')
          ..write('rowCount: $rowCount, ')
          ..write('errorKind: $errorKind, ')
          ..write('errorMessage: $errorMessage')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    connectionName,
    engine,
    databaseName,
    sql,
    startedAt,
    durationMs,
    status,
    rowCount,
    errorKind,
    errorMessage,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HistoryRow &&
          other.id == this.id &&
          other.connectionName == this.connectionName &&
          other.engine == this.engine &&
          other.databaseName == this.databaseName &&
          other.sql == this.sql &&
          other.startedAt == this.startedAt &&
          other.durationMs == this.durationMs &&
          other.status == this.status &&
          other.rowCount == this.rowCount &&
          other.errorKind == this.errorKind &&
          other.errorMessage == this.errorMessage);
}

class HistoryRowsCompanion extends UpdateCompanion<HistoryRow> {
  final Value<int> id;
  final Value<String> connectionName;
  final Value<String> engine;
  final Value<String?> databaseName;
  final Value<String> sql;
  final Value<DateTime> startedAt;
  final Value<int> durationMs;
  final Value<String> status;
  final Value<int?> rowCount;
  final Value<String?> errorKind;
  final Value<String?> errorMessage;
  const HistoryRowsCompanion({
    this.id = const Value.absent(),
    this.connectionName = const Value.absent(),
    this.engine = const Value.absent(),
    this.databaseName = const Value.absent(),
    this.sql = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.status = const Value.absent(),
    this.rowCount = const Value.absent(),
    this.errorKind = const Value.absent(),
    this.errorMessage = const Value.absent(),
  });
  HistoryRowsCompanion.insert({
    this.id = const Value.absent(),
    required String connectionName,
    required String engine,
    this.databaseName = const Value.absent(),
    required String sql,
    required DateTime startedAt,
    required int durationMs,
    required String status,
    this.rowCount = const Value.absent(),
    this.errorKind = const Value.absent(),
    this.errorMessage = const Value.absent(),
  }) : connectionName = Value(connectionName),
       engine = Value(engine),
       sql = Value(sql),
       startedAt = Value(startedAt),
       durationMs = Value(durationMs),
       status = Value(status);
  static Insertable<HistoryRow> custom({
    Expression<int>? id,
    Expression<String>? connectionName,
    Expression<String>? engine,
    Expression<String>? databaseName,
    Expression<String>? sql,
    Expression<DateTime>? startedAt,
    Expression<int>? durationMs,
    Expression<String>? status,
    Expression<int>? rowCount,
    Expression<String>? errorKind,
    Expression<String>? errorMessage,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (connectionName != null) 'connection_name': connectionName,
      if (engine != null) 'engine': engine,
      if (databaseName != null) 'database_name': databaseName,
      if (sql != null) 'sql': sql,
      if (startedAt != null) 'started_at': startedAt,
      if (durationMs != null) 'duration_ms': durationMs,
      if (status != null) 'status': status,
      if (rowCount != null) 'row_count': rowCount,
      if (errorKind != null) 'error_kind': errorKind,
      if (errorMessage != null) 'error_message': errorMessage,
    });
  }

  HistoryRowsCompanion copyWith({
    Value<int>? id,
    Value<String>? connectionName,
    Value<String>? engine,
    Value<String?>? databaseName,
    Value<String>? sql,
    Value<DateTime>? startedAt,
    Value<int>? durationMs,
    Value<String>? status,
    Value<int?>? rowCount,
    Value<String?>? errorKind,
    Value<String?>? errorMessage,
  }) {
    return HistoryRowsCompanion(
      id: id ?? this.id,
      connectionName: connectionName ?? this.connectionName,
      engine: engine ?? this.engine,
      databaseName: databaseName ?? this.databaseName,
      sql: sql ?? this.sql,
      startedAt: startedAt ?? this.startedAt,
      durationMs: durationMs ?? this.durationMs,
      status: status ?? this.status,
      rowCount: rowCount ?? this.rowCount,
      errorKind: errorKind ?? this.errorKind,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (connectionName.present) {
      map['connection_name'] = Variable<String>(connectionName.value);
    }
    if (engine.present) {
      map['engine'] = Variable<String>(engine.value);
    }
    if (databaseName.present) {
      map['database_name'] = Variable<String>(databaseName.value);
    }
    if (sql.present) {
      map['sql'] = Variable<String>(sql.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (rowCount.present) {
      map['row_count'] = Variable<int>(rowCount.value);
    }
    if (errorKind.present) {
      map['error_kind'] = Variable<String>(errorKind.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HistoryRowsCompanion(')
          ..write('id: $id, ')
          ..write('connectionName: $connectionName, ')
          ..write('engine: $engine, ')
          ..write('databaseName: $databaseName, ')
          ..write('sql: $sql, ')
          ..write('startedAt: $startedAt, ')
          ..write('durationMs: $durationMs, ')
          ..write('status: $status, ')
          ..write('rowCount: $rowCount, ')
          ..write('errorKind: $errorKind, ')
          ..write('errorMessage: $errorMessage')
          ..write(')'))
        .toString();
  }
}

abstract class _$LocalStore extends GeneratedDatabase {
  _$LocalStore(QueryExecutor e) : super(e);
  $LocalStoreManager get managers => $LocalStoreManager(this);
  late final $HistoryRowsTable historyRows = $HistoryRowsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [historyRows];
}

typedef $$HistoryRowsTableCreateCompanionBuilder =
    HistoryRowsCompanion Function({
      Value<int> id,
      required String connectionName,
      required String engine,
      Value<String?> databaseName,
      required String sql,
      required DateTime startedAt,
      required int durationMs,
      required String status,
      Value<int?> rowCount,
      Value<String?> errorKind,
      Value<String?> errorMessage,
    });
typedef $$HistoryRowsTableUpdateCompanionBuilder =
    HistoryRowsCompanion Function({
      Value<int> id,
      Value<String> connectionName,
      Value<String> engine,
      Value<String?> databaseName,
      Value<String> sql,
      Value<DateTime> startedAt,
      Value<int> durationMs,
      Value<String> status,
      Value<int?> rowCount,
      Value<String?> errorKind,
      Value<String?> errorMessage,
    });

class $$HistoryRowsTableFilterComposer
    extends Composer<_$LocalStore, $HistoryRowsTable> {
  $$HistoryRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get connectionName => $composableBuilder(
    column: $table.connectionName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get engine => $composableBuilder(
    column: $table.engine,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get databaseName => $composableBuilder(
    column: $table.databaseName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sql => $composableBuilder(
    column: $table.sql,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rowCount => $composableBuilder(
    column: $table.rowCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorKind => $composableBuilder(
    column: $table.errorKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HistoryRowsTableOrderingComposer
    extends Composer<_$LocalStore, $HistoryRowsTable> {
  $$HistoryRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get connectionName => $composableBuilder(
    column: $table.connectionName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get engine => $composableBuilder(
    column: $table.engine,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get databaseName => $composableBuilder(
    column: $table.databaseName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sql => $composableBuilder(
    column: $table.sql,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rowCount => $composableBuilder(
    column: $table.rowCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorKind => $composableBuilder(
    column: $table.errorKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HistoryRowsTableAnnotationComposer
    extends Composer<_$LocalStore, $HistoryRowsTable> {
  $$HistoryRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get connectionName => $composableBuilder(
    column: $table.connectionName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get engine =>
      $composableBuilder(column: $table.engine, builder: (column) => column);

  GeneratedColumn<String> get databaseName => $composableBuilder(
    column: $table.databaseName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sql =>
      $composableBuilder(column: $table.sql, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get rowCount =>
      $composableBuilder(column: $table.rowCount, builder: (column) => column);

  GeneratedColumn<String> get errorKind =>
      $composableBuilder(column: $table.errorKind, builder: (column) => column);

  GeneratedColumn<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => column,
  );
}

class $$HistoryRowsTableTableManager
    extends
        RootTableManager<
          _$LocalStore,
          $HistoryRowsTable,
          HistoryRow,
          $$HistoryRowsTableFilterComposer,
          $$HistoryRowsTableOrderingComposer,
          $$HistoryRowsTableAnnotationComposer,
          $$HistoryRowsTableCreateCompanionBuilder,
          $$HistoryRowsTableUpdateCompanionBuilder,
          (
            HistoryRow,
            BaseReferences<_$LocalStore, $HistoryRowsTable, HistoryRow>,
          ),
          HistoryRow,
          PrefetchHooks Function()
        > {
  $$HistoryRowsTableTableManager(_$LocalStore db, $HistoryRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HistoryRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HistoryRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HistoryRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> connectionName = const Value.absent(),
                Value<String> engine = const Value.absent(),
                Value<String?> databaseName = const Value.absent(),
                Value<String> sql = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int?> rowCount = const Value.absent(),
                Value<String?> errorKind = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
              }) => HistoryRowsCompanion(
                id: id,
                connectionName: connectionName,
                engine: engine,
                databaseName: databaseName,
                sql: sql,
                startedAt: startedAt,
                durationMs: durationMs,
                status: status,
                rowCount: rowCount,
                errorKind: errorKind,
                errorMessage: errorMessage,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String connectionName,
                required String engine,
                Value<String?> databaseName = const Value.absent(),
                required String sql,
                required DateTime startedAt,
                required int durationMs,
                required String status,
                Value<int?> rowCount = const Value.absent(),
                Value<String?> errorKind = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
              }) => HistoryRowsCompanion.insert(
                id: id,
                connectionName: connectionName,
                engine: engine,
                databaseName: databaseName,
                sql: sql,
                startedAt: startedAt,
                durationMs: durationMs,
                status: status,
                rowCount: rowCount,
                errorKind: errorKind,
                errorMessage: errorMessage,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HistoryRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalStore,
      $HistoryRowsTable,
      HistoryRow,
      $$HistoryRowsTableFilterComposer,
      $$HistoryRowsTableOrderingComposer,
      $$HistoryRowsTableAnnotationComposer,
      $$HistoryRowsTableCreateCompanionBuilder,
      $$HistoryRowsTableUpdateCompanionBuilder,
      (HistoryRow, BaseReferences<_$LocalStore, $HistoryRowsTable, HistoryRow>),
      HistoryRow,
      PrefetchHooks Function()
    >;

class $LocalStoreManager {
  final _$LocalStore _db;
  $LocalStoreManager(this._db);
  $$HistoryRowsTableTableManager get historyRows =>
      $$HistoryRowsTableTableManager(_db, _db.historyRows);
}
