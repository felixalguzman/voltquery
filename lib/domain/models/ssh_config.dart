/// How the SSH tunnel authenticates to the bastion.
enum SshAuthMode {
  /// Password, stored in the vault like a database password.
  password,

  /// Private key file, optionally itself passphrase-protected.
  privateKey;

  String get label => switch (this) {
        SshAuthMode.password => 'Password',
        SshAuthMode.privateKey => 'Private key',
      };
}

/// SSH tunnel settings for one connection.
///
/// A local port forward: VoltQuery listens on a loopback port, and everything
/// written to it is carried over SSH and delivered to `host:port` **as seen
/// from the bastion**. The database driver then connects to the local end and
/// needs to know nothing about any of it.
///
/// Secrets are not stored here — [passwordRef] and [passphraseRef] are vault
/// keys, exactly like `Connection.credentialRef` (ADR-0006).
class SshConfig {
  const SshConfig({
    this.enabled = false,
    this.host = '',
    this.port = 22,
    this.username = '',
    this.authMode = SshAuthMode.password,
    this.privateKeyPath,
    this.passwordRef,
    this.passphraseRef,
  });

  final bool enabled;

  /// The bastion / jump host.
  final String host;
  final int port;
  final String username;

  final SshAuthMode authMode;

  /// Path to a PEM/OpenSSH private key when [authMode] is
  /// [SshAuthMode.privateKey].
  final String? privateKeyPath;

  /// Vault key for the SSH password.
  final String? passwordRef;

  /// Vault key for the private key's passphrase, when it has one.
  final String? passphraseRef;

  /// Usable only once a host and user are known — an enabled-but-blank tunnel
  /// would fail at connect with a confusing error instead of being ignored.
  bool get isUsable => enabled && host.isNotEmpty && username.isNotEmpty;

  SshConfig copyWith({
    bool? enabled,
    String? host,
    int? port,
    String? username,
    SshAuthMode? authMode,
    String? privateKeyPath,
    String? passwordRef,
    String? passphraseRef,
  }) =>
      SshConfig(
        enabled: enabled ?? this.enabled,
        host: host ?? this.host,
        port: port ?? this.port,
        username: username ?? this.username,
        authMode: authMode ?? this.authMode,
        privateKeyPath: privateKeyPath ?? this.privateKeyPath,
        passwordRef: passwordRef ?? this.passwordRef,
        passphraseRef: passphraseRef ?? this.passphraseRef,
      );

  Map<String, Object?> toJson() => {
        'enabled': enabled,
        'host': host,
        'port': port,
        'username': username,
        'authMode': authMode.name,
        if (privateKeyPath != null) 'privateKeyPath': privateKeyPath,
        if (passwordRef != null) 'passwordRef': passwordRef,
        if (passphraseRef != null) 'passphraseRef': passphraseRef,
      };

  /// Tolerant of blobs from other builds; anything unreadable disables the
  /// tunnel rather than half-configuring one.
  factory SshConfig.fromJson(Map<String, Object?> json) => SshConfig(
        enabled: json['enabled'] as bool? ?? false,
        host: json['host'] as String? ?? '',
        port: json['port'] as int? ?? 22,
        username: json['username'] as String? ?? '',
        authMode: SshAuthMode.values.firstWhere(
          (m) => m.name == json['authMode'],
          orElse: () => SshAuthMode.password,
        ),
        privateKeyPath: json['privateKeyPath'] as String?,
        passwordRef: json['passwordRef'] as String?,
        passphraseRef: json['passphraseRef'] as String?,
      );
}
