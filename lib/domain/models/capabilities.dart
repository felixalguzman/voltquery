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

  /// Postgres only — see [Session.cancelActive].
  final bool supportsQueryCancel;
  final bool supportsSavepoints;

  /// False at the API level for all three launch engines.
  final bool supportsNestedTransactions;
  final ParamStyle paramStyle;
}
