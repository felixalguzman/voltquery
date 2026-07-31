# Credential handling: hybrid keychain/vault, envelope encryption, session-lifetime key

**Status:** accepted

DB connection secrets are handled behind one `SecretStore` port with two
platform adapters: the **OS keychain** (`flutter_secure_storage` — Keychain on
macOS, DPAPI on Windows) and, on **Linux**, an **encrypted vault file**
(`cryptography`: Argon2id → AES-256-GCM). Linux does not use the OS keychain
because `flutter_secure_storage`'s libsecret/D-Bus path is documented to hang the
UI on Wayland/Hyprland (issue #1017) — unacceptable on the primary dev platform.
Secrets never touch `voltquery.db` (ADR-0005); `connections` hold only an opaque
`credentialRef`.

Two mechanism choices carry trade-offs:

1. **Envelope encryption in the vault.** The master password derives a KEK
   (Argon2id) that wraps a random data-encryption key (DEK); the DEK encrypts
   each secret. So changing the master password re-wraps the DEK only, without
   re-encrypting every secret. All ciphertext is AES-256-GCM (authenticated).
2. **Session-lifetime key.** The derived key is held in memory (never persisted)
   from first unlock until quit or an optional idle timeout — not re-prompted per
   connect. This trades a smaller unlock window for usability in a tool you
   connect with constantly.

The cost of the hybrid: two backends to audit and a master password that exists
only on Linux (inconsistent cross-platform UX). Accepted because a uniform vault
would force a master-password prompt even where the OS keychain is seamless and
hardware-backed. Full design: `docs/design/credentials.md`.

**Consequence to honor:** never persist the derived key or a plaintext secret to
disk, and never write a secret into `voltquery.db`. Deleting a Connection must
`SecretStore.delete(credentialRef)`.
