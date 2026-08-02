import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

/// Stores DB connection secrets, encrypted. Secrets are keyed by an opaque
/// `credentialRef` (ADR-0005/0006). Never persists a plaintext secret.
abstract interface class SecretStore {
  /// True until [unlock] provides the master password.
  bool get isLocked;

  /// True if a vault already exists (unlock) vs first-run (create).
  bool get exists;

  /// Unlocks the vault, creating it (with this as the master password) if absent.
  /// Throws [SecretBoxAuthenticationError] on a wrong master password.
  Future<void> unlock(String masterPassword);

  /// Drops the derived key from memory.
  void lock();

  /// Re-keys the vault to [next], after checking [current].
  ///
  /// Throws [SecretBoxAuthenticationError] if [current] is wrong, and
  /// [StateError] if no vault exists yet. Cheap by design: envelope encryption
  /// means only the wrapped DEK is rewritten, so the stored secrets themselves
  /// are neither decrypted nor re-encrypted.
  Future<void> changeMasterPassword(String current, String next);

  Future<void> write(String credentialRef, String secret);
  Future<String?> read(String credentialRef);
  Future<void> delete(String credentialRef);
}

/// The Linux / default backend (ADR-0006): an encrypted vault file with
/// **envelope encryption** — Argon2id(masterPassword) → KEK wraps a random DEK;
/// each secret is AES-256-GCM(DEK). The derived key lives in memory only.
class VaultSecretStore implements SecretStore {
  VaultSecretStore(this._file, {Argon2id? kdf})
      : _kdf = kdf ??
            Argon2id(
              parallelism: 1,
              memory: 12000, // ~12 MB
              iterations: 3,
              hashLength: 32,
            );

  final File _file;
  final Argon2id _kdf;
  final AesGcm _aes = AesGcm.with256bits();

  SecretKey? _dek;
  Map<String, dynamic>? _vault;

  @override
  bool get isLocked => _dek == null;

  @override
  bool get exists => _file.existsSync();

  @override
  Future<void> unlock(String masterPassword) async {
    if (!_file.existsSync()) {
      await _create(masterPassword);
      return;
    }
    final data = jsonDecode(await _file.readAsString()) as Map<String, dynamic>;
    final kek = await _deriveKek(masterPassword, base64Decode(data['salt'] as String));
    // Throws SecretBoxAuthenticationError if the master password is wrong.
    final dekBytes = await _aes.decrypt(_boxFrom(data['wrappedDek'] as String),
        secretKey: kek);
    _dek = SecretKey(dekBytes);
    _vault = data;
  }

  Future<void> _create(String masterPassword) async {
    final salt = _randomBytes(16);
    final kek = await _deriveKek(masterPassword, salt);
    final dek = await _aes.newSecretKey();
    final wrapped = await _aes.encrypt(await dek.extractBytes(), secretKey: kek);
    _dek = dek;
    _vault = {
      'version': 1,
      'salt': base64Encode(salt),
      'wrappedDek': _boxTo(wrapped),
      'entries': <String, String>{},
    };
    await _save();
  }

  @override
  void lock() {
    _dek = null;
    _vault = null;
  }

  @override
  Future<void> changeMasterPassword(String current, String next) async {
    if (!_file.existsSync()) {
      throw StateError('no vault to re-key');
    }
    // Read from disk rather than from [_vault] so this works whether or not the
    // vault is currently unlocked, and so `current` is always actually checked
    // instead of trusted because a session happens to be open.
    final data = jsonDecode(await _file.readAsString()) as Map<String, dynamic>;
    final oldKek =
        await _deriveKek(current, base64Decode(data['salt'] as String));
    // Throws SecretBoxAuthenticationError if `current` is wrong — the same
    // failure unlock() raises, so callers handle one error type.
    final dekBytes = await _aes
        .decrypt(_boxFrom(data['wrappedDek'] as String), secretKey: oldKek);

    // New salt as well as new password: reusing the old salt would leak that
    // the two passwords were derived against the same parameters.
    final salt = _randomBytes(16);
    final newKek = await _deriveKek(next, salt);
    final rewrapped = await _aes.encrypt(dekBytes, secretKey: newKek);

    data['salt'] = base64Encode(salt);
    data['wrappedDek'] = _boxTo(rewrapped);

    // The DEK is unchanged, so an unlocked session stays valid and every stored
    // secret still decrypts — only the wrapping key moved.
    final wasUnlocked = !isLocked;
    final previous = _vault;
    _vault = data;
    try {
      await _save();
    } catch (_) {
      _vault = previous;
      rethrow;
    }
    if (!wasUnlocked) _vault = null;
  }

  @override
  Future<void> write(String credentialRef, String secret) async {
    _requireUnlocked();
    final box = await _aes.encrypt(utf8.encode(secret), secretKey: _dek!);
    (_vault!['entries'] as Map)[credentialRef] = _boxTo(box);
    await _save();
  }

  @override
  Future<String?> read(String credentialRef) async {
    if (isLocked) return null;
    final entry = (_vault!['entries'] as Map)[credentialRef] as String?;
    if (entry == null) return null;
    return utf8.decode(await _aes.decrypt(_boxFrom(entry), secretKey: _dek!));
  }

  @override
  Future<void> delete(String credentialRef) async {
    _requireUnlocked();
    (_vault!['entries'] as Map).remove(credentialRef);
    await _save();
  }

  Future<SecretKey> _deriveKek(String password, List<int> salt) =>
      _kdf.deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);

  void _requireUnlocked() {
    if (isLocked) throw StateError('vault is locked');
  }

  /// Write-then-rename, so a crash mid-save leaves the previous vault intact.
  ///
  /// Overwriting in place is survivable for a single entry, but re-keying
  /// rewrites the wrapped DEK — a torn write there loses *every* stored secret,
  /// which is not a risk worth carrying for one saved syscall.
  Future<void> _save() async {
    await _file.parent.create(recursive: true);
    final tmp = File('${_file.path}.tmp');
    await tmp.writeAsString(jsonEncode(_vault), flush: true);
    await tmp.rename(_file.path);
    // TODO(security): restrict to 0600 on POSIX.
  }

  String _boxTo(SecretBox b) => base64Encode(b.concatenation());

  SecretBox _boxFrom(String s) => SecretBox.fromConcatenation(
        base64Decode(s),
        nonceLength: _aes.nonceLength,
        macLength: _aes.macAlgorithm.macLength,
      );

  List<int> _randomBytes(int n) {
    final r = Random.secure();
    return List<int>.generate(n, (_) => r.nextInt(256));
  }
}
