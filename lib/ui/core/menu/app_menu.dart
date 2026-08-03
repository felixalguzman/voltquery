import 'package:base_menu/base_menu.dart';
import 'package:fluent_ui/fluent_ui.dart';

import '../../core/theme/volt_tokens.dart';

/// Shared chrome for both the **menu bar** dropdowns (`app_shell`) and the tree
/// **context menus** (`schema_sidebar`, #53) — one dark surface + one row style
/// so every menu in the app matches. base_menu stays behind these widgets.
// TODO(theming #7): unify these tokens into ui/core/theme.

/// The dark, rounded, shadowed panel every dropdown/context menu floats on.
class MenuSurface extends StatelessWidget {
  const MenuSurface({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = VoltTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.panel,
        border: Border.all(color: t.hairline),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: t.shadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// A menu row: an optional leading [icon], a [label], and an optional right-side
/// [accel] hint — focus-highlighted via base_menu so keyboard and pointer share
/// one highlight. Used for both dropdown actions and context-menu actions.
class MenuActionRow extends StatelessWidget {
  const MenuActionRow(this.label, {super.key, this.accel, this.icon});
  final String label;
  final String? accel;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = VoltTheme.of(context);
    final focused = BaseMenuItem.isFocusHighlightShownOf(context);
    return Container(
      color: focused ? t.accent.withValues(alpha: 0.16) : null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: t.textMid),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: t.textHigh, fontSize: 12.5),
            ),
          ),
          if (accel != null) ...[
            const SizedBox(width: 24),
            Text(accel!, style: TextStyle(color: t.textMid, fontSize: 11)),
          ],
        ],
      ),
    );
  }
}

/// A thin divider between groups of menu rows.
class MenuDivider extends StatelessWidget {
  const MenuDivider({super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
    child: SizedBox(
      height: 1,
      child: ColoredBox(color: VoltTheme.of(context).hairline),
    ),
  );
}
