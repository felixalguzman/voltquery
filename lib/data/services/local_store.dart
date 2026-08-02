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

  /// [HistorySource] name. Defaults to `editor` so rows written before this
  /// column existed — all of which were worksheet runs — stay correct.
  TextColumn get source =>
      text().withDefault(const Constant('editor'))();
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

  /// [SslMode] name. **Superseded by [options]** in schema v4 and read only by
  /// the v3→v4 migration; kept so that migration has something to read.
  TextColumn get sslMode =>
      text().withDefault(const Constant('require'))();

  /// Superseded by [options] — see [sslMode].
  TextColumn get caCertPath => text().nullable()();

  /// `ConnectionOptions` as JSON.
  ///
  /// One column rather than one per setting: connection options are a long
  /// tail (timeouts, colour tags, engine pass-through properties), and a
  /// migration per knob would be all cost and no benefit. The fields the app
  /// branches on are still typed — inside the decoded object.
  TextColumn get options => text().withDefault(const Constant('{}'))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// App settings as typed key-value (`docs/design/persistence.md`): one row per
/// top-level setting, [value] a JSON-encoded scalar.
///
/// A row per setting rather than one blob (which is what [ConnectionRows.options]
/// does) because these are written one knob at a time from a settings pane, and
/// because a key this build doesn't know must survive a round-trip through an
/// older version rather than be dropped by a whole-object rewrite.
class SettingsRows extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// The app's own **drift** store — `voltquery.db` in the app-support dir.
/// Secret-free (ADR-0005). Uses drift here (fixed compile-time schema), not the
/// raw `sqlite3` we use for arbitrary *user* databases (ADR-0003).
@DriftDatabase(tables: [HistoryRows, ConnectionRows, SettingsRows])
class LocalStore extends _$LocalStore {
  LocalStore() : super(_openFile());

  /// In-memory store for tests.
  LocalStore.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) await m.createTable(connectionRows);
          if (from < 3) {
            await m.addColumn(connectionRows, connectionRows.sslMode);
            await m.addColumn(connectionRows, connectionRows.caCertPath);
          }
          if (from < 4) {
            await m.addColumn(connectionRows, connectionRows.options);
            // Carry the v3 TLS columns into the options blob rather than
            // letting them fall back to defaults — silently resetting someone's
            // verify-full connection to `require` on upgrade would be a
            // security downgrade they never asked for.
            await customStatement(
              "UPDATE connection_rows SET options = json_object("
              "'sslMode', COALESCE(ssl_mode, 'require'), "
              "'caCertPath', ca_cert_path, "
              "'enforceForeignKeys', json('true'), "
              "'readOnly', json('false'), "
              "'connectTimeoutSeconds', 15)",
            );
          }
          if (from < 5) await m.createTable(settingsRows);
          if (from < 6) await m.addColumn(historyRows, historyRows.source);
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
