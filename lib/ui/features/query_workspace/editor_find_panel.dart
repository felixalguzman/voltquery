import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:re_editor/re_editor.dart';

import '../../core/theme/volt_tokens.dart';

// Palette lives in ui/core/theme (#7); these are local names for it.
const _panel = VoltPalette.panel;
const _bg = VoltPalette.canvas;
const _hair = VoltPalette.hairline;
const _accent = VoltPalette.accent;
const _text = VoltPalette.textHigh;
const _textLo = VoltPalette.textLow;
const _err = VoltPalette.danger;

/// The editor's find/replace bar (`Ctrl+F` / `Ctrl+H`).
///
/// re_editor already owns the hard part — matching, match ordering, the
/// selection that scrolls into view, replace — through [CodeFindController].
/// `Ctrl+F` was bound and working all along; the editor simply had no
/// `findBuilder`, so nothing appeared. This is that panel, in the app's chrome.
///
/// Distinct from the sidebar's [FilterField]: a filter narrows a list, this
/// walks matches inside one buffer, so it needs the position readout and
/// prev/next that a filter has no use for.
class EditorFindPanel extends StatelessWidget implements PreferredSizeWidget {
  const EditorFindPanel({
    super.key,
    required this.controller,
    required this.readOnly,
  });

  final CodeFindController controller;
  final bool readOnly;

  static const _rowHeight = 32.0;

  @override
  Size get preferredSize => Size.fromHeight(
        controller.value?.replaceMode ?? false ? _rowHeight * 2 : _rowHeight,
      );

  @override
  Widget build(BuildContext context) {
    final value = controller.value;
    if (value == null) return const SizedBox.shrink();

    return Container(
      decoration: const BoxDecoration(
        color: _panel,
        border: Border(bottom: BorderSide(color: _hair)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: _rowHeight, child: _findRow(value)),
          if (value.replaceMode && !readOnly)
            SizedBox(height: _rowHeight, child: _replaceRow()),
        ],
      ),
    );
  }

  Widget _findRow(CodeFindValue value) {
    final result = value.result;
    final matches = result?.matches.length ?? 0;
    // A malformed regex yields a null RegExp rather than throwing, which would
    // otherwise read as "no matches" — say which it is.
    final badRegex = value.option.regex && value.option.regExp == null;

    return Row(children: [
      const SizedBox(width: 8),
      _input(
        controller: controller.findInputController,
        focusNode: controller.findInputFocusNode,
        placeholder: 'Find',
        error: badRegex,
        onSubmitted: controller.nextMatch,
      ),
      const SizedBox(width: 8),
      SizedBox(
        width: 76,
        child: Text(
          badRegex
              ? 'bad regex'
              : matches == 0
                  ? (value.option.pattern.isEmpty ? '' : 'no results')
                  // 1-based: "0 of 12" would be a lie about where you are.
                  : '${(result?.index ?? 0) + 1} of $matches',
          style: TextStyle(
              color: badRegex ? _err : _textLo,
              fontSize: 11,
              fontFamily: 'monospace'),
        ),
      ),
      _iconToggle(
        icon: FluentIcons.font_color_a,
        tooltip: 'Match case',
        active: value.option.caseSensitive,
        onPressed: controller.toggleCaseSensitive,
      ),
      _iconToggle(
        icon: FluentIcons.code,
        tooltip: 'Regular expression',
        active: value.option.regex,
        onPressed: controller.toggleRegex,
      ),
      const SizedBox(width: 4),
      _iconToggle(
        icon: FluentIcons.up,
        tooltip: 'Previous match (Shift+Enter)',
        active: false,
        enabled: matches > 0,
        onPressed: controller.previousMatch,
      ),
      _iconToggle(
        icon: FluentIcons.down,
        tooltip: 'Next match (Enter)',
        active: false,
        enabled: matches > 0,
        onPressed: controller.nextMatch,
      ),
      if (!readOnly)
        _iconToggle(
          icon: FluentIcons.edit,
          tooltip: 'Replace',
          active: value.replaceMode,
          onPressed: controller.toggleMode,
        ),
      const Spacer(),
      _iconToggle(
        icon: FluentIcons.chrome_close,
        tooltip: 'Close (Esc)',
        active: false,
        onPressed: controller.close,
      ),
      const SizedBox(width: 6),
    ]);
  }

  Widget _replaceRow() {
    final matches = controller.value?.result?.matches.length ?? 0;
    return Row(children: [
      const SizedBox(width: 8),
      _input(
        controller: controller.replaceInputController,
        focusNode: controller.replaceInputFocusNode,
        placeholder: 'Replace',
        onSubmitted: controller.replaceMatch,
      ),
      const SizedBox(width: 8),
      _smallButton('Replace', matches > 0 ? controller.replaceMatch : null),
      const SizedBox(width: 4),
      _smallButton('All', matches > 0 ? controller.replaceAllMatches : null),
    ]);
  }

  Widget _input({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String placeholder,
    required VoidCallback onSubmitted,
    bool error = false,
  }) {
    return SizedBox(
      width: 200,
      height: 22,
      child: CallbackShortcuts(
        bindings: {
          // Shift+Enter walks backwards, the convention everywhere from
          // browsers to IDEs.
          const SingleActivator(LogicalKeyboardKey.enter, shift: true):
              this.controller.previousMatch,
        },
        child: TextBox(
          controller: controller,
          focusNode: focusNode,
          placeholder: placeholder,
          onSubmitted: (_) => onSubmitted(),
          style: const TextStyle(
              color: _text, fontSize: 12, fontFamily: 'monospace'),
          placeholderStyle:
              const TextStyle(color: _textLo, fontSize: 12),
          decoration: WidgetStatePropertyAll(BoxDecoration(
            color: _bg,
            border: Border.all(color: error ? _err : _hair),
            borderRadius: BorderRadius.circular(3),
          )),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        ),
      ),
    );
  }

  Widget _iconToggle({
    required IconData icon,
    required String tooltip,
    required bool active,
    required VoidCallback onPressed,
    bool enabled = true,
  }) {
    return Tooltip(
      message: tooltip,
      child: HoverButton(
        onPressed: enabled ? onPressed : null,
        builder: (context, states) => Container(
          width: 24,
          height: 22,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: active
                ? VoltPalette.accentWash
                : (states.isHovered ? VoltPalette.hover : null),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Icon(icon,
              size: 11,
              color: !enabled
                  ? VoltPalette.chip
                  : active
                      ? _accent
                      : _textLo),
        ),
      ),
    );
  }

  Widget _smallButton(String label, VoidCallback? onPressed) => HoverButton(
        onPressed: onPressed,
        builder: (context, states) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: states.isHovered ? VoltPalette.hover : null,
            border: Border.all(color: _hair),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(label,
              style: TextStyle(
                  color: onPressed == null ? _textLo : _text, fontSize: 11)),
        ),
      );
}
