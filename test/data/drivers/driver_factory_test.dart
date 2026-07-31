import 'package:flutter_test/flutter_test.dart';
import 'package:voltquery/data/drivers/driver_factory.dart';
import 'package:voltquery/data/drivers/postgres/postgres_driver.dart';
import 'package:voltquery/data/drivers/sqlite/sqlite_driver.dart';
import 'package:voltquery/domain/models/capabilities.dart';
import 'package:voltquery/domain/models/engine.dart';

/// Postgres needs a live server, so integration is verified manually; here we
/// test what's server-free: the factory + capabilities.
void main() {
  test('driverFor picks the driver for each engine', () {
    expect(driverFor(Engine.sqlite), isA<SqliteDriver>());
    expect(driverFor(Engine.postgres), isA<PostgresDriver>());
  });

  test('Postgres capabilities: server + schemas; cancel gated off in v3.5.12', () {
    final c = PostgresDriver().capabilities;
    expect(c.hasServer, isTrue);
    expect(c.hasSchemas, isTrue);
    expect(c.supportsQueryCancel, isFalse);
    expect(c.paramStyle, ParamStyle.dollar);
  });

  test('SQLite and Postgres differ on hierarchy capabilities', () {
    expect(SqliteDriver().capabilities.hasServer, isFalse);
    expect(SqliteDriver().capabilities.hasSchemas, isFalse);
    expect(PostgresDriver().capabilities.hasServer, isTrue);
  });
}
