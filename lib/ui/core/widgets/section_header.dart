import 'package:fluent_ui/fluent_ui.dart';

// TODO(theming #7): unify tokens into ui/core/theme.
const _hair = Color(0xFF262A31);
const _textMid = Color(0xFF9BA1AD);

/// Height of a sidebar section header. A collapsed section shrinks to exactly
/// this, so the title stays clickable — collapsing must never make a panel
/// unreachable.
const double kSectionHeaderHeight = 30;

/// The `CONNECTIONS` / `SCHEMA` / `HISTORY` strip at the top of a sidebar
/// section: a collapse chevron, the title, and the section's own actions.
///
/// Shared rather than repeated per panel so the three stay identical — they had
/// already drifted apart by a few pixels of padding before this existed.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actions = const [],
    this.collapsed = false,
    this.onToggle,
  });

  final String title;

  /// Trailing buttons (the vault padlock, schema refresh…).
  final List<Widget> actions;

  final bool collapsed;

  /// Null hides the chevron — a section that can't collapse shouldn't pretend.
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final header = Container(
      height: kSectionHeaderHeight,
      padding: EdgeInsets.only(left: onToggle == null ? 12 : 4, right: 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _hair)),
      ),
      child: Row(
        children: [
          if (onToggle != null) ...[
            AnimatedRotation(
              turns: collapsed ? -0.25 : 0,
              duration: const Duration(milliseconds: 120),
              child: const Icon(FluentIcons.chevron_down,
                  size: 9, color: _textMid),
            ),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(title,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: _textMid,
                    fontSize: 10.5,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w600)),
          ),
          ...actions,
        ],
      ),
    );

    if (onToggle == null) return header;
    // The whole strip toggles, not just the chevron — a 9px hit target for the
    // most-used control in the sidebar would be a nuisance. Actions sit inside
    // their own buttons, so they still win the tap.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onToggle,
      child: header,
    );
  }
}
