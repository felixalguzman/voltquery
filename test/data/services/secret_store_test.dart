import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltquery/data/services/secret_store.dart';

/// Seam: the encrypted vault round-trips secrets and rejects a wrong password.
/// Fast Argon2id params for the test (production uses stronger).
void main() {
  final fastKdf =
      Argon2id(parallelism: 1, memory: 100, iterations: 1, hashLength: 32);

  test('create → write → read; lock hides; wrong password fails', () async {
    final dir = Directory.systemTemp.createTempSync('vq_vault');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/credentials.vault');

    final store = VaultSecretStore(file, kdf: fastKdf);
    expect(store.exists, isFalse);
    expect(store.isLocked, isTrue);

    await store.unlock('master-pw'); // creates the vault
    expect(store.isLocked, isFalse);
    expect(file.existsSync(), isTrue);

    await store.write('conn-1', 's3cr3t-pw');
    expect(await store.read('conn-1'), 's3cr3t-pw');

    store.lock();
    expect(store.isLocked, isTrue);
    expect(await store.read('conn-1'), isNull); // locked → no read

    // Reopen from disk + unlock with the correct password.
    final reopened = VaultSecretStore(file, kdf: fastKdf);
    expect(reopened.exists, isTrue);
    await reopened.unlock('master-pw');
    expect(await reopened.read('conn-1'), 's3cr3t-pw');

    // Wrong password is rejected (AEAD auth failure).
    final wrong = VaultSecretStore(file, kdf: fastKdf);
    await expectLater(
      () => wrong.unlock('nope'),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
  });

  /// Re-keying rewraps the DEK. The contract that matters: the old password
  /// stops working, the new one works, and every stored secret survives — a
  /// password change that silently emptied the vault would be catastrophic and
  /// unnoticed until the next connection.
  group('changeMasterPassword', () {
    late Directory dir;
    late File file;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('vq_vault_rekey');
      file = File('${dir.path}/credentials.vault');
    });
    tearDown(() => dir.deleteSync(recursive: true));

    test('secrets survive; the old password stops working', () async {
      final store = VaultSecretStore(file, kdf: fastKdf);
      await store.unlock('old-pw');
      await store.write('conn-1', 's3cr3t');

      await store.changeMasterPassword('old-pw', 'new-pw');

      // Still usable in this session — the DEK never changed.
      expect(await store.read('conn-1'), 's3cr3t');

      final withNew = VaultSecretStore(file, kdf: fastKdf);
      await withNew.unlock('new-pw');
      expect(await withNew.read('conn-1'), 's3cr3t');

      final withOld = VaultSecretStore(file, kdf: fastKdf);
      await expectLater(
        () => withOld.unlock('old-pw'),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });

    test('a wrong current password changes nothing', () async {
      final store = VaultSecretStore(file, kdf: fastKdf);
      await store.unlock('old-pw');
      await store.write('conn-1', 's3cr3t');

      await expectLater(
        () => store.changeMasterPassword('not-it', 'new-pw'),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );

      // The original password must still open the vault.
      final reopened = VaultSecretStore(file, kdf: fastKdf);
      await reopened.unlock('old-pw');
      expect(await reopened.read('conn-1'), 's3cr3t');
    });

    test('works while locked, and leaves it locked', () async {
      final store = VaultSecretStore(file, kdf: fastKdf);
      await store.unlock('old-pw');
      await store.write('conn-1', 's3cr3t');
      store.lock();

      await store.changeMasterPassword('old-pw', 'new-pw');

      expect(store.isLocked, isTrue);
      await store.unlock('new-pw');
      expect(await store.read('conn-1'), 's3cr3t');
    });

    test('refuses when there is no vault yet', () async {
      final store = VaultSecretStore(file, kdf: fastKdf);
      await expectLater(
        () => store.changeMasterPassword('a', 'b'),
        throwsA(isA<StateError>()),
      );
    });
  });
}
