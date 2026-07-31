/// Normalized error kinds so the UI reacts the same across engines.
/// Each driver maps its native exception (SQLSTATE / errno / sqlite code) in.
/// See `docs/design/driver-abstraction.md`.
enum DriverErrorKind {
  connectionFailed,
  authFailed,
  tlsError,
  timeout,
  canceled,
  syntaxError,
  permissionDenied,
  constraintViolation,
  objectNotFound,
  serverError,
  unsupported,
  unknown,
}

/// An engine exception normalized to a uniform shape.
class DriverError implements Exception {
  DriverError(this.kind, this.message, {this.nativeCode, this.cause});

  final DriverErrorKind kind;
  final String message;

  /// The engine's native code: SQLSTATE (Postgres) / errno (MySQL) / result code (SQLite).
  final String? nativeCode;

  /// The original exception, for logging.
  final Object? cause;

  @override
  String toString() =>
      'DriverError(${kind.name}: $message${nativeCode == null ? '' : ' [$nativeCode]'})';
}
