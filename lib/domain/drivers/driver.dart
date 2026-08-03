import '../models/capabilities.dart';
import '../models/connection.dart';
import '../models/engine.dart';
import 'result.dart';
import 'schema_introspector.dart';

/// The unified interface the app codes against so Postgres / MySQL / SQLite are
/// interchangeable. The app **never** branches on [Engine]; per-engine
/// differences hide inside a driver or surface as [Capabilities]. ADR-0003.
///
/// Concrete adapters live in `data/drivers/{postgres,mysql,sqlite}`.
abstract interface class Driver {
  Engine get engine;
  Capabilities get capabilities;

  /// Opens a live [Session]. [secret] is resolved from the SecretStore at call
  /// time (ADR-0006) and never stored on the [Connection].
  Future<Session> connect(Connection config, {String? secret});
}

/// The live, hot runtime of an open [Connection]. Never persisted. `CONTEXT.md`.
abstract interface class Session {
  Connection get connection;
  String? get currentDatabase;
  bool get inTransaction;

  /// The single entry point — returns a [RowsResult] (row-returning) or a
  /// [CommandResult] (DML/DDL). The caller can't pre-classify arbitrary SQL.
  Future<ExecutionResult> execute(
    String sql, {
    List<Object?> params = const [],
  });

  // Minimal transaction primitives (ADR-0007). Higher orchestration lives in
  // the query_workspace view-models, not here.
  Future<void> begin();
  Future<void> commit();
  Future<void> rollback();
  Future<void> useDatabase(String name);

  /// Cancels the in-flight statement. Only meaningful when
  /// [Capabilities.supportsQueryCancel]; otherwise throws
  /// `DriverError(DriverErrorKind.unsupported)` (Postgres-only true cancel).
  Future<void> cancelActive();

  SchemaIntrospector get schema;

  Future<void> close();
}
