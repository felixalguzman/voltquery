import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';

import '../../core/theme/volt_tokens.dart';

// Palette lives in ui/core/theme (#7); these are local names for it.
const _bg = VoltPalette.canvas;
const _hair = VoltPalette.hairline;
const _accent = VoltPalette.accent;
const _text = VoltPalette.textHigh;
const _textLo = VoltPalette.textLow;

/// Substring match, case- and accent-insensitive as far as `toLowerCase` goes.
///
/// **Substring, not prefix.** Real schemas are prefix-heavy — `ven_factura`,
/// `ven_factura_detalle`, `secuencia_ncf` — so prefix matching makes you type
/// the boring part of every name before it narrows anything.
bool matchesFilter(String haystack, String needle) {
  if (needle.isEmpty) return true;
  return haystack.toLowerCase().contains(needle.toLowerCase());
}

/// Whether a panel's filter row is showing, and what's in it.
///
/// Open-ness is state of its own rather than "text is non-empty": the row has
/// to appear *before* you can type into it, and clearing the text shouldn't
/// snatch the box away mid-edit.
class FilterState {
  const FilterState({this.open = false, this.text = ''});

  final bool open;
  final String text;

  /// True only when the filter should actually narrow anything.
  bool get active => open && text.isNotEmpty;
}

/// Standard filter row: a [FilterField] on its own line under a section header.
///
/// Under rather than inside the header, because the header is 240px wide and
/// something had to give — and losing the section title also loses
/// click-title-to-collapse, which is worse than 24px of height that only
/// exists while you're filtering.
class FilterRow extends StatelessWidget {
  const FilterRow({
    super.key,
    required this.state,
    required this.onChanged,
    required this.placeholder,
    this.matchCount,
  });

  final FilterState state;
  final ValueChanged<String> onChanged;
  final String placeholder;
  final int? matchCount;

  @override
  Widget build(BuildContext context) {
    if (!state.open) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
      child: FilterField(
        value: state.text,
        placeholder: placeholder,
        matchCount: matchCount,
        autofocus: true,
        onChanged: onChanged,
      ),
    );
  }
}

/// The one filter box, shared by every list in the app that you'd otherwise
/// scan by eye: the schema tree, query history, the table-info column list.
///
/// One widget rather than three so they behave identically — same matching
/// rule, same clear affordance, same Escape behaviour. Deliberately small: it
/// sits inside a section header's width, not across a dialog.
class FilterField extends StatefulWidget {
  const FilterField({
    super.key,
    required this.value,
    required this.onChanged,
    this.placeholder = 'Filter…',
    this.matchCount,
    this.autofocus = false,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String placeholder;

  /// Shown as `n` on the right when filtering. Null hides it.
  final int? matchCount;

  final bool autofocus;

  @override
  State<FilterField> createState() => _FilterFieldState();
}

class _FilterFieldState extends State<FilterField> {
  late final _controller = TextEditingController(text: widget.value);
  final _focus = FocusNode();

  @override
  void didUpdateWidget(FilterField old) {
    super.didUpdateWidget(old);
    // Reflect a clear that came from somewhere else (Escape elsewhere, a
    // connection switch) without stomping what the user is mid-way through.
    if (widget.value != old.value && widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.value.isNotEmpty;
    return CallbackShortcuts(
      bindings: {
        // Escape clears rather than closing anything — the filter is a lens on
        // a panel that stays put, so "get me back to everything" is the only
        // sensible meaning.
        const SingleActivator(LogicalKeyboardKey.escape): _clear,
      },
      // One border, drawn by the TextBox itself. Wrapping it in a bordered
      // Container nested two rounded rectangles inside each other, which read
      // as a rendering bug rather than a field.
      child: SizedBox(
        height: 24,
        child: TextBox(
          controller: _controller,
          focusNode: _focus,
          autofocus: widget.autofocus,
          placeholder: widget.placeholder,
          onChanged: widget.onChanged,
          style: const TextStyle(color: _text, fontSize: 11.5),
          placeholderStyle: const TextStyle(color: _textLo, fontSize: 11.5),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: WidgetStatePropertyAll(BoxDecoration(
            color: _bg,
            border: Border.all(color: active ? _accent : _hair),
            borderRadius: BorderRadius.circular(3),
          )),
          // fluent draws a second, thicker underline on focus; the border
          // above already says "focused".
          foregroundDecoration: const WidgetStatePropertyAll(BoxDecoration()),
          prefix: Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Icon(FluentIcons.filter,
                size: 9, color: active ? _accent : _textLo),
          ),
          // A bare gesture target, not an IconButton: fluent's button carries
          // minimum-size constraints that overflow a 24px field.
          suffix: active
              ? GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _clear,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (widget.matchCount != null) ...[
                        Text('${widget.matchCount}',
                            style: const TextStyle(
                                color: _textLo,
                                fontSize: 10,
                                fontFamily: 'monospace')),
                        const SizedBox(width: 5),
                      ],
                      const Icon(FluentIcons.clear, size: 8, color: _textLo),
                    ]),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
