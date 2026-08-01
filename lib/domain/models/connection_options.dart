import 'dart:convert';

import 'ssl_mode.dart';

/// Per-connection settings that aren't part of *reaching* the server.
///
/// Kept apart from [Connection]'s address fields (host/port/user/database) so
/// the connection dialog can be tabbed instead of one ever-growing flat form,
/// and so adding a setting doesn't mean a schema migration every time: the
/// whole object serializes to one JSON column.
///
/// Typed fields are for things the app *branches on*; [driverProperties] is the
/// long tail — engine-specific knobs we pass through without understanding
/// (DBeaver's "Driver properties" tab is the same idea, and is genuinely used
/// for things like `application_name` or `connect_timeout`).
class ConnectionOptions {
  const ConnectionOptions({
    this.sslMode = SslMode.require,
    this.caCertPath,
    this.enforceForeignKeys = true,
    this.colorTag,
    this.readOnly = false,
    this.connectTimeoutSeconds = 15,
    this.driverProperties = const {},
  });

  /// TLS policy. See [SslMode] — the default is `require`, so encryption is
  /// opted out of rather than into.
  final SslMode sslMode;

  /// PEM CA for [SslMode.verifyFull] against a private or self-signed CA.
  final String? caCertPath;

  /// SQLite only. `PRAGMA foreign_keys` defaults **off** per connection, which
  /// makes a declared FK unenforced — an edit pointing at a nonexistent parent
  /// row is written silently, where Postgres and MySQL reject it. On by
  /// default so the schema means what it says; configurable because an existing
  /// database may already hold rows that violate its own constraints, and
  /// enforcement would then block otherwise-valid edits.
  final bool enforceForeignKeys;

  /// ARGB colour marking this connection in the UI — the conventional
  /// red-means-production cue. Null = untagged.
  final int? colorTag;

  /// Refuse writes from the grid's edit path for this connection.
  ///
  /// A UI-level guard, not a server-side one: it stops *this app* generating
  /// DML, it does not make the account read-only. Useful on production
  /// connections alongside a colour tag.
  final bool readOnly;

  final int connectTimeoutSeconds;

  /// Engine-specific pass-through settings, applied verbatim by the driver.
  final Map<String, String> driverProperties;

  ConnectionOptions copyWith({
    SslMode? sslMode,
    String? caCertPath,
    bool? enforceForeignKeys,
    int? colorTag,
    bool? readOnly,
    int? connectTimeoutSeconds,
    Map<String, String>? driverProperties,
  }) =>
      ConnectionOptions(
        sslMode: sslMode ?? this.sslMode,
        caCertPath: caCertPath ?? this.caCertPath,
        enforceForeignKeys: enforceForeignKeys ?? this.enforceForeignKeys,
        colorTag: colorTag ?? this.colorTag,
        readOnly: readOnly ?? this.readOnly,
        connectTimeoutSeconds:
            connectTimeoutSeconds ?? this.connectTimeoutSeconds,
        driverProperties: driverProperties ?? this.driverProperties,
      );

  Map<String, Object?> toJson() => {
        'sslMode': sslMode.name,
        if (caCertPath != null) 'caCertPath': caCertPath,
        'enforceForeignKeys': enforceForeignKeys,
        if (colorTag != null) 'colorTag': colorTag,
        'readOnly': readOnly,
        'connectTimeoutSeconds': connectTimeoutSeconds,
        if (driverProperties.isNotEmpty) 'driverProperties': driverProperties,
      };

  /// Tolerant by design: a row written by an older (or newer) build must still
  /// open. Anything missing or malformed falls back to the default rather than
  /// failing the connection — except TLS, whose fallback is deliberately
  /// `require` so a corrupt value can never silently downgrade to plaintext.
  factory ConnectionOptions.fromJson(Map<String, Object?> json) {
    return ConnectionOptions(
      sslMode: SslMode.byName(json['sslMode'] as String?),
      caCertPath: json['caCertPath'] as String?,
      enforceForeignKeys: json['enforceForeignKeys'] as bool? ?? true,
      colorTag: json['colorTag'] as int?,
      readOnly: json['readOnly'] as bool? ?? false,
      connectTimeoutSeconds: json['connectTimeoutSeconds'] as int? ?? 15,
      driverProperties: switch (json['driverProperties']) {
        final Map<String, Object?> m => {
            for (final e in m.entries) e.key: '${e.value}',
          },
        _ => const {},
      },
    );
  }

  String encode() => jsonEncode(toJson());

  /// Decodes a stored blob. Null, empty or unparseable input yields defaults —
  /// a connection is still usable if its options are unreadable.
  static ConnectionOptions decode(String? raw) {
    if (raw == null || raw.isEmpty) return const ConnectionOptions();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) return const ConnectionOptions();
      return ConnectionOptions.fromJson(decoded);
    } catch (_) {
      return const ConnectionOptions();
    }
  }
}
