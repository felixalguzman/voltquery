/// How an engine writes SQL statement placeholders. The driver translates.
enum ParamStyle { dollar, question, named }

/// Per-Engine feature flags the app reads instead of `switch`-ing on [Engine].
///
/// Enforces ADR-0001 (uniform hierarchy) / ADR-0003 (driver abstraction):
/// consumers branch on capabilities, never on the concrete engine.
/// See `docs/design/driver-abstraction.md`.
class Capabilities {
  const Capabilities({
    required this.hasServer,
    required this.hasSchemas,
    required this.supportsTls,
    required this.verifiesTlsCertificates,
    required this.supportsQueryCancel,
    required this.supportsSavepoints,
    required this.supportsNestedTransactions,
    required this.paramStyle,
  });

  /// False for SQLite (a file *is* the database).
  final bool hasServer;

  /// True for Postgres; MySQL folds Schema into Database; SQLite has neither.
  final bool hasSchemas;
  final bool supportsTls;

  /// Whether the driver can actually *verify* a server certificate.
  ///
  /// False for MySQL: `mysql_client` hardcodes
  /// `SecureSocket.secure(onBadCertificate: (_) => true)`, so its TLS is
  /// encrypted but unauthenticated. Offering "verify full" there would be a
  /// security claim the driver cannot honour, so the UI hides it and the driver
  /// refuses it outright rather than downgrading silently.
  final bool verifiesTlsCertificates;

  /// Postgres only — see [Session.cancelActive].
  final bool supportsQueryCancel;
  final bool supportsSavepoints;

  /// False at the API level for all three launch engines.
  final bool supportsNestedTransactions;
  final ParamStyle paramStyle;
}
