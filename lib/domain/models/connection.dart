import 'engine.dart';

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
}
