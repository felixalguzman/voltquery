# Credentials & secret handling

Design output of issue **Credentials & secret handling** (#11). Plan-only.
Security-sensitive. Grounded in the secure-storage research (#4,
`docs/research/secure-storage.md`) and the persistence decision (#10, ref-only).
Recorded in **ADR-0006**.

## Posture (hybrid)

| Platform | Backend | Master password? |
|----------|---------|------------------|
| macOS | Keychain Services (flutter_secure_storage; optional Secure Enclave) | No — OS login |
| Windows | DPAPI / Credential Manager (flutter_secure_storage) | No — OS login |
| Linux | **Encrypted vault file** (`cryptography` Argon2id → AES-256-GCM) | **Yes** |

Linux uses a vault, not the OS keychain: `flutter_secure_storage`'s
libsecret/D-Bus path is documented to hang the UI on Wayland/Hyprland
(issue #1017) — unacceptable on the primary dev platform.

## SecretStore port

One interface, two adapters chosen at startup by platform. Secrets never touch
`voltquery.db` (ADR-0005); they live only here.

```dart
abstract interface class SecretStore {
  // vault lifecycle (no-op / always-unlocked on keychain backends)
  bool get isLocked;
  Future<void> unlock(String masterPassword);   // Linux: derive key, unwrap DEK
  void lock();                                   // drop key from memory
  Future<void> changeMasterPassword(String oldPw, String newPw); // re-wrap DEK only

  // secret CRUD, keyed by the opaque credentialRef stored in connections
  Future<void> write(String credentialRef, Secret secret);
  Future<Secret?> read(String credentialRef);    // may trigger unlock prompt
  Future<void> delete(String credentialRef);
}
```

- `KeychainSecretStore` — flutter_secure_storage, service `com.voltquery.credentials`; `isLocked` always false; `unlock`/`changeMasterPassword` are no-ops.
- `VaultSecretStore` — the Linux encrypted-file implementation below.

## What is a Secret

The DB connection **password**, and a **TLS client-key passphrase** if used.
**Not** secrets (they live in `voltquery.db`): host, port, username, database,
TLS mode, cert *file paths*. SSH tunnels are out of scope.

## credentialRef

A stable UUID generated when a connection's secret is first written.
`connections.credentialRef` holds it (persistence); the SecretStore is keyed by
it. On keychain it is the account key; in the vault it is the map key.

## Linux vault — envelope encryption

A single file `credentials.vault` in the app-support dir (mode `0600`), separate
from `voltquery.db`:

```
header:  version · kdf=Argon2id{salt, memory=64MiB, iterations=3, parallelism=1}
         · wrappedDEK = AES-256-GCM(KEK, DEK){nonce, tag}
entries: { credentialRef -> AES-256-GCM(DEK, secret){nonce, tag} }
```

- **KEK** = Argon2id(masterPassword, salt). Never stored.
- **DEK** = random 256-bit key, stored only **wrapped** by the KEK. Changing the
  master password re-wraps the DEK — no secret is re-encrypted.
- All ciphertext is **AES-256-GCM** (authenticated — tamper-evident).

## Unlock model (Linux)

Prompt for the master password at the **first secret access after launch**;
hold the derived DEK **in memory only** (never on disk) for the session. Optional
**idle auto-lock** (configurable timeout, default off) drops the key and
re-prompts. Quit drops the key. First-ever secret write prompts to **create** the
master password.

Best-effort: zero secret/key buffers after use (Dart GC makes this advisory, not
guaranteed).

## Retrieval at connect time

```
open Worksheet Session (sessionProvider)
  -> resolve Connection from ConnectionRepository (has credentialRef, no secret)
  -> SecretStore.read(credentialRef)      // Linux: unlock if locked (prompt)
  -> Driver.connect(Connection, secret)   // secret passed in, never persisted
```

The persisted `Connection` never carries the secret; it is injected into
`Driver.connect` at call time from the SecretStore.

## Lifecycle

| Action | Effect |
|--------|--------|
| Create connection w/ password | generate `credentialRef`; `SecretStore.write(ref, secret)` |
| Edit password | `SecretStore.write(ref, secret)` (overwrite) |
| Delete connection | `SecretStore.delete(ref)` — the purge #10 coordinates on delete |
| Change master password (Linux) | `changeMasterPassword` re-wraps DEK |
| Test connection | resolve secret + `Driver.connect`, then close |

## Platform build notes (from research)

- **macOS:** `Keychain Sharing` entitlement in all build configs; Secure Enclave optional (`useSecureEnclave`, unavailable on simulators).
- **Windows:** Visual Studio Build Tools with **C++ ATL** at build time.
- **Linux:** no libsecret dependency (vault is pure-Dart `cryptography`) — a deliberate benefit of avoiding the keychain.

## Hand-off

- **Connection management UX** (now graduated) designs the master-password
  create/unlock prompts and the connection wizard's password field.
