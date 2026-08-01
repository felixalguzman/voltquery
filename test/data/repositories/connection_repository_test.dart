import 'package:flutter_test/flutter_test.dart';
import 'package:voltquery/data/repositories/connection_repository.dart';
import 'package:voltquery/data/services/local_store.dart';
import 'package:voltquery/domain/models/connection.dart';
import 'package:voltquery/domain/models/ssl_mode.dart';
import 'package:voltquery/domain/models/connection_options.dart';
import 'package:voltquery/domain/models/engine.dart';

/// Seam: ConnectionRepository over an in-memory drift LocalStore.
void main() {
  test('saved connections persist, list, and delete', () async {
    final db = LocalStore.memory();
    addTearDown(db.close);
    final repo = ConnectionRepository(db);

    await repo.save(const Connection(
      id: 'c1',
      name: 'mydb.sqlite',
      engine: Engine.sqlite,
      sqlitePath: '/tmp/mydb.sqlite',
    ));

    final all = await repo.watchAll().first;
    expect(all, hasLength(1));
    expect(all.first.name, 'mydb.sqlite');
    expect(all.first.sqlitePath, '/tmp/mydb.sqlite');
    expect(all.first.engine, Engine.sqlite);

    await repo.delete('c1');
    expect(await repo.watchAll().first, isEmpty);
  });

  test('saving an existing id updates in place, keeping identity', () async {
    final db = LocalStore.memory();
    addTearDown(db.close);
    final repo = ConnectionRepository(db);

    // The edit path reuses the id so the vault entry and history stay attached;
    // an insert-instead-of-update here would silently orphan both.
    const original = Connection(
      id: 'c1',
      name: 'Prod',
      engine: Engine.postgres,
      host: 'db.internal',
      port: 5432,
      username: 'app',
      credentialRef: 'c1',
      options: ConnectionOptions(sslMode: SslMode.verifyFull),
    );
    await repo.save(original);

    await repo.save(original.copyWith(
      name: 'Production',
      host: 'db.example.com',
      options: const ConnectionOptions(
        sslMode: SslMode.require,
        colorTag: 0xFFFF6B6B,
      ),
    ));

    final all = await repo.watchAll().first;
    expect(all, hasLength(1), reason: 'updated, not duplicated');
    final c = all.single;
    expect(c.id, 'c1');
    expect(c.credentialRef, 'c1', reason: 'vault entry stays attached');
    expect(c.name, 'Production');
    expect(c.host, 'db.example.com');
    expect(c.options.sslMode, SslMode.require);
    expect(c.options.colorTag, 0xFFFF6B6B);
  });

  test('connection options survive a round trip through the store', () async {
    final db = LocalStore.memory();
    addTearDown(db.close);
    final repo = ConnectionRepository(db);

    const c = Connection(
      id: 'c2',
      name: 'Tagged',
      engine: Engine.mysql,
      options: ConnectionOptions(
        sslMode: SslMode.disable,
        enforceForeignKeys: false,
        colorTag: 0xFF6FE39A,
        readOnly: true,
        connectTimeoutSeconds: 42,
        driverProperties: {'application_name': 'voltquery'},
      ),
    );
    await repo.save(c);

    final back = (await repo.watchAll().first).single.options;
    expect(back.sslMode, SslMode.disable);
    expect(back.enforceForeignKeys, isFalse);
    expect(back.colorTag, 0xFF6FE39A);
    expect(back.readOnly, isTrue);
    expect(back.connectTimeoutSeconds, 42);
    expect(back.driverProperties, {'application_name': 'voltquery'});
  });
}
