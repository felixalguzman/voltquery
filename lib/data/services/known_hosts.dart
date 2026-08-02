import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// The outcome of checking a bastion's host key.
enum HostKeyVerdict {
  /// Seen before, same key. Proceed.
  trusted,

  /// Never seen. The user has to decide (trust on first use).
  unknown,

  /// Seen before with a **different** key. Either the server was rebuilt, or
  /// something is impersonating it.
  changed,
}

/// One trusted bastion, as the settings pane shows it.
class KnownHost {
  const KnownHost({
    required this.host,
    required this.port,
    required this.keyType,
    required this.fingerprint,
  });

  final String host;
  final int port;

  /// e.g. `ssh-ed25519`. Empty if the stored value predates the type prefix.
  final String keyType;

  /// The `SHA256:…` form, without the key type.
  final String fingerprint;

  /// Splits the stored `host:port` → `keytype fingerprint` pair back apart.
  /// Tolerant: an entry that doesn't parse is still listed (and so still
  /// revocable) rather than hidden.
  factory KnownHost.parse(String key, String value) {
    final colon = key.lastIndexOf(':');
    final space = value.indexOf(' ');
    return KnownHost(
      host: colon == -1 ? key : key.substring(0, colon),
      port: colon == -1 ? 22 : int.tryParse(key.substring(colon + 1)) ?? 22,
      keyType: space == -1 ? '' : value.substring(0, space),
      fingerprint: space == -1 ? value : value.substring(space + 1),
    );
  }
}

/// Remembers which SSH host keys have been accepted, so a bastion's identity is
/// verified and not merely assumed.
///
/// Without this, authenticating *to* a bastion proves nothing about *which*
/// machine answered — anything on the path can present its own key and relay
/// the session. This is the same trust-on-first-use model `ssh(1)` uses, and
/// the reason it prompts the first time and shouts afterwards.
///
/// Stored in the app's own file rather than `~/.ssh/known_hosts`: writing to a
/// file the user's real ssh client depends on is not something a GUI should do
/// behind their back.
class KnownHostsStore {
  KnownHostsStore(this._file);

  /// In-memory, for tests.
  KnownHostsStore.memory() : _file = null;

  final File? _file;
  Map<String, String>? _entries;

  static Future<KnownHostsStore> open() async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'VoltQuery', 'known_hosts.json'));
    await file.parent.create(recursive: true);
    return KnownHostsStore(file);
  }

  /// `host:port` → `keytype fingerprint`.
  Future<Map<String, String>> _load() async {
    if (_entries != null) return _entries!;
    final file = _file;
    if (file == null || !file.existsSync()) return _entries = {};
    try {
      final decoded = jsonDecode(await file.readAsString());
      return _entries = {
        if (decoded is Map)
          for (final e in decoded.entries) '${e.key}': '${e.value}',
      };
    } catch (_) {
      // A corrupt store must not lock the user out of every bastion; treat it
      // as empty, which downgrades to prompting rather than to trusting.
      return _entries = {};
    }
  }

  static String keyOf(String host, int port) => '$host:$port';

  /// SHA-256, base64, no padding — the `SHA256:…` form ssh prints, so a user
  /// can compare it against `ssh-keyscan` output directly.
  static String fingerprintOf(String type, Uint8List raw) {
    final digest = sha256.convert(raw).bytes;
    final b64 = base64.encode(digest).replaceAll('=', '');
    return '$type SHA256:$b64';
  }

  Future<HostKeyVerdict> check(
    String host,
    int port,
    String fingerprint,
  ) async {
    final entries = await _load();
    final known = entries[keyOf(host, port)];
    if (known == null) return HostKeyVerdict.unknown;
    return known == fingerprint
        ? HostKeyVerdict.trusted
        : HostKeyVerdict.changed;
  }

  /// Records (or replaces) the accepted key for a host.
  Future<void> trust(String host, int port, String fingerprint) async {
    final entries = await _load();
    entries[keyOf(host, port)] = fingerprint;
    await _flush();
  }

  /// Every trusted host, for the settings pane.
  ///
  /// Trust-on-first-use is only half a trust model without this: a key accepted
  /// once at a prompt is otherwise invisible and unrevocable, so a bastion
  /// trusted by mistake stays trusted forever.
  Future<List<KnownHost>> entries() async {
    final entries = await _load();
    final hosts = [
      for (final e in entries.entries) KnownHost.parse(e.key, e.value),
    ];
    hosts.sort((a, b) => a.host.compareTo(b.host));
    return hosts;
  }

  Future<void> forget(String host, int port) async {
    final entries = await _load();
    entries.remove(keyOf(host, port));
    await _flush();
  }

  Future<void> _flush() async {
    final file = _file;
    if (file == null) return;
    await file.writeAsString(jsonEncode(_entries));
  }
}
