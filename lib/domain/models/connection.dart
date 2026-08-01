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
    this.sslMode = SslMode.require,
    this.caCertPath,
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

  /// TLS policy for server engines; ignored by SQLite (a local file).
  ///
  /// Defaults to [SslMode.require] rather than `disable`: encryption should be
  /// something you opt *out* of, and MySQL 8 can't authenticate without it.
  final SslMode sslMode;

  /// PEM certificate authority for [SslMode.verifyFull] when the server's CA
  /// isn't in the system trust store (self-signed, private CA). Null = use the
  /// system roots.
  final String? caCertPath;

  Connection copyWith({
    String? name,
    String? host,
    int? port,
    String? username,
    String? credentialRef,
    String? defaultDatabase,
    SslMode? sslMode,
    String? caCertPath,
  }) =>
      Connection(
        id: id,
        name: name ?? this.name,
        engine: engine,
        host: host ?? this.host,
        port: port ?? this.port,
        username: username ?? this.username,
        credentialRef: credentialRef ?? this.credentialRef,
        sqlitePath: sqlitePath,
        defaultDatabase: defaultDatabase ?? this.defaultDatabase,
        sslMode: sslMode ?? this.sslMode,
        caCertPath: caCertPath ?? this.caCertPath,
      );
}
