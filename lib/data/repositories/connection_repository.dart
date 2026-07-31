import 'package:drift/drift.dart';

import '../../domain/models/connection.dart';
import '../../domain/models/engine.dart';
import '../services/local_store.dart';

/// Single source of truth for **saved** connections (ADR-0004/0005). Secret-free
/// — persists a `credentialRef` only.
class ConnectionRepository {
  ConnectionRepository(this._db);

  final LocalStore _db;

  Stream<List<Connection>> watchAll() {
    final q = _db.select(_db.connectionRows)
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    return q.watch().map((rows) => rows.map(_toDomain).toList());
  }

  Future<void> save(Connection c) {
    return _db.into(_db.connectionRows).insertOnConflictUpdate(
          ConnectionRowsCompanion.insert(
            id: c.id,
            name: c.name,
            engine: c.engine.name,
            host: Value(c.host),
            port: Value(c.port),
            username: Value(c.username),
            credentialRef: Value(c.credentialRef),
            sqlitePath: Value(c.sqlitePath),
            defaultDatabase: Value(c.defaultDatabase),
          ),
        );
  }

  Future<void> delete(String id) =>
      (_db.delete(_db.connectionRows)..where((t) => t.id.equals(id))).go();

  Connection _toDomain(ConnectionRow r) => Connection(
        id: r.id,
        name: r.name,
        engine: Engine.values.byName(r.engine),
        host: r.host,
        port: r.port,
        username: r.username,
        credentialRef: r.credentialRef,
        sqlitePath: r.sqlitePath,
        defaultDatabase: r.defaultDatabase,
      );
}
