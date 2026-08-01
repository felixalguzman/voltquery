import 'package:flutter_test/flutter_test.dart';
import 'package:voltquery/data/services/ssh_tunnel.dart';
import 'package:voltquery/domain/drivers/driver_error.dart';
import 'package:voltquery/domain/models/ssh_config.dart';

/// The tunnel's failure path. A bastion that can't be reached has to surface as
/// a normalized DriverError naming SSH — not a raw SocketException that the
/// connection dialog would then blame on the database.
void main() {
  test('an unreachable bastion fails as a DriverError mentioning SSH',
      () async {
    await expectLater(
      SshTunnel.open(
        // Port 1 on loopback: nothing listens there, so this fails fast
        // without depending on the network or DNS.
        config: const SshConfig(
          enabled: true,
          host: '127.0.0.1',
          port: 1,
          username: 'nobody',
        ),
        targetHost: 'db.internal',
        targetPort: 5432,
        password: 'irrelevant',
        timeout: const Duration(seconds: 2),
      ),
      throwsA(
        isA<DriverError>()
            .having((e) => e.kind, 'kind', DriverErrorKind.connectionFailed)
            .having((e) => e.message, 'message', contains('SSH tunnel'))
            // The bastion address, so it's obvious which hop failed.
            .having((e) => e.message, 'message', contains('127.0.0.1:1')),
      ),
    );
  });

  test('private-key auth without a key file is refused before connecting',
      () async {
    await expectLater(
      SshTunnel.open(
        config: const SshConfig(
          enabled: true,
          host: '127.0.0.1',
          port: 1,
          username: 'nobody',
          authMode: SshAuthMode.privateKey,
          // privateKeyPath deliberately absent.
        ),
        targetHost: 'db.internal',
        targetPort: 5432,
        timeout: const Duration(seconds: 2),
      ),
      throwsA(isA<DriverError>()),
    );
  });
}
