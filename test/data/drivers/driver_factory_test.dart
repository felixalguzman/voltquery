import 'package:flutter_test/flutter_test.dart';
import 'package:voltquery/data/drivers/driver_factory.dart';
import 'package:voltquery/data/drivers/mysql/mysql_driver.dart';
import 'package:voltquery/data/drivers/postgres/postgres_driver.dart';
import 'package:voltquery/data/drivers/sqlite/sqlite_driver.dart';
import 'package:voltquery/domain/models/capabilities.dart';
import 'package:voltquery/domain/models/engine.dart';

/// Server engines need a live server, so integration is verified manually; here
/// we test what's server-free: the factory + capabilities.
void main() {
  test('driverFor picks the driver for each engine', () {
    expect(driverFor(Engine.sqlite), isA<SqliteDriver>());
    expect(driverFor(Engine.postgres), isA<PostgresDriver>());
    expect(driverFor(Engine.mysql), isA<MysqlDriver>());
  });

  test('MySQL capabilities: server + schemas (Database==Schema), no cancel', () {
    final c = MysqlDriver().capabilities;
    expect(c.hasServer, isTrue);
    // MySQL treats SCHEMA and DATABASE as synonyms, so the schema level *is*
    // the database list. Reporting true is what lets a connection with no
    // default database still be browsed — and any database be reached, not
    // just the default one.
    expect(c.hasSchemas, isTrue);
    expect(c.supportsQueryCancel, isFalse);
    expect(c.paramStyle, ParamStyle.question);
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
