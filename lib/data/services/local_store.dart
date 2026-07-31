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

/// The app's own **drift** store — `voltquery.db` in the app-support dir.
/// Secret-free (ADR-0005). Uses drift here (fixed compile-time schema), not the
/// raw `sqlite3` we use for arbitrary *user* databases (ADR-0003).
@DriftDatabase(tables: [HistoryRows])
class LocalStore extends _$LocalStore {
  LocalStore() : super(_openFile());

  /// In-memory store for tests.
  LocalStore.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openFile() {
  return LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'VoltQuery', 'voltquery.db'));
    await file.parent.create(recursive: true);
    return NativeDatabase.createInBackground(file);
  });
}
