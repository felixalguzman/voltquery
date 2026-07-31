# Research: desktop secure credential storage

> Resolves #4

---

## 1. flutter_secure_storage — per-platform support table

**Package:** [flutter_secure_storage 10.3.1](https://pub.dev/packages/flutter_secure_storage)  
**Pub score:** 150 pts · 4.47k likes · 3.37M downloads  
**Last published:** ~2 months ago (v10.3.1); v11.0.0-beta.1 prerelease available  
**Null safety:** Yes  
**Publisher:** steenbakker.dev (verified)

| Platform | Backend | Native API | Runtime Dependency | Notes |
|----------|---------|------------|-------------------|-------|
| Linux | libsecret / Secret Service (D-Bus) | `secret_password_store_sync`, `secret_service_search_sync`, `secret_password_clear_sync` (via libsecret C API) | `libsecret-1-0` at runtime; `libsecret-1-dev` at build time | Requires a running Secret Service daemon (gnome-keyring, kwallet, or compatible); Flatpak support via `org.freedesktop.Platform` runtime 25.08+ |
| macOS | Apple Keychain Services | `SecItem*` family (SecItemAdd, SecItemCopyMatching, etc.); optional Secure Enclave via `kSecAttrTokenIDSecureEnclave` | None (framework bundled with macOS) | Requires `Keychain Sharing` capability in entitlements; `kSecUseDataProtectionKeychain` enabled when available; `useSecureEnclave` option wraps AES key in EC private key stored in Secure Enclave hardware |
| Windows | DPAPI / Credential Manager | C++ ATL + Win32 credential storage APIs | C++ ATL libraries from Visual Studio Build Tools (build-time) | README references DPAPI and Credential Manager but does not document exact Win32 symbol names |
| iOS | Apple Keychain Services | `SecItem*` family | None | Hot-restart on physical device may return null without proper Keychain Sharing entitlements |
| Android | Android Keystore + EncryptedSharedPreferences | Jetpack Security (pre-v10), Android Keystore System (v10+) | Min SDK 23 (Android 6.0+) | Auto-backup must be disabled to prevent `InvalidKeyException` |
| Web | Web Crypto API (browser) | Requires HTTPS or localhost | None (browser API) | Susceptible to XSS; HSTS headers required |

Sources: [pub.dev README](https://pub.dev/packages/flutter_secure_storage), [GitHub README (develop branch)](https://raw.githubusercontent.com/mogol/flutter_secure_storage/develop/README.md), [Linux plugin source](https://github.com/mogol/flutter_secure_storage/blob/develop/flutter_secure_storage_linux/linux/flutter_secure_storage_linux_plugin.cc)

---

## 2. Runtime / native dependency notes

### Linux — libsecret and the Secret Service

libsecret is a GLib-based client library that communicates with a Secret Service implementation (most commonly `gnome-keyring` or KDE's `ksecretservice`) over **D-Bus** ([libsecret GitLab](https://gitlab.gnome.org/GNOME/libsecret)). The GNOME wiki describes it as: *"a library for storing and retrieving passwords and other secrets. It communicates with the 'Secret Service' using D-Bus."* ([GNOME Projects/Libsecret](https://wiki.gnome.org/Projects/Libsecret))

**What this means in practice:**

- The binary must link against `libsecret-1.so` (package `libsecret-1-0` on Debian/Ubuntu, `libsecret` on Arch/Fedora). Without this `.so` the app fails to launch.
- At runtime a D-Bus session bus **and** a running Secret Service daemon are required. On a headless Linux host (CI runners, Docker containers, servers) neither is present by default.
- The flutter_secure_storage Linux plugin wraps errors from the daemon. The source contains a `catch (const gchar *e)` block that checks for `"KeyringLocked"` and converts it to an error response, so the app does not hard-crash — but all read/write calls will return errors or hang when no daemon is available ([plugin source](https://github.com/mogol/flutter_secure_storage/blob/develop/flutter_secure_storage_linux/linux/flutter_secure_storage_linux_plugin.cc)).
- Issue [#1017](https://github.com/mogol/flutter_secure_storage/issues/1017) documents a case where `.read()` and `.write()` **hang the UI indefinitely** on Arch Linux with Wayland/Hyprland even when `gnome-keyring` and `libsecret` packages are installed, spanning multiple plugin and Flutter versions. This suggests the D-Bus handshake can block rather than time-out gracefully.

**CI workaround:** Run `gnome-keyring-daemon --unlock` or `dbus-run-session` in the CI job, or mock the storage layer.

### macOS — Keychain Services entitlements

- All build configurations (`DebugProfile.entitlements`, `Release.entitlements`) must include the `Keychain Sharing` capability ([README](https://raw.githubusercontent.com/mogol/flutter_secure_storage/develop/README.md)).
- For multi-app access, the App Group identifier must be added to keychain access groups.
- The Secure Enclave path (`useSecureEnclave: true`) is unavailable on simulators; the plugin falls back to standard Keychain automatically.

### Windows — ATL requirement

- Visual Studio Build Tools with C++ ATL selected must be installed on the build machine. This is a **build-time** requirement, not a runtime `.dll` dependency for end users. ([README](https://raw.githubusercontent.com/mogol/flutter_secure_storage/develop/README.md))

---

## 3. Known gaps and limitations

### Per-platform, sourced from README and GitHub issues

**Linux**
- Requires `gnome-keyring`, `kwallet`, or another XDG Secret Service implementation — not present by default on minimal distros, servers, or CI containers ([README](https://raw.githubusercontent.com/mogol/flutter_secure_storage/develop/README.md)).
- Open issue [#1017](https://github.com/mogol/flutter_secure_storage/issues/1017): UI-blocking hang on Wayland/Hyprland even with keyring installed — unresolved as of search date.
- Open issue [#778](https://github.com/mogol/flutter_secure_storage/issues/778): `libsecret_error: Failed to unlock the keyring` warning.
- Open issue [#1181](https://github.com/mogol/flutter_secure_storage/issues/1181): `xdg:schema` (libsecret schema name) attribute set incorrectly — may affect portability across Secret Service implementations.
- Open issue [#1203](https://github.com/mogol/flutter_secure_storage/issues/1203): No support for XDG Desktop Secret Portal (`org.freedesktop.portal.Secret`), which is the recommended path for Flatpak sandboxed apps.
- Historical issues (closed): `D-Bus AccessDenied` (#309), `read always returns null` (#353), Fedora compilation errors (#957, #958).

**macOS**
- Missing `Keychain Sharing` entitlement causes silent null returns or exceptions — entitlement must be manually added to all build configs ([README](https://raw.githubusercontent.com/mogol/flutter_secure_storage/develop/README.md)).
- Secure Enclave unavailable on simulators.

**Windows**
- C++ ATL libraries must be explicitly selected during Visual Studio Build Tools installation; the default install does not include them ([README](https://raw.githubusercontent.com/mogol/flutter_secure_storage/develop/README.md)).
- No documented details on DPAPI vs Credential Manager selection criteria.

**General**
- The package is moving toward v11 (beta); v10 API may change.
- No built-in key derivation — the package stores bytes; callers are responsible for what they store.

---

## 4. Encrypted-file alternative assessment

### `encrypt` (v5.0.3)

| Attribute | Detail |
|-----------|--------|
| pub.dev | [encrypt 5.0.3](https://pub.dev/packages/encrypt) · 130 pts · last published **2 years ago** |
| Underlying library | PointyCastle |
| AES modes | CBC, CFB-64, CTR, ECB, OFB-64/GCTR, OFB-64, SIC |
| **AES-GCM** | **Not supported** — no authenticated encryption mode |
| Key derivation | **None built in** — callers use `Key.fromUtf8()` or `Key.fromLength()` (raw bytes) |
| Desktop support | Pure Dart via PointyCastle — works on Linux/macOS/Windows |
| Null safety | Yes |
| Verdict | Provides symmetric encryption primitives only; no AEAD, no KDF, no integrity guarantees out of the box. Stale (2-year-old release). |

### `cryptography` (v2.9.0)

| Attribute | Detail |
|-----------|--------|
| pub.dev | [cryptography 2.9.0](https://pub.dev/packages/cryptography) · 150 pts · 506k weekly downloads · last published **8 months ago** |
| License | Apache 2.0 |
| AES modes | AES-CBC, AES-CTR, **AES-GCM** (authenticated encryption) |
| Stream ciphers | ChaCha20, XChaCha20 |
| Key derivation | **PBKDF2**, **Argon2id**, HKDF, Hchacha20 |
| Signing | Ed25519, ECDSA (P-256/384/521), RSA-PSS, RSA-PKCS1v15 |
| Desktop support | Pure Dart fallback on Linux/macOS/Windows; native APIs used on Android/iOS/macOS |
| Null safety | Yes |
| Verdict | The strongest all-in-one option: authenticated encryption (AES-GCM / ChaCha20-Poly1305) + password hashing (Argon2id) in one package. Pure-Dart fallback means no native build requirements on desktop. |

### `hive_ce` (community edition of Hive, v≥2)

| Attribute | Detail |
|-----------|--------|
| pub.dev | [hive_ce](https://pub.dev/packages/hive_ce) · 160 pts · 845k downloads · last published **5 months ago** |
| Encryption class | `HiveAesCipher` |
| Cipher | **AES-256 CBC with PKCS7 padding** (no authentication / AEAD) |
| Key format | Raw 32-byte (`Uint8List`) — **no built-in key derivation** |
| Key derivation | Caller must supply derived key; CRC32/SHA256 checksum used only for key validation, not derivation ([source](https://github.com/IO-Design-Team/hive_ce/blob/main/hive/lib/src/crypto/hive_aes_cipher.dart)) |
| Desktop support | Yes — mobile, desktop, browser |
| Null safety | Yes |
| Verdict | Convenient if the project already uses Hive/Hive CE as its local database. Encryption is unauthenticated CBC — no ciphertext integrity; caller must derive and manage the 32-byte key externally. Suitable for "encrypt the whole DB file" pattern only. |

---

## 5. Key derivation options

For deriving an encryption key from a user-supplied master password on desktop (Linux/macOS/Windows):

| Package | KDF Algorithms | Desktop | Notes |
|---------|---------------|---------|-------|
| [`cryptography`](https://pub.dev/packages/cryptography) v2.9.0 | **Argon2id**, PBKDF2, HKDF, Hchacha20 | Yes (pure Dart) | Best option — Argon2id is the 2015 Password Hash Competition winner and the OWASP-recommended algorithm; PBKDF2 also available for lower-memory contexts |
| [`argon2`](https://pub.dev/packages/argon2) v1.0.1 | Argon2i only | Yes | Dart port of BouncyCastle; **last published 5 years ago** (stale); only Argon2i (not Argon2id). Low adoption (19 likes). Not recommended. |
| `encrypt` (PointyCastle) | PBKDF2 available via PointyCastle directly | Yes | PointyCastle exposes PBKDF2 but not via the `encrypt` package's public API; requires dropping down to PointyCastle — maintenance burden |

**Recommendation:** Use `cryptography` for both encryption (AES-GCM or ChaCha20-Poly1305) and key derivation (Argon2id). This avoids multiple dependencies and provides modern, audited primitives with a pure-Dart desktop path.

---

## 6. Tradeoffs: OS-keychain-first vs encrypted-file-first

### OS-keychain-first (flutter_secure_storage)

**Strengths:**
- On macOS and Windows, secrets are stored in the OS-managed keychain (Keychain Services, DPAPI/Credential Manager). The OS enforces per-app access control, hardware-backed key protection (Secure Enclave on Apple Silicon), and user-consent flows.
- Zero key management by the app: no master password to derive, no key to store, no risk of key-in-plaintext.
- On macOS/Windows the approach is reliable, well-tested, and matches platform security expectations.

**Weaknesses:**
- **Linux is fragile.** The libsecret/D-Bus/gnome-keyring stack is not universally present. Minimal distros, server installs, Docker containers, and CI runners will fail unless gnome-keyring is explicitly installed and a D-Bus session started. This is a significant operational risk for a desktop app targeting Linux broadly.
- The XDG Secret Portal path (needed for Flatpak sandboxing) is not yet supported ([issue #1203](https://github.com/mogol/flutter_secure_storage/issues/1203)).
- Silent/blocking failures on Linux are documented and still open ([issue #1017](https://github.com/mogol/flutter_secure_storage/issues/1017), [#778](https://github.com/mogol/flutter_secure_storage/issues/778)).
- No control over cipher or key strength — you trust the OS.

### Encrypted-file-first (cryptography + derived key)

**Strengths:**
- Fully portable: works identically on Linux, macOS, and Windows with no native dependencies beyond a pure-Dart library.
- No D-Bus, no keyring daemon, no entitlements configuration.
- Cipher and KDF are explicit and auditable (e.g., Argon2id → AES-256-GCM).
- Works in CI and headless environments.
- App has full control over security parameters (Argon2id cost factors).

**Weaknesses:**
- The master key or user password must be acquired somehow. If the app requires no password at launch, the derived key must itself be stored — creating a chicken-and-egg problem that leads back to OS keychain for the root secret.
- Without hardware backing (Secure Enclave, TPM), an attacker with filesystem read access can attempt offline brute-force against the encrypted blob. Argon2id raises the cost but does not eliminate the risk.
- Key management complexity falls on the app: key rotation, backup, loss of master password = data loss.

### Decision guidance

For a Flutter desktop app storing DB connection secrets (server hostname, username, password):

- **If macOS + Windows is the primary target and Linux is secondary:** Use `flutter_secure_storage` for macOS/Windows and fall back to an encrypted-file approach on Linux. The package supports per-platform options; callers can detect the platform and route accordingly.
- **If Linux must be fully supported (including CI/server/Flatpak):** Do not rely solely on `flutter_secure_storage` for Linux. Either: (a) require the user to enter a master password at launch and derive a key with Argon2id (`cryptography` package) to unlock an AES-GCM encrypted credentials file; or (b) use `flutter_secure_storage` on macOS/Windows and the encrypted-file pattern on Linux.
- **Hybrid (recommended for this project):** Use OS keychain on macOS and Windows via `flutter_secure_storage`, and on Linux either prompt for a master password (encrypted-file with Argon2id+AES-GCM via `cryptography`) or document the gnome-keyring runtime requirement prominently. This gives the best security on platforms where the keychain is solid, and avoids silent Linux failures.
