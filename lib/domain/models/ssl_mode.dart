/// How a server connection should use TLS.
///
/// Named after the libpq modes every DBA already knows, and deliberately
/// *without* a "prefer"-style silent fallback: a connection that quietly
/// downgrades to plaintext is the failure mode this enum exists to prevent.
enum SslMode {
  /// No TLS. Credentials and data cross the wire in the clear.
  ///
  /// Note this is not merely "less secure" — MySQL 8's default auth plugin
  /// (`caching_sha2_password`) *refuses* to authenticate over a plaintext
  /// socket, so `disable` cannot connect to a default-configured MySQL 8 at all.
  disable,

  /// Encrypt, but don't verify the server's certificate.
  ///
  /// Protects against passive eavesdropping, **not** against an active
  /// man-in-the-middle, since any certificate is accepted. The pragmatic choice
  /// for localhost and self-signed development servers.
  require,

  /// Encrypt and verify the certificate chain and hostname.
  ///
  /// The only mode that is actually safe across an untrusted network. Requires
  /// the server's CA to be trusted by the system (or supplied via
  /// [Connection.caCertPath]). Not supported by every engine — see
  /// [Capabilities.verifiesTlsCertificates].
  verifyFull;

  bool get enabled => this != SslMode.disable;

  /// Human label for the connection form.
  String get label => switch (this) {
        SslMode.disable => 'Disabled',
        SslMode.require => 'Required (no verification)',
        SslMode.verifyFull => 'Verify full',
      };

  String get description => switch (this) {
        SslMode.disable =>
          'No encryption. MySQL 8 refuses to authenticate this way.',
        SslMode.require =>
          'Encrypted, certificate not checked. Fine for localhost.',
        SslMode.verifyFull =>
          'Encrypted and the certificate is verified. Use across a network.',
      };

  static SslMode byName(String? name) => SslMode.values.firstWhere(
        (m) => m.name == name,
        orElse: () => SslMode.require,
      );
}
