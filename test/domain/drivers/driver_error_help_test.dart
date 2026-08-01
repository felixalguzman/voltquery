import 'package:flutter_test/flutter_test.dart';
import 'package:voltquery/domain/drivers/driver_error.dart';
import 'package:voltquery/domain/drivers/driver_error_help.dart';
import 'package:voltquery/domain/models/engine.dart';
import 'package:voltquery/domain/models/ssl_mode.dart';

/// Driver messages are written for whoever wrote the driver. This layer turns
/// them into something the person looking at the dialog can act on.
void main() {
  const pg = DriverErrorHelper(Engine.postgres);
  const mysql = DriverErrorHelper(Engine.mysql);

  test('a server without TLS gets a one-click fix, not a Dart API', () {
    // The postgres package literally answers this with
    // "use `ConnectionSettings(sslMode: SslMode.disable)`" — a constructor the
    // user cannot reach from a dialog.
    final help = pg.help(DriverError(
      DriverErrorKind.serverError,
      'Server does not support SSL, but it was required (default '
      'configuration). To disable secure connections, use '
      '`ConnectionSettings(sslMode: SslMode.disable)`.',
    ));

    expect(help.headline, isNot(contains('ConnectionSettings')));
    expect(help.headline, contains("doesn't accept encrypted"));
    expect(help.hint, contains('Security tab'));
    expect(help.remedy, ErrorRemedy.setSslDisable);
    expect(DriverErrorHelper.modeFor(help.remedy!), SslMode.disable);
  });

  test('MySQL demanding encryption is fixable in the other direction', () {
    final help = mysql.help(DriverError(
      DriverErrorKind.serverError,
      'Auth plugin caching_sha2_password is supported only with secure '
      'connections',
    ));
    expect(help.remedy, ErrorRemedy.setSslRequire);
    expect(DriverErrorHelper.modeFor(help.remedy!), SslMode.require);
  });

  test('a certificate failure explains both ways out, offers neither', () {
    // Auto-switching to unverified TLS would silently weaken security, so this
    // one is explained rather than "fixed".
    final help = pg.help(
      DriverError(DriverErrorKind.connectionFailed, 'certificate verify failed'),
    );
    expect(help.headline, contains('certificate'));
    expect(help.hint, contains('CA'));
    expect(help.remedy, isNull);
  });

  group('unreachable servers are diagnosed by cause', () {
    String? hintFor(String message) => pg
        .help(DriverError(DriverErrorKind.connectionFailed, message))
        .hint;

    test('refused', () {
      expect(hintFor('Connection refused'), contains('Nothing is listening'));
    });

    test('timeout', () {
      expect(hintFor('Connection timed out'), contains('firewall'));
    });

    test('bad hostname', () {
      expect(hintFor('Failed host lookup: nope.invalid'),
          contains('could not be resolved'));
    });

    test('anything else still gets usable advice', () {
      expect(hintFor('something odd'), contains('host, port'));
    });
  });

  test('error kinds without a special case still get plain language', () {
    expect(pg.help(DriverError(DriverErrorKind.authFailed, 'FATAL: password'))
        .headline, contains('rejected these credentials'));
    expect(pg.help(DriverError(DriverErrorKind.permissionDenied, 'denied'))
        .headline, contains('lacks permission'));
    expect(pg.help(DriverError(DriverErrorKind.objectNotFound, 'no db'))
        .headline, contains('does not exist'));
  });

  test('an unknown failure never shows an empty headline', () {
    final help = pg.help(DriverError(DriverErrorKind.unknown, ''));
    expect(help.headline, isNotEmpty);
  });
}
