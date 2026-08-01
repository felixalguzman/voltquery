import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voltquery/data/services/known_hosts.dart';

/// Trust-on-first-use for SSH bastions. The verdicts are the security contract:
/// an unknown host must prompt, and a *changed* key must be distinguishable
/// from a new one — that difference is the whole point of storing them.
void main() {
  late KnownHostsStore store;

  setUp(() => store = KnownHostsStore.memory());

  const fp = 'ssh-ed25519 SHA256:abc123';
  const other = 'ssh-ed25519 SHA256:zzz999';

  test('an unseen host is unknown, not trusted', () {
    // Defaulting to trusted here would make the whole store pointless.
    expect(store.check('bastion', 22, fp),
        completion(HostKeyVerdict.unknown));
  });

  test('a trusted host with the same key is trusted', () async {
    await store.trust('bastion', 22, fp);
    expect(await store.check('bastion', 22, fp), HostKeyVerdict.trusted);
  });

  test('a different key on a known host reports CHANGED, not unknown',
      () async {
    // "Unknown" reads as routine first contact; "changed" is what a
    // machine-in-the-middle looks like, and has to surface differently.
    await store.trust('bastion', 22, fp);
    expect(await store.check('bastion', 22, other), HostKeyVerdict.changed);
  });

  test('host keys are scoped per host AND port', () async {
    await store.trust('bastion', 22, fp);
    expect(await store.check('bastion', 2222, fp), HostKeyVerdict.unknown);
    expect(await store.check('elsewhere', 22, fp), HostKeyVerdict.unknown);
  });

  test('trusting again replaces the key, so a rekey can be accepted',
      () async {
    await store.trust('bastion', 22, fp);
    await store.trust('bastion', 22, other);
    expect(await store.check('bastion', 22, other), HostKeyVerdict.trusted);
    expect(await store.check('bastion', 22, fp), HostKeyVerdict.changed);
  });

  test('forget returns a host to unknown', () async {
    await store.trust('bastion', 22, fp);
    await store.forget('bastion', 22);
    expect(await store.check('bastion', 22, fp), HostKeyVerdict.unknown);
  });

  group('fingerprints', () {
    test('are the SHA256: form ssh prints, so they can be compared by eye', () {
      final fingerprint = KnownHostsStore.fingerprintOf(
        'ssh-ed25519',
        Uint8List.fromList([1, 2, 3, 4]),
      );
      expect(fingerprint, startsWith('ssh-ed25519 SHA256:'));
      expect(fingerprint, isNot(contains('=')), reason: 'unpadded, like ssh');
    });

    test('differ when the key differs', () {
      final a = KnownHostsStore.fingerprintOf(
          'ssh-rsa', Uint8List.fromList([1, 2, 3]));
      final b = KnownHostsStore.fingerprintOf(
          'ssh-rsa', Uint8List.fromList([1, 2, 4]));
      expect(a, isNot(b));
    });

    test('differ when only the key *type* differs', () {
      // Same bytes under a different algorithm is still a different identity.
      final bytes = Uint8List.fromList([1, 2, 3]);
      expect(
        KnownHostsStore.fingerprintOf('ssh-rsa', bytes),
        isNot(KnownHostsStore.fingerprintOf('ssh-ed25519', bytes)),
      );
    });
  });
}
