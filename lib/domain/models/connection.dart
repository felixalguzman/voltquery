import 'connection_options.dart';
import 'engine.dart';
import 'ssl_mode.dart';

/// A saved, **cold** profile for reaching a Server. Holds **no secret** — only a
/// [credentialRef] into the SecretStore (ADR-0005 ref-only / ADR-0006). The
/// secret is injected into [Driver.connect] at call time, never persisted here.
///
/// See `CONTEXT.md` and `docs/design/persistence.md`.
///
/// TODO(build): promote to a `freezed` immutable model once codegen is wired.
class Connection {
  const Connection({
    required this.id,
    required this.name,
    required this.engine,
    this.host,
    this.port,
    this.username,
    this.credentialRef,
    this.sqlitePath,
    this.defaultDatabase,
    this.options = const ConnectionOptions(),
  });

  final String id;
  final String name;
  final Engine engine;

  // Server engines (Postgres / MySQL):
  final String? host;
  final int? port;
  final String? username;

  /// Opaque key into the SecretStore — **never** the secret itself.
  final String? credentialRef;

  /// SQLite only.
  final String? sqlitePath;

  final String? defaultDatabase;

  /// Everything that isn't part of *reaching* the server — TLS, timeouts, the
  /// colour tag, engine pass-through properties. Grouped so the dialog can be
  /// tabbed and so adding a setting doesn't mean a schema migration.
  final ConnectionOptions options;

  // Convenience delegates: the drivers care about these specifically, and
  // routing through `options` at every call site would only add noise.
  SslMode get sslMode => options.sslMode;
  String? get caCertPath => options.caCertPath;

  Connection copyWith({
    String? name,
    String? host,
    int? port,
    String? username,
    String? credentialRef,
    String? defaultDatabase,
    ConnectionOptions? options,
  }) => Connection(
    id: id,
    name: name ?? this.name,
    engine: engine,
    host: host ?? this.host,
    port: port ?? this.port,
    username: username ?? this.username,
    credentialRef: credentialRef ?? this.credentialRef,
    sqlitePath: sqlitePath,
    defaultDatabase: defaultDatabase ?? this.defaultDatabase,
    options: options ?? this.options,
  );
}
