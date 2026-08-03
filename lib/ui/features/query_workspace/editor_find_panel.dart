import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:re_editor/re_editor.dart';

import '../../core/theme/volt_tokens.dart';

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
    final t = VoltTheme.of(context);
    final value = controller.value;
    if (value == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: t.panel,
        border: Border(bottom: BorderSide(color: t.hairline)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: _rowHeight, child: _findRow(t, value)),
          if (value.replaceMode && !readOnly)
            SizedBox(height: _rowHeight, child: _replaceRow(t)),
        ],
      ),
    );
  }

  Widget _findRow(VoltTokens t, CodeFindValue value) {
    final result = value.result;
    final matches = result?.matches.length ?? 0;
    // A malformed regex yields a null RegExp rather than throwing, which would
    // otherwise read as "no matches" — say which it is.
    final badRegex = value.option.regex && value.option.regExp == null;

    return Row(
      children: [
        const SizedBox(width: 8),
        _input(
          t,
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
              color: badRegex ? t.danger : t.textLow,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
        ),
        _iconToggle(
          t,
          icon: FluentIcons.font_color_a,
          tooltip: 'Match case',
          active: value.option.caseSensitive,
          onPressed: controller.toggleCaseSensitive,
        ),
        _iconToggle(
          t,
          icon: FluentIcons.code,
          tooltip: 'Regular expression',
          active: value.option.regex,
          onPressed: controller.toggleRegex,
        ),
        const SizedBox(width: 4),
        _iconToggle(
          t,
          icon: FluentIcons.up,
          tooltip: 'Previous match (Shift+Enter)',
          active: false,
          enabled: matches > 0,
          onPressed: controller.previousMatch,
        ),
        _iconToggle(
          t,
          icon: FluentIcons.down,
          tooltip: 'Next match (Enter)',
          active: false,
          enabled: matches > 0,
          onPressed: controller.nextMatch,
        ),
        if (!readOnly)
          _iconToggle(
            t,
            icon: FluentIcons.edit,
            tooltip: 'Replace',
            active: value.replaceMode,
            onPressed: controller.toggleMode,
          ),
        const Spacer(),
        _iconToggle(
          t,
          icon: FluentIcons.chrome_close,
          tooltip: 'Close (Esc)',
          active: false,
          onPressed: controller.close,
        ),
        const SizedBox(width: 6),
      ],
    );
  }

  Widget _replaceRow(VoltTokens t) {
    final matches = controller.value?.result?.matches.length ?? 0;
    return Row(
      children: [
        const SizedBox(width: 8),
        _input(
          t,
          controller: controller.replaceInputController,
          focusNode: controller.replaceInputFocusNode,
          placeholder: 'Replace',
          onSubmitted: controller.replaceMatch,
        ),
        const SizedBox(width: 8),
        _smallButton(
          t,
          'Replace',
          matches > 0 ? controller.replaceMatch : null,
        ),
        const SizedBox(width: 4),
        _smallButton(
          t,
          'All',
          matches > 0 ? controller.replaceAllMatches : null,
        ),
      ],
    );
  }

  Widget _input(
    VoltTokens t, {
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
          style: TextStyle(
            color: t.textHigh,
            fontSize: 12,
            fontFamily: 'monospace',
          ),
          placeholderStyle: TextStyle(color: t.textLow, fontSize: 12),
          decoration: WidgetStatePropertyAll(
            BoxDecoration(
              color: t.canvas,
              border: Border.all(color: error ? t.danger : t.hairline),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        ),
      ),
    );
  }

  Widget _iconToggle(
    VoltTokens t, {
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
            color: active ? t.accentWash : (states.isHovered ? t.hover : null),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Icon(
            icon,
            size: 11,
            color: !enabled
                ? t.chip
                : active
                ? t.accent
                : t.textLow,
          ),
        ),
      ),
    );
  }

  Widget _smallButton(VoltTokens t, String label, VoidCallback? onPressed) =>
      HoverButton(
        onPressed: onPressed,
        builder: (context, states) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: states.isHovered ? t.hover : null,
            border: Border.all(color: t.hairline),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: onPressed == null ? t.textLow : t.textHigh,
              fontSize: 11,
            ),
          ),
        ),
      );
}
