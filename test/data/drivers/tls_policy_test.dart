import 'package:flutter_test/flutter_test.dart';
import 'package:voltquery/data/drivers/driver_factory.dart';
import 'package:voltquery/data/drivers/mysql/mysql_driver.dart';
import 'package:voltquery/domain/drivers/driver_error.dart';
import 'package:voltquery/domain/models/connection.dart';
import 'package:voltquery/domain/models/engine.dart';
import 'package:voltquery/domain/models/ssl_mode.dart';

/// TLS policy at the driver seam. The important guarantee here is negative:
/// a driver that cannot verify certificates must refuse to *claim* it did.
void main() {
  test('encryption is opt-out, not opt-in', () {
    // A connection built without saying anything about TLS is encrypted.
    const c = Connection(id: 'x', name: 'x', engine: Engine.postgres);
    expect(c.sslMode, SslMode.require);
  });

  test('only disable turns encryption off', () {
    expect(SslMode.disable.enabled, isFalse);
    expect(SslMode.require.enabled, isTrue);
    expect(SslMode.verifyFull.enabled, isTrue);
  });

  test('unknown/legacy persisted values fall back to require, not disable', () {
    // Rows written before the TLS column existed must not silently downgrade.
    expect(SslMode.byName(null), SslMode.require);
    expect(SslMode.byName('nonsense'), SslMode.require);
    expect(SslMode.byName('disable'), SslMode.disable);
    expect(SslMode.byName('verifyFull'), SslMode.verifyFull);
  });

  group('capabilities describe what each driver can actually honour', () {
    test('postgres can verify certificates', () {
      final caps = driverFor(Engine.postgres).capabilities;
      expect(caps.supportsTls, isTrue);
      expect(caps.verifiesTlsCertificates, isTrue);
    });

    test('mysql supports TLS but cannot verify', () {
      // mysql_client calls SecureSocket.secure(onBadCertificate: (_) => true).
      final caps = driverFor(Engine.mysql).capabilities;
      expect(caps.supportsTls, isTrue);
      expect(caps.verifiesTlsCertificates, isFalse);
    });

    test('sqlite has no transport at all', () {
      final caps = driverFor(Engine.sqlite).capabilities;
      expect(caps.supportsTls, isFalse);
      expect(caps.verifiesTlsCertificates, isFalse);
    });
  });

  test('MySQL refuses verify-full rather than silently not verifying',
      () async {
    // The whole point: connecting and reporting success would assert a
    // verified channel the driver never verified.
    const c = Connection(
      id: 'x',
      name: 'x',
      engine: Engine.mysql,
      host: 'localhost',
      sslMode: SslMode.verifyFull,
    );
    await expectLater(
      MysqlDriver().connect(c),
      throwsA(isA<DriverError>()
          .having((e) => e.kind, 'kind', DriverErrorKind.unsupported)
          .having((e) => e.message, 'message', contains('verify'))),
    );
  });
}
