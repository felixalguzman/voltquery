import 'package:base_menu/base_menu.dart';
import 'package:flutter/widgets.dart';

import 'app_menu.dart';

/// One entry in a [ContextMenuRegion]: a labelled action (with an optional
/// leading [icon]), or a [MenuAction.divider] between groups.
class MenuAction {
  const MenuAction(this.label, this.onSelected, {this.icon})
    : isDivider = false;
  const MenuAction._divider()
    : label = '',
      onSelected = _noop,
      icon = null,
      isDivider = true;

  static const divider = MenuAction._divider();
  static void _noop() {}

  final String label;
  final IconData? icon;
  final VoidCallback onSelected;
  final bool isDivider;
}

/// Wraps [child] so a **right-click** (or long-press, for touch) opens [actions]
/// as a base_menu context menu anchored at the pointer (#53). Primary taps and
/// hover pass straight through — only the secondary gesture is claimed — so the
/// wrapped widget's own tap handling (e.g. a tree row opening a table) is intact.
///
/// This is the app's one context-menu primitive: it keeps base_menu behind our
/// own widget and reuses the shared [MenuSurface] / [MenuActionRow] chrome so
/// context menus match the menu bar.
class ContextMenuRegion extends StatefulWidget {
  const ContextMenuRegion({
    super.key,
    required this.child,
    required this.actions,
  });

  final Widget child;
  final List<MenuAction> actions;

  @override
  State<ContextMenuRegion> createState() => _ContextMenuRegionState();
}

class _ContextMenuRegionState extends State<ContextMenuRegion> {
  final _controller = MenuController();

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Nothing to offer → don't install a menu anchor at all.
    if (widget.actions.isEmpty) return widget.child;

    return BaseMenu(
      controller: _controller,
      consumeOutsideTaps: true,
      menu: MenuSurface(
        child: BaseMenuPanel(
          constraints: const BoxConstraints.tightFor(width: 220),
          children: [
            const SizedBox(height: 4),
            for (final a in widget.actions)
              a.isDivider
                  ? const MenuDivider()
                  : BaseMenuItem(
                      onPressed: a.onSelected,
                      child: MenuActionRow(a.label, icon: a.icon),
                    ),
            const SizedBox(height: 4),
          ],
        ),
      ),
      builder: (context, controller, child) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onSecondaryTapDown: (d) => controller.open(position: d.localPosition),
        onLongPressStart: (d) => controller.open(position: d.localPosition),
        child: child,
      ),
      child: widget.child,
    );
  }
}
