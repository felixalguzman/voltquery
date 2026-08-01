import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'local_store.g.dart';

/// Query history rows (ADR-0005). Denormalized `connectionName`/`engine` so an
/// entry stays readable after its connection is deleted.
class HistoryRows extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get connectionName => text()();
  TextColumn get engine => text()();
  TextColumn get databaseName => text().nullable()();
  TextColumn get sql => text()();
  DateTimeColumn get startedAt => dateTime()();
  IntColumn get durationMs => integer()();
  TextColumn get status => text()();
  IntColumn get rowCount => integer().nullable()();
  TextColumn get errorKind => text().nullable()();
  TextColumn get errorMessage => text().nullable()();
}

/// Saved connections (ADR-0005). **Secret-free** — [credentialRef] is an opaque
/// key into the credentials layer, never a secret. Schema-ready columns exist
/// even where the SQLite-only UI doesn't use them yet.
class ConnectionRows extends Table {
  TextColumn get id => text()(); // uuid
  TextColumn get name => text()();
  TextColumn get engine => text()();
  TextColumn get host => text().nullable()();
  IntColumn get port => integer().nullable()();
  TextColumn get username => text().nullable()();
  TextColumn get credentialRef => text().nullable()();
  TextColumn get sqlitePath => text().nullable()();
  TextColumn get defaultDatabase => text().nullable()();

  /// [SslMode] name. Existing rows migrate to `require` rather than `disable`:
  /// encryption should be opted out of, not into — and MySQL 8 cannot
  /// authenticate without it.
  TextColumn get sslMode =>
      text().withDefault(const Constant('require'))();

  /// PEM CA bundle for verify-full against a private/self-signed CA.
  TextColumn get caCertPath => text().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// The app's own **drift** store — `voltquery.db` in the app-support dir.
/// Secret-free (ADR-0005). Uses drift here (fixed compile-time schema), not the
/// raw `sqlite3` we use for arbitrary *user* databases (ADR-0003).
@DriftDatabase(tables: [HistoryRows, ConnectionRows])
class LocalStore extends _$LocalStore {
  LocalStore() : super(_openFile());

  /// In-memory store for tests.
  LocalStore.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) await m.createTable(connectionRows);
          if (from < 3) {
            await m.addColumn(connectionRows, connectionRows.sslMode);
            await m.addColumn(connectionRows, connectionRows.caCertPath);
          }
        },
      );
}

LazyDatabase _openFile() {
  return LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'VoltQuery', 'voltquery.db'));
    await file.parent.create(recursive: true);
    return NativeDatabase.createInBackground(file);
  });
}
