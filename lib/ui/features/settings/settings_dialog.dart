import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/sql.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';

import '../../core/theme/volt_tokens.dart';

import '../../../domain/models/app_settings.dart';
import '../../../domain/models/ssl_mode.dart';
import '../../core/menu/confirm.dart';
import '../../core/shell/window_chrome.dart';
import 'known_hosts_section.dart';
import 'settings_providers.dart';
import 'vault_section.dart';


/// App preferences.
///
/// Changes apply and persist as you make them — there is no OK/Cancel. Every
/// setting here is reversible and previewable in place (a font size you can't
/// see applied is a font size you have to guess at), so staging them behind a
/// confirm would buy nothing and add a whole class of "saved but not applied"
/// bugs.
Future<void> showSettingsDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (context) => const SettingsDialog(),
  );
}

enum _Section {
  general('General', FluentIcons.settings),
  editor('Editor', FluentIcons.edit),
  results('Results', FluentIcons.table),
  window('Window', FluentIcons.tiles),
  connections('Connections', FluentIcons.plug_connected),
  security('Security', FluentIcons.lock);

  const _Section(this.label, this.icon);
  final String label;
  final IconData icon;
}

class SettingsDialog extends ConsumerStatefulWidget {
  const SettingsDialog({super.key});

  @override
  ConsumerState<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<SettingsDialog> {
  VoltTokens get t => VoltTheme.of(context);
  _Section _section = _Section.general;

  /// Sample for the editor preview. Held in state, not rebuilt per frame — a
  /// fresh controller each build would reset the highlighter every keystroke
  /// in the font-size box.
  final _previewCode = CodeLineEditingController.fromText(
    "SELECT id, name, total\n"
    "  FROM orders\n"
    " WHERE status = 'shipped' AND total > 100;",
  );

  @override
  void dispose() {
    _previewCode.dispose();
    super.dispose();
  }

  AppSettings get _settings => ref.watch(settingsProvider);

  Future<void> _edit(AppSettings Function(AppSettings) change) =>
      ref.read(settingsProvider.notifier).edit(change);

  @override
  Widget build(BuildContext context) {
    final t = VoltTheme.of(context);
    final screen = MediaQuery.sizeOf(context);
    return ContentDialog(
      constraints: BoxConstraints(
        maxWidth: screen.width.clamp(480.0, 780.0),
        maxHeight: screen.height * 0.82,
      ),
      title: const Text('Settings', style: TextStyle(fontSize: 15)),
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 150, child: _rail()),
          Container(width: 1, color: t.hairline),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 18),
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(right: 8),
                child: switch (_section) {
                  _Section.general => _generalSection(),
                  _Section.editor => _editorSection(),
                  _Section.results => _resultsSection(),
                  _Section.window => _windowSection(),
                  _Section.connections => _connectionsSection(),
                  _Section.security => _securitySection(),
                },
              ),
            ),
          ),
        ],
      ),
      actions: [
        Button(onPressed: _resetAll, child: const Text('Reset to defaults')),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Future<void> _resetAll() async {
    final ok = await confirm(
      context,
      title: 'Reset all settings?',
      message: 'Every preference goes back to its default. Saved connections, '
          'history and vault secrets are not affected.',
      confirmLabel: 'Reset',
    );
    if (!ok) return;
    await ref.read(settingsProvider.notifier).resetToDefaults();
    // The window is the one setting with an effect outside the app's own state.
    await applyTitleBarVisibility(const AppSettings().titleBarVisible);
  }

  Widget _rail() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final s in _Section.values)
            HoverButton(
              onPressed: () => setState(() => _section = s),
              builder: (context, states) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                margin: const EdgeInsets.only(bottom: 2, right: 8),
                decoration: BoxDecoration(
                  color: _section == s
                      ? t.accentWash
                      : (states.isHovered ? t.hover : null),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(s.icon,
                        size: 13,
                        color: _section == s ? t.accent : t.textMid),
                    const SizedBox(width: 8),
                    // Flexible so a narrow window ellipsises the longest label
                    // ("Connections") instead of overflowing the rail.
                    Flexible(
                      child: Text(s.label,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12.5,
                              color: _section == s ? t.accent : t.textHigh)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );

  // ---------------------------------------------------------------- sections

  Widget _generalSection() {
    final s = _settings;
    return _sectionBody([
      _SettingRow(
        label: 'Prune query history',
        description:
            'Trim old history on startup. Off keeps every entry forever — '
            'history is the only record of what you ran.',
        child: ToggleSwitch(
          checked: s.historyRetentionEnabled,
          onChanged: (v) => _edit((p) => p.copyWith(historyRetentionEnabled: v)),
        ),
      ),
      _SettingRow(
        label: 'Keep for (days)',
        description: 'Entries newer than this are always kept.',
        enabled: s.historyRetentionEnabled,
        child: _number(
          value: s.historyRetentionDays,
          step: 30,
          min: 1,
          max: 3650,
          enabled: s.historyRetentionEnabled,
          onChanged: (v) => _edit((p) => p.copyWith(historyRetentionDays: v)),
        ),
      ),
      _SettingRow(
        label: 'Keep at least (entries)',
        description:
            'Whichever is larger wins, so a quiet month does not erase your '
            'history and a busy afternoon does not blow it up.',
        enabled: s.historyRetentionEnabled,
        child: _number(
          value: s.historyRetentionRows,
          step: 500,
          min: 1,
          max: 1000000,
          enabled: s.historyRetentionEnabled,
          onChanged: (v) => _edit((p) => p.copyWith(historyRetentionRows: v)),
        ),
      ),
    ]);
  }

  Widget _editorSection() {
    final s = _settings;
    return _sectionBody([
      _SettingRow(
        label: 'Font family',
        description:
            'Monospace fonts installed on this machine. `monospace` follows '
            'the system default. Anything not listed can still be typed.',
        child: _FontPicker(
          value: s.editorFontFamily,
          families: ref.watch(monospaceFontsProvider).value ?? [],
          onCommit: (v) => _edit((p) => p.copyWith(editorFontFamily: v)),
        ),
      ),
      _SettingRow(
        label: 'Font size',
        child: _number<double>(
          value: s.editorFontSize,
          step: 0.5,
          min: 6,
          max: 48,
          onChanged: (v) => _edit((p) => p.copyWith(editorFontSize: v)),
        ),
      ),
      _preview(s),
    ]);
  }

  /// Lines in [_previewCode] — the box is sized to hold exactly this many at
  /// the chosen font size, so the sample never scrolls.
  static const _previewLines = 3;

  Widget _preview(AppSettings s) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Preview',
              style: TextStyle(color: t.textMid, fontSize: 11)),
          const SizedBox(height: 6),
          Container(
            // Grows with the font instead of being a fixed box: a scrollbar on
            // three lines of sample SQL is noise, and at 24pt the sample was
            // genuinely cut off.
            height: _previewLines * s.editorFontSize * 1.6 + 16,
            decoration: BoxDecoration(
              border: Border.all(color: t.hairline),
              borderRadius: BorderRadius.circular(4),
            ),
            clipBehavior: Clip.antiAlias,
            // The real editor widget, read-only — same highlighter, same
            // theme, same font resolution. A hand-styled Text sample can agree
            // with the editor today and drift from it tomorrow, and this one
            // already had: it showed the SQL in flat white while the editor
            // syntax-highlights.
            child: IgnorePointer(
              child: ScrollConfiguration(
                // The sample always fits, so any scrollbar here is decoration.
                behavior:
                    ScrollConfiguration.of(context).copyWith(scrollbars: false),
                child: CodeEditor(
                  controller: _previewCode,
                  readOnly: true,
                  style: CodeEditorStyle(
                    fontSize: s.editorFontSize,
                    fontFamily: s.editorFontFamily,
                    backgroundColor: t.canvas,
                    codeTheme: CodeHighlightTheme(
                      languages: {'sql': CodeHighlightThemeMode(mode: langSql)},
                      theme: atomOneDarkTheme,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );

  Widget _resultsSection() {
    final s = _settings;
    return _sectionBody([
      _SettingRow(
        label: 'Row render cap',
        description:
            'How many rows a result is materialized to. The grid builds every '
            'visible cell, so raising this is what makes a wide SELECT * crawl.',
        child: _number(
          value: s.resultRowCap,
          step: 50,
          min: 1,
          max: 1000000,
          onChanged: (v) => _edit((p) => p.copyWith(resultRowCap: v)),
        ),
      ),
      _SettingRow(
        label: 'Table preview LIMIT',
        description:
            'The LIMIT written into the SELECT * when you open a table from '
            'the schema tree. It is text in the editor, so you can always '
            'change it for one query without coming back here.',
        child: _number(
          value: s.tablePreviewLimit,
          step: 50,
          min: 1,
          max: 1000000,
          onChanged: (v) => _edit((p) => p.copyWith(tablePreviewLimit: v)),
        ),
      ),
      _SettingRow(
        label: 'Fetch batch size',
        description:
            'Rows drained per cursor fetch. Smaller means more round trips and '
            'lower peak memory.',
        child: _number(
          value: s.resultFetchBatch,
          step: 50,
          min: 1,
          max: 10000,
          onChanged: (v) => _edit((p) => p.copyWith(resultFetchBatch: v)),
        ),
      ),
      _SettingRow(
        label: 'Show NULL as',
        description:
            'Kept distinct from an empty string on purpose — telling the two '
            'apart by eye is otherwise impossible.',
        child: _TextSetting(
          value: s.nullDisplay,
          width: 120,
          onCommit: (v) => _edit((p) => p.copyWith(nullDisplay: v)),
        ),
      ),
    ]);
  }

  Widget _windowSection() {
    final s = _settings;
    return _sectionBody([
      _SettingRow(
        label: 'Show title bar',
        description:
            'Turn off on a tiling window manager (Hyprland, sway, i3), where '
            'the compositor already draws the frame and the bar is a wasted '
            'row. The menu bar below it stays draggable either way, and File → '
            'Quit still closes the window.',
        child: ToggleSwitch(
          checked: s.titleBarVisible,
          onChanged: (v) async {
            await _edit((p) => p.copyWith(titleBarVisible: v));
            await applyTitleBarVisibility(v);
          },
        ),
      ),
    ]);
  }

  Widget _connectionsSection() {
    final s = _settings;
    return _sectionBody([
      const _Note(
        'Defaults for **new** connections. Existing saved connections keep '
        'whatever they were saved with — changing these never edits them.',
      ),
      _SettingRow(
        label: 'TLS mode',
        description: s.defaultSslMode.description,
        child: ComboBox<SslMode>(
          value: s.defaultSslMode,
          items: [
            for (final m in SslMode.values)
              ComboBoxItem(
                value: m,
                child: Text(m.label, style: const TextStyle(fontSize: 12.5)),
              ),
          ],
          onChanged: (v) =>
              v == null ? null : _edit((p) => p.copyWith(defaultSslMode: v)),
        ),
      ),
      _SettingRow(
        label: 'Connect timeout (seconds)',
        child: _number(
          value: s.defaultConnectTimeoutSeconds,
          step: 5,
          min: 1,
          max: 600,
          onChanged: (v) =>
              _edit((p) => p.copyWith(defaultConnectTimeoutSeconds: v)),
        ),
      ),
    ]);
  }

  Widget _securitySection() => _sectionBody([
        const VaultSection(),
        const SizedBox(height: 8),
        Container(height: 1, color: t.hairline),
        const SizedBox(height: 12),
        const KnownHostsSection(),
      ]);

  Widget _sectionBody(List<Widget> children) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: children,
      );

  /// [NumberBox] fires `onChanged` on commit (spinner or focus loss), never per
  /// keystroke — typing "500" into a field that applied every digit would set
  /// the cap to 5, then 50, re-running nothing but the validator each time.
  ///
  /// [step] is sized to the field: nudging a 500-row cap by 1 is thirty clicks
  /// to a useful number. PageUp/PageDown move ten steps at once.
  Widget _number<T extends num>({
    required T value,
    required ValueChanged<T> onChanged,
    num step = 1,
    num? min,
    num? max,
    bool enabled = true,
  }) =>
      SizedBox(
        width: 132,
        child: NumberBox<T>(
          value: value,
          min: min,
          max: max,
          smallChange: step,
          largeChange: step * 10,
          mode: SpinButtonPlacementMode.inline,
          clearButton: false,
          onChanged: enabled ? (v) => v == null ? null : onChanged(v) : null,
        ),
      );
}

/// One label + description + control row.
class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.label,
    required this.child,
    this.description,
    this.enabled = true,
  });

  final String label;
  final String? description;
  final Widget child;

  /// Greys the text when the control is inert, so a disabled row reads as
  /// disabled rather than as broken.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = VoltTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 12.5, color: enabled ? t.textHigh : t.textLow)),
                if (description != null) ...[
                  const SizedBox(height: 3),
                  Text(description!,
                      style: TextStyle(
                          fontSize: 11,
                          height: 1.35,
                          color: enabled ? t.textMid : t.textLow)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          child,
        ],
      ),
    );
  }
}

/// A text setting that commits on Enter or focus loss rather than per keystroke
/// — the same reason [NumberBox] does, and it keeps a half-typed font name from
/// being persisted and rendered.
class _TextSetting extends StatefulWidget {
  const _TextSetting({
    required this.value,
    required this.onCommit,
    this.width = 160,
  });

  final String value;
  final ValueChanged<String> onCommit;
  final double width;

  @override
  State<_TextSetting> createState() => _TextSettingState();
}

class _TextSettingState extends State<_TextSetting> {
  VoltTokens get t => VoltTheme.of(context);
  late final _controller = TextEditingController(text: widget.value);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(_TextSetting old) {
    super.didUpdateWidget(old);
    // Reflect an external change (Reset to defaults) unless the user is mid-edit.
    if (widget.value != old.value && !_focus.hasFocus) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _commit() {
    final v = _controller.text.trim();
    if (v.isEmpty) {
      // Empty is not a value here — restore rather than persist a blank that
      // would render as an invisible NULL marker or a nameless font.
      _controller.text = widget.value;
      return;
    }
    if (v != widget.value) widget.onCommit(v);
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: widget.width,
        child: TextBox(
          controller: _controller,
          focusNode: _focus,
          onSubmitted: (_) => _commit(),
        ),
      );
}

/// Search-and-pick over the installed monospace families, each rendered in
/// itself so the list is its own preview.
///
/// Still free text underneath: [families] comes from fontconfig, which won't
/// know about a family the app can nonetheless resolve, and is empty entirely
/// on platforms we can't enumerate. Restricting the field to the list would
/// turn a missing catalog into a broken setting.
class _FontPicker extends StatefulWidget {
  const _FontPicker({
    required this.value,
    required this.families,
    required this.onCommit,
  });

  final String value;
  final List<String> families;
  final ValueChanged<String> onCommit;

  @override
  State<_FontPicker> createState() => _FontPickerState();
}

class _FontPickerState extends State<_FontPicker> {
  VoltTokens get t => VoltTheme.of(context);
  late final _controller = TextEditingController(text: widget.value);
  final _focus = FocusNode();

  /// Reaches the box's `showOverlay()` — see [_onFocusChange].
  final _box = GlobalKey<AutoSuggestBoxState<String>>();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
  }

  /// Empties the field on focus, opens the list, and restores the value on blur.
  ///
  /// Two things fought here. The box filters by whatever text it holds, so
  /// leaving the current family in place offered exactly one suggestion — the
  /// font you already have. But fluent's own focus handler only opens the
  /// overlay `if (_controller.text.isNotEmpty)`, so clearing alone left the
  /// list shut until a keystroke (typing a space was the workaround). Clearing
  /// *and* opening it ourselves gives the plain "click to see everything" a
  /// picker is supposed to have. Nothing is lost — blurring without choosing
  /// puts the old value straight back.
  void _onFocusChange() {
    if (_focus.hasFocus) {
      _controller.clear();
      // After the clear lands, or fluent's own focus handler races it shut.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_focus.hasFocus) _box.currentState?.showOverlay();
      });
      return;
    }
    _commit(_controller.text);
  }

  @override
  void didUpdateWidget(_FontPicker old) {
    super.didUpdateWidget(old);
    if (widget.value != old.value && !_focus.hasFocus) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _commit(String raw) {
    final v = raw.trim();
    if (v.isEmpty) {
      // Blurring without choosing, or a blank entry — put the old value back.
      // A blank family would render as the system default while leaving the
      // field looking unset.
      _controller.text = widget.value;
      return;
    }
    if (v != widget.value) widget.onCommit(v);
    _controller.text = v;
  }

  @override
  Widget build(BuildContext context) {
    final t = VoltTheme.of(context);
    return SizedBox(
      // Wide enough for the real names installed on a dev machine —
      // "JetBrainsMono Nerd Font Mono" ellipsised to "JetBrainsMono Nerd Fo…"
      // is indistinguishable from three of its siblings.
      width: 270,
      child: AutoSuggestBox<String>(
        key: _box,
        controller: _controller,
        focusNode: _focus,
        clearButtonEnabled: false,
        trailingIcon: Icon(FluentIcons.font, size: 12, color: t.textMid),
        placeholder: widget.value,
        items: [
          for (final family in widget.families)
            AutoSuggestBoxItem<String>(
              value: family,
              label: family,
              // Each row in its own face: picking a font from a list set in
              // some other font tells you nothing about the font. Two lines
              // before ellipsising, so a long family name stays identifiable.
              child: Text(
                family,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: family, fontSize: 13),
              ),
            ),
        ],
        onSelected: (item) => _commit(item.value ?? item.label),
      ),
    );
  }
}

/// A short explanatory line above a group of settings. `**bold**` spans are
/// rendered; nothing else is.
class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = VoltTheme.of(context);
    final parts = text.split('**');
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text.rich(
        TextSpan(
          children: [
            for (final (i, part) in parts.indexed)
              TextSpan(
                text: part,
                style: TextStyle(
                  fontWeight: i.isOdd ? FontWeight.w600 : FontWeight.normal,
                  color: i.isOdd ? t.textHigh : t.textMid,
                ),
              ),
          ],
        ),
        style: TextStyle(fontSize: 11, height: 1.35, color: t.textMid),
      ),
    );
  }
}
