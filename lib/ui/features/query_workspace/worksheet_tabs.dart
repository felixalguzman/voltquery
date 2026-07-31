import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'worksheet_providers.dart';
import 'worksheet_view.dart';

// TODO(theming #7): unify tokens into ui/core/theme.
const _bg = Color(0xFF0D0E11);
const _panel = Color(0xFF16181D);
const _hair = Color(0xFF262A31);
const _accent = Color(0xFF2FE6FF);
const _textMid = Color(0xFF9BA1AD);
const _textLo = Color(0xFF5A6069);

/// The worksheet tab bar + bodies. Each tab is a Worksheet with its **own**
/// live Session (ADR-0002/0004) — an [IndexedStack] keeps every tab mounted so
/// its editor + result (and session) persist across switches; the tab is closed
/// → its `WorksheetView` unmounts → `worksheetSessionProvider` disposes → the
/// Session closes.
class WorksheetTabBar extends ConsumerWidget {
  const WorksheetTabBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabs = ref.watch(worksheetTabsProvider);
    final ctrl = ref.read(worksheetTabsProvider.notifier);
    final activeIndex = tabs.ids.indexOf(tabs.activeId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _strip(tabs, ctrl),
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

  Widget _strip(WorksheetTabsState tabs, WorksheetTabs ctrl) {
    return Container(
      height: 34,
      decoration: const BoxDecoration(
        color: _panel,
        border: Border(bottom: BorderSide(color: _hair)),
      ),
      child: Row(children: [
        Expanded(
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (var i = 0; i < tabs.ids.length; i++)
                _tab(tabs, ctrl, i),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(FluentIcons.add, size: 12, color: _textMid),
          onPressed: ctrl.add,
        ),
        const SizedBox(width: 4),
      ]),
    );
  }

  Widget _tab(WorksheetTabsState tabs, WorksheetTabs ctrl, int i) {
    final id = tabs.ids[i];
    final active = id == tabs.activeId;
    return GestureDetector(
      onTap: () => ctrl.select(id),
      child: Container(
        padding: const EdgeInsets.only(left: 12, right: 6),
        decoration: BoxDecoration(
          color: active ? _bg : _panel,
          border: Border(
            right: const BorderSide(color: _hair),
            bottom: BorderSide(
                color: active ? _accent : Colors.transparent, width: 2),
          ),
        ),
        child: Row(children: [
          Text('Query ${i + 1}',
              style: TextStyle(
                  color: active ? const Color(0xFFE6E8EC) : _textLo,
                  fontSize: 12)),
          const SizedBox(width: 6),
          if (tabs.ids.length > 1)
            IconButton(
              icon: const Icon(FluentIcons.chrome_close, size: 9, color: _textMid),
              onPressed: () => ctrl.close(id),
            )
          else
            const SizedBox(width: 8),
        ]),
      ),
    );
  }
}
