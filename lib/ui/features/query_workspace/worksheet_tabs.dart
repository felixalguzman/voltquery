import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/volt_tokens.dart';

import '../../core/menu/context_menu.dart';

import 'worksheet_providers.dart';
import 'worksheet_view.dart';

/// The worksheet tab bar + bodies. Each tab is a Worksheet with its **own**
/// live Session (ADR-0002/0004) — an [IndexedStack] keeps every tab mounted so
/// its editor + result (and session) persist across switches; the tab is closed
/// → its `WorksheetView` unmounts → `worksheetSessionProvider` disposes → the
/// Session closes.
class WorksheetTabBar extends ConsumerWidget {
  const WorksheetTabBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = VoltTheme.of(context);
    final tabs = ref.watch(worksheetTabsProvider);
    final ctrl = ref.read(worksheetTabsProvider.notifier);
    final activeIndex = tabs.ids.indexOf(tabs.activeId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _strip(t, tabs, ctrl),
        Expanded(
          child: IndexedStack(
            index: activeIndex < 0 ? 0 : activeIndex,
            children: [
              for (final id in tabs.ids)
                WorksheetView(key: ValueKey(id), worksheetId: id),
            ],
          ),
        ),
      ],
    );
  }

  Widget _strip(VoltTokens t, WorksheetTabsState tabs, WorksheetTabs ctrl) {
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: t.panel,
        border: Border(bottom: BorderSide(color: t.hairline)),
      ),
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (var i = 0; i < tabs.ids.length; i++)
                  _tab(t, tabs, ctrl, i),
              ],
            ),
          ),
          IconButton(
            icon: Icon(FluentIcons.add, size: 12, color: t.textMid),
            onPressed: ctrl.add,
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _tab(
    VoltTokens t,
    WorksheetTabsState tabs,
    WorksheetTabs ctrl,
    int i,
  ) {
    final id = tabs.ids[i];
    final active = id == tabs.activeId;
    final only = tabs.ids.length == 1;
    return ContextMenuRegion(
      actions: [
        MenuAction(
          'Close',
          () => only ? null : ctrl.close(id),
          icon: FluentIcons.chrome_close,
        ),
        MenuAction(
          'Close Others',
          () => only ? null : ctrl.closeOthers(id),
          icon: FluentIcons.clear_selection,
        ),
        MenuAction(
          'Close to the Right',
          () => ctrl.closeToRight(id),
          icon: FluentIcons.forward,
        ),
      ],
      child: GestureDetector(
        onTap: () => ctrl.select(id),
        child: Container(
          padding: const EdgeInsets.only(left: 12, right: 6),
          decoration: BoxDecoration(
            color: active ? t.canvas : t.panel,
            border: Border(
              right: BorderSide(color: t.hairline),
              bottom: BorderSide(
                color: active ? t.accent : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            children: [
              Text(
                'Query ${i + 1}',
                style: TextStyle(
                  color: active ? t.textHigh : t.textLow,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 6),
              if (tabs.ids.length > 1)
                IconButton(
                  icon: Icon(
                    FluentIcons.chrome_close,
                    size: 9,
                    color: t.textMid,
                  ),
                  onPressed: () => ctrl.close(id),
                )
              else
                const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}
