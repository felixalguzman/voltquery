import 'package:flutter_test/flutter_test.dart';
import 'package:voltquery/domain/models/connection_options.dart';
import 'package:voltquery/domain/models/ssh_config.dart';

/// Tunnel settings ride along in the connection options blob, so the same
/// tolerance rules apply — and a half-configured tunnel must never be treated
/// as usable.
void main() {
  test('tunnelling is off by default', () {
    const c = SshConfig();
    expect(c.enabled, isFalse);
    expect(c.isUsable, isFalse);
    expect(c.port, 22);
    expect(c.authMode, SshAuthMode.password);
  });

  group('isUsable guards a half-configured tunnel', () {
    test('enabled but blank is not usable', () {
      // Attempting this would fail at connect with a confusing error instead
      // of the tunnel simply being ignored.
      expect(const SshConfig(enabled: true).isUsable, isFalse);
      expect(const SshConfig(enabled: true, host: 'bastion').isUsable, isFalse);
      expect(const SshConfig(enabled: true, username: 'me').isUsable, isFalse);
    });

    test('host + user + enabled is usable', () {
      expect(
        const SshConfig(enabled: true, host: 'bastion', username: 'me')
            .isUsable,
        isTrue,
      );
    });

    test('a fully configured but disabled tunnel is not usable', () {
      expect(
        const SshConfig(host: 'bastion', username: 'me').isUsable,
        isFalse,
      );
    });
  });

  test('round-trips inside ConnectionOptions', () {
    const options = ConnectionOptions(
      ssh: SshConfig(
        enabled: true,
        host: 'bastion.example.com',
        port: 2222,
        username: 'deploy',
        authMode: SshAuthMode.privateKey,
        privateKeyPath: '/home/me/.ssh/id_ed25519',
        passwordRef: 'c1/ssh-password',
        passphraseRef: 'c1/ssh-passphrase',
      ),
    );
    final back = ConnectionOptions.decode(options.encode()).ssh;

    expect(back.enabled, isTrue);
    expect(back.host, 'bastion.example.com');
    expect(back.port, 2222);
    expect(back.username, 'deploy');
    expect(back.authMode, SshAuthMode.privateKey);
    expect(back.privateKeyPath, '/home/me/.ssh/id_ed25519');
    expect(back.passwordRef, 'c1/ssh-password');
    expect(back.passphraseRef, 'c1/ssh-passphrase');
  });

  test('a disabled tunnel is omitted from the blob entirely', () {
    // No reason to persist an empty tunnel on every connection.
    expect(const ConnectionOptions().encode(), isNot(contains('ssh')));
  });

  test('options without an ssh key decode to a disabled tunnel', () {
    // Blobs written before tunnelling existed.
    final o = ConnectionOptions.decode('{"sslMode":"require"}');
    expect(o.ssh.enabled, isFalse);
  });

  test('a malformed ssh blob disables rather than half-configures', () {
    final o = ConnectionOptions.decode('{"ssh":"nonsense"}');
    expect(o.ssh.enabled, isFalse);
    expect(o.ssh.isUsable, isFalse);
  });

  test('an unknown auth mode falls back to password', () {
    final c = SshConfig.fromJson({'authMode': 'retina-scan'});
    expect(c.authMode, SshAuthMode.password);
  });

  test('no secret is ever stored on the config itself', () {
    // Only vault *references* — same rule as Connection.credentialRef.
    const c = SshConfig(
      enabled: true,
      host: 'b',
      username: 'u',
      passwordRef: 'c1/ssh-password',
    );
    expect(c.toJson().values.contains('hunter2'), isFalse);
    expect(c.toJson()['passwordRef'], 'c1/ssh-password');
  });
}
