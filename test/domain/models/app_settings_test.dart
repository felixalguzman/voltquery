import 'package:flutter_test/flutter_test.dart';
import 'package:voltquery/domain/models/app_settings.dart';
import 'package:voltquery/domain/models/ssl_mode.dart';

/// A settings row is user-editable state read at startup: decoding must never
/// throw, and an out-of-range value must not be honoured just because it parsed.
void main() {
  test('missing keys decode to defaults', () {
    final s = AppSettings.fromJson(const {});
    expect(s.toJson(), const AppSettings().toJson());
  });

  test('wrong-typed values fall back rather than throw', () {
    final s = AppSettings.fromJson(const {
      'resultRowCap': 'lots',
      'titleBarVisible': 'yes',
      'editorFontSize': null,
    });

    expect(s.resultRowCap, const AppSettings().resultRowCap);
    expect(s.titleBarVisible, const AppSettings().titleBarVisible);
    expect(s.editorFontSize, const AppSettings().editorFontSize);
  });

  test('out-of-range numbers fall back to the default', () {
    final s = AppSettings.fromJson(const {
      'resultRowCap': 0,
      'editorFontSize': 900.0,
      'defaultConnectTimeoutSeconds': -5,
    });

    expect(s.resultRowCap, const AppSettings().resultRowCap);
    expect(s.editorFontSize, const AppSettings().editorFontSize);
    expect(s.defaultConnectTimeoutSeconds,
        const AppSettings().defaultConnectTimeoutSeconds);
  });

  test('an unreadable TLS default lands on require, never on disable', () {
    final s = AppSettings.fromJson(const {'defaultSslMode': 'nonsense'});
    expect(s.defaultSslMode, SslMode.require);
  });

  test('a JSON round-trip preserves every field', () {
    const written = AppSettings(
      historyRetentionEnabled: false,
      historyRetentionDays: 30,
      editorFontFamily: 'Fira Code',
      editorFontSize: 15.5,
      resultRowCap: 1000,
      tablePreviewLimit: 50,
      nullDisplay: '(null)',
      titleBarVisible: false,
      defaultSslMode: SslMode.disable,
      vaultAutoLockMinutes: 10,
    );

    expect(AppSettings.fromJson(written.toJson()).toJson(), written.toJson());
  });
}
