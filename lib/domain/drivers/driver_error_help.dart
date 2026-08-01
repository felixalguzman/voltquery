import '../models/engine.dart';
import '../models/ssl_mode.dart';
import 'driver_error.dart';

/// A remedy the UI can apply for the user, rather than describing.
enum ErrorRemedy {
  /// Turn TLS off — the server doesn't speak it.
  setSslDisable,

  /// Turn TLS on — the server (or its auth plugin) insists on it.
  setSslRequire,
}

/// A driver failure translated into something worth showing a human.
class DriverErrorHelp {
  const DriverErrorHelp({
    required this.headline,
    this.hint,
    this.remedy,
    this.remedyLabel,
  });

  /// One line, plain language, no package internals.
  final String headline;

  /// What to try, when we can say something specific.
  final String? hint;

  /// A one-click fix, when the app can apply it.
  final ErrorRemedy? remedy;
  final String? remedyLabel;
}

/// Turns a [DriverError] into guidance.
///
/// Driver messages are written for whoever wrote the driver: the postgres
/// package answers "server does not support SSL" with `ConnectionSettings(
/// sslMode: SslMode.disable)` — a Dart API the user can't reach and shouldn't
/// have to know. The raw text is still worth keeping (it's what you paste into
/// a search), but it belongs *behind* an explanation of what to actually do.
///
/// Matching is on message content because the underlying packages don't expose
/// structured codes for most of these. Unmatched errors fall through to the
/// kind's generic guidance rather than guessing.
class DriverErrorHelper {
  const DriverErrorHelper(this.engine);

  final Engine engine;

  DriverErrorHelp help(DriverError error) {
    final text = error.message.toLowerCase();

    // TLS mismatches — both directions, both one-click fixable.
    if (text.contains('does not support ssl') ||
        text.contains('server does not support ssl')) {
      return const DriverErrorHelp(
        headline: "This server doesn't accept encrypted connections.",
        hint: 'It was reached, but it has TLS turned off. Set TLS to '
            '"Disabled" on the Security tab, or enable TLS on the server.',
        remedy: ErrorRemedy.setSslDisable,
        remedyLabel: 'Set TLS to Disabled',
      );
    }
    if (text.contains('caching_sha2_password') ||
        (text.contains('secure connection') && text.contains('supported'))) {
      return const DriverErrorHelp(
        headline: 'This account requires an encrypted connection.',
        hint: "MySQL's default password plugin refuses to authenticate over "
            'plaintext. Set TLS to "Required" on the Security tab.',
        remedy: ErrorRemedy.setSslRequire,
        remedyLabel: 'Set TLS to Required',
      );
    }
    if (text.contains('certificate')) {
      return const DriverErrorHelp(
        headline: "The server's TLS certificate could not be verified.",
        hint: 'Supply the issuing CA on the Security tab, or use "Required" '
            'to encrypt without verifying (safe on localhost, not across a '
            'network).',
      );
    }

    return switch (error.kind) {
      DriverErrorKind.authFailed => const DriverErrorHelp(
          headline: 'The server rejected these credentials.',
          hint: 'Check the username and password. On an edited connection, '
              'leaving the password blank keeps the previously saved one.',
        ),
      DriverErrorKind.connectionFailed => DriverErrorHelp(
          headline: "Couldn't reach the server.",
          hint: _unreachableHint(text),
        ),
      DriverErrorKind.objectNotFound => const DriverErrorHelp(
          headline: 'The database or object does not exist.',
          hint: 'Check the database name — on this server it is '
              'case-sensitive.',
        ),
      DriverErrorKind.permissionDenied => const DriverErrorHelp(
          headline: 'This account lacks permission for that.',
          hint: 'The connection worked; the account is missing a grant.',
        ),
      DriverErrorKind.syntaxError => const DriverErrorHelp(
          headline: 'The server could not parse that statement.',
        ),
      DriverErrorKind.constraintViolation => const DriverErrorHelp(
          headline: 'The change violates a constraint.',
          hint: 'A unique, foreign-key or check constraint rejected it.',
        ),
      DriverErrorKind.unsupported => DriverErrorHelp(
          headline: 'Not supported by this driver.',
          hint: error.message,
        ),
      _ => const DriverErrorHelp(headline: 'The server returned an error.'),
    };
  }

  String _unreachableHint(String text) {
    if (text.contains('refused')) {
      return 'Nothing is listening on that host and port. Is the server '
          'running, and is the port right?';
    }
    if (text.contains('timed out') || text.contains('timeout')) {
      return 'The host did not respond in time — often a firewall, or a '
          'server that is only reachable through a tunnel.';
    }
    if (text.contains('lookup') ||
        text.contains('no such host') ||
        text.contains('resolve')) {
      return 'That hostname could not be resolved. Check it for typos.';
    }
    return 'Check the host, port, and that the server is running.';
  }

  /// The mode a remedy switches to.
  static SslMode? modeFor(ErrorRemedy remedy) => switch (remedy) {
        ErrorRemedy.setSslDisable => SslMode.disable,
        ErrorRemedy.setSslRequire => SslMode.require,
      };
}
