import 'package:flutter_test/flutter_test.dart';
import 'package:voltquery/data/repositories/connection_repository.dart';
import 'package:voltquery/data/services/local_store.dart';
import 'package:voltquery/domain/models/connection.dart';
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
}
