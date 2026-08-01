import 'package:flutter_test/flutter_test.dart';
import 'package:voltquery/domain/models/connection_options.dart';
import 'package:voltquery/domain/models/ssl_mode.dart';

/// Connection options serialize to one JSON column, so decoding has to survive
/// blobs written by older *and* newer builds. The important case is the unsafe
/// one: a value we can't read must never quietly weaken security.
void main() {
  test('defaults are the safe ones', () {
    const o = ConnectionOptions();
    expect(o.sslMode, SslMode.require); // encryption is opt-out
    expect(o.enforceForeignKeys, isTrue); // a declared FK means something
    expect(o.readOnly, isFalse);
    expect(o.colorTag, isNull);
    expect(o.driverProperties, isEmpty);
  });

  test('round-trips through JSON', () {
    const o = ConnectionOptions(
      sslMode: SslMode.verifyFull,
      caCertPath: '/etc/ssl/ca.pem',
      enforceForeignKeys: false,
      colorTag: 0xFFFF6B6B,
      readOnly: true,
      connectTimeoutSeconds: 42,
      driverProperties: {'application_name': 'voltquery'},
    );
    final back = ConnectionOptions.decode(o.encode());

    expect(back.sslMode, SslMode.verifyFull);
    expect(back.caCertPath, '/etc/ssl/ca.pem');
    expect(back.enforceForeignKeys, isFalse);
    expect(back.colorTag, 0xFFFF6B6B);
    expect(back.readOnly, isTrue);
    expect(back.connectTimeoutSeconds, 42);
    expect(back.driverProperties, {'application_name': 'voltquery'});
  });

  group('decoding is tolerant but never unsafe', () {
    test('null, empty and malformed input yield defaults', () {
      for (final raw in [null, '', 'not json', '[]', '42']) {
        final o = ConnectionOptions.decode(raw);
        expect(o.sslMode, SslMode.require, reason: 'input: $raw');
        expect(o.enforceForeignKeys, isTrue, reason: 'input: $raw');
      }
    });

    test('an unreadable TLS value falls back to require, not disable', () {
      // The one fallback that must not be permissive: a corrupt or unknown
      // mode silently becoming plaintext would be a security downgrade.
      expect(ConnectionOptions.decode('{"sslMode":"nonsense"}').sslMode,
          SslMode.require);
      expect(ConnectionOptions.decode('{}').sslMode, SslMode.require);
    });

    test('a blob from an older build keeps its known keys', () {
      // Only TLS was stored before options existed.
      final o = ConnectionOptions.decode('{"sslMode":"disable"}');
      expect(o.sslMode, SslMode.disable); // explicit choice is respected
      expect(o.enforceForeignKeys, isTrue); // new key takes its default
      expect(o.connectTimeoutSeconds, 15);
    });

    test('unknown keys from a newer build are ignored, not fatal', () {
      final o = ConnectionOptions.decode(
          '{"sslMode":"require","sshHost":"bastion","futureFlag":true}');
      expect(o.sslMode, SslMode.require);
    });

    test('driver properties coerce to strings', () {
      final o = ConnectionOptions.decode(
          '{"driverProperties":{"timeout":30,"flag":true}}');
      expect(o.driverProperties, {'timeout': '30', 'flag': 'true'});
    });
  });

  test('copyWith changes one field and leaves the rest', () {
    const o = ConnectionOptions(colorTag: 0xFF00FF00, readOnly: true);
    final next = o.copyWith(sslMode: SslMode.disable);
    expect(next.sslMode, SslMode.disable);
    expect(next.colorTag, 0xFF00FF00);
    expect(next.readOnly, isTrue);
  });
}
