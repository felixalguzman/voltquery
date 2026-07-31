import '../../domain/drivers/driver.dart';
import '../../domain/models/engine.dart';
import 'postgres/postgres_driver.dart';
import 'sqlite/sqlite_driver.dart';

/// Picks the [Driver] for an [Engine]. The one place engine → driver is chosen;
/// everything else codes against the port (ADR-0003).
Driver driverFor(Engine engine) => switch (engine) {
      Engine.sqlite => SqliteDriver(),
      Engine.postgres => PostgresDriver(),
      Engine.mysql => throw UnimplementedError('MySQL driver — later slice'),
    };
