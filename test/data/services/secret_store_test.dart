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
}
