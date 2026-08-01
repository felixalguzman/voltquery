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

class $ConnectionRowsTable extends ConnectionRows
    with TableInfo<$ConnectionRowsTable, ConnectionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConnectionRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
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
  static const VerificationMeta _hostMeta = const VerificationMeta('host');
  @override
  late final GeneratedColumn<String> host = GeneratedColumn<String>(
    'host',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _portMeta = const VerificationMeta('port');
  @override
  late final GeneratedColumn<int> port = GeneratedColumn<int>(
    'port',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _usernameMeta = const VerificationMeta(
    'username',
  );
  @override
  late final GeneratedColumn<String> username = GeneratedColumn<String>(
    'username',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _credentialRefMeta = const VerificationMeta(
    'credentialRef',
  );
  @override
  late final GeneratedColumn<String> credentialRef = GeneratedColumn<String>(
    'credential_ref',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sqlitePathMeta = const VerificationMeta(
    'sqlitePath',
  );
  @override
  late final GeneratedColumn<String> sqlitePath = GeneratedColumn<String>(
    'sqlite_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _defaultDatabaseMeta = const VerificationMeta(
    'defaultDatabase',
  );
  @override
  late final GeneratedColumn<String> defaultDatabase = GeneratedColumn<String>(
    'default_database',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sslModeMeta = const VerificationMeta(
    'sslMode',
  );
  @override
  late final GeneratedColumn<String> sslMode = GeneratedColumn<String>(
    'ssl_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('require'),
  );
  static const VerificationMeta _caCertPathMeta = const VerificationMeta(
    'caCertPath',
  );
  @override
  late final GeneratedColumn<String> caCertPath = GeneratedColumn<String>(
    'ca_cert_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    engine,
    host,
    port,
    username,
    credentialRef,
    sqlitePath,
    defaultDatabase,
    sslMode,
    caCertPath,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'connection_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConnectionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('engine')) {
      context.handle(
        _engineMeta,
        engine.isAcceptableOrUnknown(data['engine']!, _engineMeta),
      );
    } else if (isInserting) {
      context.missing(_engineMeta);
    }
    if (data.containsKey('host')) {
      context.handle(
        _hostMeta,
        host.isAcceptableOrUnknown(data['host']!, _hostMeta),
      );
    }
    if (data.containsKey('port')) {
      context.handle(
        _portMeta,
        port.isAcceptableOrUnknown(data['port']!, _portMeta),
      );
    }
    if (data.containsKey('username')) {
      context.handle(
        _usernameMeta,
        username.isAcceptableOrUnknown(data['username']!, _usernameMeta),
      );
    }
    if (data.containsKey('credential_ref')) {
      context.handle(
        _credentialRefMeta,
        credentialRef.isAcceptableOrUnknown(
          data['credential_ref']!,
          _credentialRefMeta,
        ),
      );
    }
    if (data.containsKey('sqlite_path')) {
      context.handle(
        _sqlitePathMeta,
        sqlitePath.isAcceptableOrUnknown(data['sqlite_path']!, _sqlitePathMeta),
      );
    }
    if (data.containsKey('default_database')) {
      context.handle(
        _defaultDatabaseMeta,
        defaultDatabase.isAcceptableOrUnknown(
          data['default_database']!,
          _defaultDatabaseMeta,
        ),
      );
    }
    if (data.containsKey('ssl_mode')) {
      context.handle(
        _sslModeMeta,
        sslMode.isAcceptableOrUnknown(data['ssl_mode']!, _sslModeMeta),
      );
    }
    if (data.containsKey('ca_cert_path')) {
      context.handle(
        _caCertPathMeta,
        caCertPath.isAcceptableOrUnknown(
          data['ca_cert_path']!,
          _caCertPathMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ConnectionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConnectionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      engine: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}engine'],
      )!,
      host: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}host'],
      ),
      port: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}port'],
      ),
      username: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}username'],
      ),
      credentialRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}credential_ref'],
      ),
      sqlitePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sqlite_path'],
      ),
      defaultDatabase: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}default_database'],
      ),
      sslMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ssl_mode'],
      )!,
      caCertPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ca_cert_path'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ConnectionRowsTable createAlias(String alias) {
    return $ConnectionRowsTable(attachedDatabase, alias);
  }
}

class ConnectionRow extends DataClass implements Insertable<ConnectionRow> {
  final String id;
  final String name;
  final String engine;
  final String? host;
  final int? port;
  final String? username;
  final String? credentialRef;
  final String? sqlitePath;
  final String? defaultDatabase;

  /// [SslMode] name. Existing rows migrate to `require` rather than `disable`:
  /// encryption should be opted out of, not into — and MySQL 8 cannot
  /// authenticate without it.
  final String sslMode;

  /// PEM CA bundle for verify-full against a private/self-signed CA.
  final String? caCertPath;
  final DateTime createdAt;
  const ConnectionRow({
    required this.id,
    required this.name,
    required this.engine,
    this.host,
    this.port,
    this.username,
    this.credentialRef,
    this.sqlitePath,
    this.defaultDatabase,
    required this.sslMode,
    this.caCertPath,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['engine'] = Variable<String>(engine);
    if (!nullToAbsent || host != null) {
      map['host'] = Variable<String>(host);
    }
    if (!nullToAbsent || port != null) {
      map['port'] = Variable<int>(port);
    }
    if (!nullToAbsent || username != null) {
      map['username'] = Variable<String>(username);
    }
    if (!nullToAbsent || credentialRef != null) {
      map['credential_ref'] = Variable<String>(credentialRef);
    }
    if (!nullToAbsent || sqlitePath != null) {
      map['sqlite_path'] = Variable<String>(sqlitePath);
    }
    if (!nullToAbsent || defaultDatabase != null) {
      map['default_database'] = Variable<String>(defaultDatabase);
    }
    map['ssl_mode'] = Variable<String>(sslMode);
    if (!nullToAbsent || caCertPath != null) {
      map['ca_cert_path'] = Variable<String>(caCertPath);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ConnectionRowsCompanion toCompanion(bool nullToAbsent) {
    return ConnectionRowsCompanion(
      id: Value(id),
      name: Value(name),
      engine: Value(engine),
      host: host == null && nullToAbsent ? const Value.absent() : Value(host),
      port: port == null && nullToAbsent ? const Value.absent() : Value(port),
      username: username == null && nullToAbsent
          ? const Value.absent()
          : Value(username),
      credentialRef: credentialRef == null && nullToAbsent
          ? const Value.absent()
          : Value(credentialRef),
      sqlitePath: sqlitePath == null && nullToAbsent
          ? const Value.absent()
          : Value(sqlitePath),
      defaultDatabase: defaultDatabase == null && nullToAbsent
          ? const Value.absent()
          : Value(defaultDatabase),
      sslMode: Value(sslMode),
      caCertPath: caCertPath == null && nullToAbsent
          ? const Value.absent()
          : Value(caCertPath),
      createdAt: Value(createdAt),
    );
  }

  factory ConnectionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConnectionRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      engine: serializer.fromJson<String>(json['engine']),
      host: serializer.fromJson<String?>(json['host']),
      port: serializer.fromJson<int?>(json['port']),
      username: serializer.fromJson<String?>(json['username']),
      credentialRef: serializer.fromJson<String?>(json['credentialRef']),
      sqlitePath: serializer.fromJson<String?>(json['sqlitePath']),
      defaultDatabase: serializer.fromJson<String?>(json['defaultDatabase']),
      sslMode: serializer.fromJson<String>(json['sslMode']),
      caCertPath: serializer.fromJson<String?>(json['caCertPath']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'engine': serializer.toJson<String>(engine),
      'host': serializer.toJson<String?>(host),
      'port': serializer.toJson<int?>(port),
      'username': serializer.toJson<String?>(username),
      'credentialRef': serializer.toJson<String?>(credentialRef),
      'sqlitePath': serializer.toJson<String?>(sqlitePath),
      'defaultDatabase': serializer.toJson<String?>(defaultDatabase),
      'sslMode': serializer.toJson<String>(sslMode),
      'caCertPath': serializer.toJson<String?>(caCertPath),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ConnectionRow copyWith({
    String? id,
    String? name,
    String? engine,
    Value<String?> host = const Value.absent(),
    Value<int?> port = const Value.absent(),
    Value<String?> username = const Value.absent(),
    Value<String?> credentialRef = const Value.absent(),
    Value<String?> sqlitePath = const Value.absent(),
    Value<String?> defaultDatabase = const Value.absent(),
    String? sslMode,
    Value<String?> caCertPath = const Value.absent(),
    DateTime? createdAt,
  }) => ConnectionRow(
    id: id ?? this.id,
    name: name ?? this.name,
    engine: engine ?? this.engine,
    host: host.present ? host.value : this.host,
    port: port.present ? port.value : this.port,
    username: username.present ? username.value : this.username,
    credentialRef: credentialRef.present
        ? credentialRef.value
        : this.credentialRef,
    sqlitePath: sqlitePath.present ? sqlitePath.value : this.sqlitePath,
    defaultDatabase: defaultDatabase.present
        ? defaultDatabase.value
        : this.defaultDatabase,
    sslMode: sslMode ?? this.sslMode,
    caCertPath: caCertPath.present ? caCertPath.value : this.caCertPath,
    createdAt: createdAt ?? this.createdAt,
  );
  ConnectionRow copyWithCompanion(ConnectionRowsCompanion data) {
    return ConnectionRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      engine: data.engine.present ? data.engine.value : this.engine,
      host: data.host.present ? data.host.value : this.host,
      port: data.port.present ? data.port.value : this.port,
      username: data.username.present ? data.username.value : this.username,
      credentialRef: data.credentialRef.present
          ? data.credentialRef.value
          : this.credentialRef,
      sqlitePath: data.sqlitePath.present
          ? data.sqlitePath.value
          : this.sqlitePath,
      defaultDatabase: data.defaultDatabase.present
          ? data.defaultDatabase.value
          : this.defaultDatabase,
      sslMode: data.sslMode.present ? data.sslMode.value : this.sslMode,
      caCertPath: data.caCertPath.present
          ? data.caCertPath.value
          : this.caCertPath,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConnectionRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('engine: $engine, ')
          ..write('host: $host, ')
          ..write('port: $port, ')
          ..write('username: $username, ')
          ..write('credentialRef: $credentialRef, ')
          ..write('sqlitePath: $sqlitePath, ')
          ..write('defaultDatabase: $defaultDatabase, ')
          ..write('sslMode: $sslMode, ')
          ..write('caCertPath: $caCertPath, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    engine,
    host,
    port,
    username,
    credentialRef,
    sqlitePath,
    defaultDatabase,
    sslMode,
    caCertPath,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConnectionRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.engine == this.engine &&
          other.host == this.host &&
          other.port == this.port &&
          other.username == this.username &&
          other.credentialRef == this.credentialRef &&
          other.sqlitePath == this.sqlitePath &&
          other.defaultDatabase == this.defaultDatabase &&
          other.sslMode == this.sslMode &&
          other.caCertPath == this.caCertPath &&
          other.createdAt == this.createdAt);
}

class ConnectionRowsCompanion extends UpdateCompanion<ConnectionRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> engine;
  final Value<String?> host;
  final Value<int?> port;
  final Value<String?> username;
  final Value<String?> credentialRef;
  final Value<String?> sqlitePath;
  final Value<String?> defaultDatabase;
  final Value<String> sslMode;
  final Value<String?> caCertPath;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ConnectionRowsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.engine = const Value.absent(),
    this.host = const Value.absent(),
    this.port = const Value.absent(),
    this.username = const Value.absent(),
    this.credentialRef = const Value.absent(),
    this.sqlitePath = const Value.absent(),
    this.defaultDatabase = const Value.absent(),
    this.sslMode = const Value.absent(),
    this.caCertPath = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConnectionRowsCompanion.insert({
    required String id,
    required String name,
    required String engine,
    this.host = const Value.absent(),
    this.port = const Value.absent(),
    this.username = const Value.absent(),
    this.credentialRef = const Value.absent(),
    this.sqlitePath = const Value.absent(),
    this.defaultDatabase = const Value.absent(),
    this.sslMode = const Value.absent(),
    this.caCertPath = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       engine = Value(engine);
  static Insertable<ConnectionRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? engine,
    Expression<String>? host,
    Expression<int>? port,
    Expression<String>? username,
    Expression<String>? credentialRef,
    Expression<String>? sqlitePath,
    Expression<String>? defaultDatabase,
    Expression<String>? sslMode,
    Expression<String>? caCertPath,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (engine != null) 'engine': engine,
      if (host != null) 'host': host,
      if (port != null) 'port': port,
      if (username != null) 'username': username,
      if (credentialRef != null) 'credential_ref': credentialRef,
      if (sqlitePath != null) 'sqlite_path': sqlitePath,
      if (defaultDatabase != null) 'default_database': defaultDatabase,
      if (sslMode != null) 'ssl_mode': sslMode,
      if (caCertPath != null) 'ca_cert_path': caCertPath,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConnectionRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? engine,
    Value<String?>? host,
    Value<int?>? port,
    Value<String?>? username,
    Value<String?>? credentialRef,
    Value<String?>? sqlitePath,
    Value<String?>? defaultDatabase,
    Value<String>? sslMode,
    Value<String?>? caCertPath,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ConnectionRowsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      engine: engine ?? this.engine,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      credentialRef: credentialRef ?? this.credentialRef,
      sqlitePath: sqlitePath ?? this.sqlitePath,
      defaultDatabase: defaultDatabase ?? this.defaultDatabase,
      sslMode: sslMode ?? this.sslMode,
      caCertPath: caCertPath ?? this.caCertPath,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (engine.present) {
      map['engine'] = Variable<String>(engine.value);
    }
    if (host.present) {
      map['host'] = Variable<String>(host.value);
    }
    if (port.present) {
      map['port'] = Variable<int>(port.value);
    }
    if (username.present) {
      map['username'] = Variable<String>(username.value);
    }
    if (credentialRef.present) {
      map['credential_ref'] = Variable<String>(credentialRef.value);
    }
    if (sqlitePath.present) {
      map['sqlite_path'] = Variable<String>(sqlitePath.value);
    }
    if (defaultDatabase.present) {
      map['default_database'] = Variable<String>(defaultDatabase.value);
    }
    if (sslMode.present) {
      map['ssl_mode'] = Variable<String>(sslMode.value);
    }
    if (caCertPath.present) {
      map['ca_cert_path'] = Variable<String>(caCertPath.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConnectionRowsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('engine: $engine, ')
          ..write('host: $host, ')
          ..write('port: $port, ')
          ..write('username: $username, ')
          ..write('credentialRef: $credentialRef, ')
          ..write('sqlitePath: $sqlitePath, ')
          ..write('defaultDatabase: $defaultDatabase, ')
          ..write('sslMode: $sslMode, ')
          ..write('caCertPath: $caCertPath, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$LocalStore extends GeneratedDatabase {
  _$LocalStore(QueryExecutor e) : super(e);
  $LocalStoreManager get managers => $LocalStoreManager(this);
  late final $HistoryRowsTable historyRows = $HistoryRowsTable(this);
  late final $ConnectionRowsTable connectionRows = $ConnectionRowsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    historyRows,
    connectionRows,
  ];
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
typedef $$ConnectionRowsTableCreateCompanionBuilder =
    ConnectionRowsCompanion Function({
      required String id,
      required String name,
      required String engine,
      Value<String?> host,
      Value<int?> port,
      Value<String?> username,
      Value<String?> credentialRef,
      Value<String?> sqlitePath,
      Value<String?> defaultDatabase,
      Value<String> sslMode,
      Value<String?> caCertPath,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$ConnectionRowsTableUpdateCompanionBuilder =
    ConnectionRowsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> engine,
      Value<String?> host,
      Value<int?> port,
      Value<String?> username,
      Value<String?> credentialRef,
      Value<String?> sqlitePath,
      Value<String?> defaultDatabase,
      Value<String> sslMode,
      Value<String?> caCertPath,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$ConnectionRowsTableFilterComposer
    extends Composer<_$LocalStore, $ConnectionRowsTable> {
  $$ConnectionRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get engine => $composableBuilder(
    column: $table.engine,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get host => $composableBuilder(
    column: $table.host,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get port => $composableBuilder(
    column: $table.port,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get credentialRef => $composableBuilder(
    column: $table.credentialRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sqlitePath => $composableBuilder(
    column: $table.sqlitePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get defaultDatabase => $composableBuilder(
    column: $table.defaultDatabase,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sslMode => $composableBuilder(
    column: $table.sslMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get caCertPath => $composableBuilder(
    column: $table.caCertPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ConnectionRowsTableOrderingComposer
    extends Composer<_$LocalStore, $ConnectionRowsTable> {
  $$ConnectionRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get engine => $composableBuilder(
    column: $table.engine,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get host => $composableBuilder(
    column: $table.host,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get port => $composableBuilder(
    column: $table.port,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get credentialRef => $composableBuilder(
    column: $table.credentialRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sqlitePath => $composableBuilder(
    column: $table.sqlitePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get defaultDatabase => $composableBuilder(
    column: $table.defaultDatabase,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sslMode => $composableBuilder(
    column: $table.sslMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get caCertPath => $composableBuilder(
    column: $table.caCertPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ConnectionRowsTableAnnotationComposer
    extends Composer<_$LocalStore, $ConnectionRowsTable> {
  $$ConnectionRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get engine =>
      $composableBuilder(column: $table.engine, builder: (column) => column);

  GeneratedColumn<String> get host =>
      $composableBuilder(column: $table.host, builder: (column) => column);

  GeneratedColumn<int> get port =>
      $composableBuilder(column: $table.port, builder: (column) => column);

  GeneratedColumn<String> get username =>
      $composableBuilder(column: $table.username, builder: (column) => column);

  GeneratedColumn<String> get credentialRef => $composableBuilder(
    column: $table.credentialRef,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sqlitePath => $composableBuilder(
    column: $table.sqlitePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get defaultDatabase => $composableBuilder(
    column: $table.defaultDatabase,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sslMode =>
      $composableBuilder(column: $table.sslMode, builder: (column) => column);

  GeneratedColumn<String> get caCertPath => $composableBuilder(
    column: $table.caCertPath,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ConnectionRowsTableTableManager
    extends
        RootTableManager<
          _$LocalStore,
          $ConnectionRowsTable,
          ConnectionRow,
          $$ConnectionRowsTableFilterComposer,
          $$ConnectionRowsTableOrderingComposer,
          $$ConnectionRowsTableAnnotationComposer,
          $$ConnectionRowsTableCreateCompanionBuilder,
          $$ConnectionRowsTableUpdateCompanionBuilder,
          (
            ConnectionRow,
            BaseReferences<_$LocalStore, $ConnectionRowsTable, ConnectionRow>,
          ),
          ConnectionRow,
          PrefetchHooks Function()
        > {
  $$ConnectionRowsTableTableManager(_$LocalStore db, $ConnectionRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConnectionRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConnectionRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConnectionRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> engine = const Value.absent(),
                Value<String?> host = const Value.absent(),
                Value<int?> port = const Value.absent(),
                Value<String?> username = const Value.absent(),
                Value<String?> credentialRef = const Value.absent(),
                Value<String?> sqlitePath = const Value.absent(),
                Value<String?> defaultDatabase = const Value.absent(),
                Value<String> sslMode = const Value.absent(),
                Value<String?> caCertPath = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConnectionRowsCompanion(
                id: id,
                name: name,
                engine: engine,
                host: host,
                port: port,
                username: username,
                credentialRef: credentialRef,
                sqlitePath: sqlitePath,
                defaultDatabase: defaultDatabase,
                sslMode: sslMode,
                caCertPath: caCertPath,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String engine,
                Value<String?> host = const Value.absent(),
                Value<int?> port = const Value.absent(),
                Value<String?> username = const Value.absent(),
                Value<String?> credentialRef = const Value.absent(),
                Value<String?> sqlitePath = const Value.absent(),
                Value<String?> defaultDatabase = const Value.absent(),
                Value<String> sslMode = const Value.absent(),
                Value<String?> caCertPath = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConnectionRowsCompanion.insert(
                id: id,
                name: name,
                engine: engine,
                host: host,
                port: port,
                username: username,
                credentialRef: credentialRef,
                sqlitePath: sqlitePath,
                defaultDatabase: defaultDatabase,
                sslMode: sslMode,
                caCertPath: caCertPath,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ConnectionRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalStore,
      $ConnectionRowsTable,
      ConnectionRow,
      $$ConnectionRowsTableFilterComposer,
      $$ConnectionRowsTableOrderingComposer,
      $$ConnectionRowsTableAnnotationComposer,
      $$ConnectionRowsTableCreateCompanionBuilder,
      $$ConnectionRowsTableUpdateCompanionBuilder,
      (
        ConnectionRow,
        BaseReferences<_$LocalStore, $ConnectionRowsTable, ConnectionRow>,
      ),
      ConnectionRow,
      PrefetchHooks Function()
    >;

class $LocalStoreManager {
  final _$LocalStore _db;
  $LocalStoreManager(this._db);
  $$HistoryRowsTableTableManager get historyRows =>
      $$HistoryRowsTableTableManager(_db, _db.historyRows);
  $$ConnectionRowsTableTableManager get connectionRows =>
      $$ConnectionRowsTableTableManager(_db, _db.connectionRows);
}
