import 'ssl_mode.dart';

/// App-wide preferences — the values that used to be constants scattered
/// through the widget tree (render caps, editor font, connection defaults).
///
/// Immutable and whole-object: the UI reads one of these, the repository
/// persists it a key at a time. Every field has a default that matches what was
/// hardcoded before it moved here, so a store with no rows behaves exactly like
/// the build that had no settings at all.
class AppSettings {
  const AppSettings({
    this.historyRetentionEnabled = true,
    this.historyRetentionDays = 90,
    this.historyRetentionRows = 2000,
    this.editorFontFamily = 'monospace',
    this.editorFontSize = 13.5,
    this.resultRowCap = 500,
    this.resultFetchBatch = 100,
    this.tablePreviewLimit = 200,
    this.nullDisplay = 'NULL',
    this.titleBarVisible = true,
    this.defaultSslMode = SslMode.require,
    this.defaultConnectTimeoutSeconds = 15,
    this.vaultAutoLockMinutes = 0,
  });

  /// Prune history on startup. Off keeps every row forever, which is a real
  /// choice — history is the only record of what you ran.
  final bool historyRetentionEnabled;

  /// Keep entries newer than this **or** the newest [historyRetentionRows],
  /// whichever is larger (`docs/design/persistence.md`) — so a quiet month
  /// doesn't erase your history, and a busy afternoon doesn't blow it up.
  final int historyRetentionDays;
  final int historyRetentionRows;

  final String editorFontFamily;
  final double editorFontSize;

  /// How many rows a result is materialized to before the grid says "capped".
  /// The grid builds every visible cell, so this is a render budget, not a
  /// fetch limit — raising it is what makes a wide `SELECT *` crawl.
  final int resultRowCap;

  /// Rows drained per cursor fetch. Smaller = more round trips, lower peak
  /// memory; larger = the reverse.
  final int resultFetchBatch;

  /// The `LIMIT` in the `SELECT *` that opening a table from the schema tree
  /// writes into the new worksheet.
  ///
  /// Separate from [resultRowCap]: that one is a client-side render budget
  /// applied to *any* result, this one is text in a query you can see and edit
  /// before or after it runs. Keeping them apart means raising the cap doesn't
  /// silently make every table click a heavier query.
  final int tablePreviewLimit;

  /// What a SQL NULL renders as in the grid. Distinct from the empty string on
  /// purpose — telling `''` from NULL by eye is otherwise impossible.
  final String nullDisplay;

  /// Show the OS window's title bar.
  ///
  /// Off on a tiling WM (Hyprland/Omarchy and friends), where the compositor
  /// already draws the frame and titles the window, so the bar is a wasted row.
  /// The app's own menu bar doubles as the drag handle when this is off.
  final bool titleBarVisible;

  /// TLS mode a **new** connection starts with. Existing connections keep
  /// whatever they were saved with — changing this never touches them.
  final SslMode defaultSslMode;
  final int defaultConnectTimeoutSeconds;

  /// Re-lock the credentials vault after this many minutes idle. `0` = only on
  /// quit, which is the launch-time behaviour this setting generalizes.
  final int vaultAutoLockMinutes;

  AppSettings copyWith({
    bool? historyRetentionEnabled,
    int? historyRetentionDays,
    int? historyRetentionRows,
    String? editorFontFamily,
    double? editorFontSize,
    int? resultRowCap,
    int? resultFetchBatch,
    int? tablePreviewLimit,
    String? nullDisplay,
    bool? titleBarVisible,
    SslMode? defaultSslMode,
    int? defaultConnectTimeoutSeconds,
    int? vaultAutoLockMinutes,
  }) =>
      AppSettings(
        historyRetentionEnabled:
            historyRetentionEnabled ?? this.historyRetentionEnabled,
        historyRetentionDays: historyRetentionDays ?? this.historyRetentionDays,
        historyRetentionRows: historyRetentionRows ?? this.historyRetentionRows,
        editorFontFamily: editorFontFamily ?? this.editorFontFamily,
        editorFontSize: editorFontSize ?? this.editorFontSize,
        resultRowCap: resultRowCap ?? this.resultRowCap,
        resultFetchBatch: resultFetchBatch ?? this.resultFetchBatch,
        tablePreviewLimit: tablePreviewLimit ?? this.tablePreviewLimit,
        nullDisplay: nullDisplay ?? this.nullDisplay,
        titleBarVisible: titleBarVisible ?? this.titleBarVisible,
        defaultSslMode: defaultSslMode ?? this.defaultSslMode,
        defaultConnectTimeoutSeconds:
            defaultConnectTimeoutSeconds ?? this.defaultConnectTimeoutSeconds,
        vaultAutoLockMinutes: vaultAutoLockMinutes ?? this.vaultAutoLockMinutes,
      );

  /// One entry per settings row. Keys are the wire format — renaming one is a
  /// silent reset to default for everyone who had it set, so don't.
  Map<String, Object?> toJson() => {
        'historyRetentionEnabled': historyRetentionEnabled,
        'historyRetentionDays': historyRetentionDays,
        'historyRetentionRows': historyRetentionRows,
        'editorFontFamily': editorFontFamily,
        'editorFontSize': editorFontSize,
        'resultRowCap': resultRowCap,
        'resultFetchBatch': resultFetchBatch,
        'tablePreviewLimit': tablePreviewLimit,
        'nullDisplay': nullDisplay,
        'titleBarVisible': titleBarVisible,
        'defaultSslMode': defaultSslMode.name,
        'defaultConnectTimeoutSeconds': defaultConnectTimeoutSeconds,
        'vaultAutoLockMinutes': vaultAutoLockMinutes,
      };

  /// Tolerant like [ConnectionOptions.fromJson]: a value of the wrong type, or
  /// one written by a build that stored it differently, falls back to the
  /// default rather than throwing. A settings row must never brick startup.
  factory AppSettings.fromJson(Map<String, Object?> json) {
    const d = AppSettings();
    return AppSettings(
      historyRetentionEnabled:
          _bool(json['historyRetentionEnabled'], d.historyRetentionEnabled),
      historyRetentionDays: _int(
          json['historyRetentionDays'], d.historyRetentionDays,
          min: 1),
      historyRetentionRows: _int(
          json['historyRetentionRows'], d.historyRetentionRows,
          min: 1),
      editorFontFamily: _string(json['editorFontFamily'], d.editorFontFamily),
      editorFontSize:
          _double(json['editorFontSize'], d.editorFontSize, min: 6, max: 48),
      resultRowCap:
          _int(json['resultRowCap'], d.resultRowCap, min: 1, max: 1000000),
      resultFetchBatch:
          _int(json['resultFetchBatch'], d.resultFetchBatch, min: 1, max: 10000),
      tablePreviewLimit: _int(json['tablePreviewLimit'], d.tablePreviewLimit,
          min: 1, max: 1000000),
      nullDisplay: _string(json['nullDisplay'], d.nullDisplay),
      titleBarVisible: _bool(json['titleBarVisible'], d.titleBarVisible),
      // No `byName` fallback games here: SslMode.byName already lands on
      // `require` for anything unrecognised, never on `disable`.
      defaultSslMode: SslMode.byName(json['defaultSslMode'] as String?),
      defaultConnectTimeoutSeconds: _int(
          json['defaultConnectTimeoutSeconds'], d.defaultConnectTimeoutSeconds,
          min: 1, max: 600),
      vaultAutoLockMinutes: _int(
          json['vaultAutoLockMinutes'], d.vaultAutoLockMinutes,
          min: 0, max: 1440),
    );
  }

  static bool _bool(Object? v, bool fallback) => v is bool ? v : fallback;

  static String _string(Object? v, String fallback) =>
      v is String && v.isNotEmpty ? v : fallback;

  static int _int(Object? v, int fallback, {int? min, int? max}) {
    final n = switch (v) {
      final int i => i,
      final num i => i.toInt(),
      _ => null,
    };
    if (n == null) return fallback;
    if (min != null && n < min) return fallback;
    if (max != null && n > max) return fallback;
    return n;
  }

  static double _double(Object? v, double fallback, {double? min, double? max}) {
    final n = v is num ? v.toDouble() : null;
    if (n == null) return fallback;
    if (min != null && n < min) return fallback;
    if (max != null && n > max) return fallback;
    return n;
  }
}
