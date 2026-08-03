import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/volt_tokens.dart';

import '../../core/menu/confirm.dart';
import '../../core/menu/context_menu.dart';
import '../../core/widgets/filter_field.dart';
import '../../core/widgets/section_header.dart';

import '../../../domain/models/history_entry.dart';
import '../query_workspace/worksheet_providers.dart';
import 'history_providers.dart';

/// Recent query history (persisted, ADR-0005). Click an entry to reload its SQL
/// into the active worksheet.
class HistoryPanel extends ConsumerWidget {
  const HistoryPanel({super.key, this.collapsed = false, this.onToggle});

  final bool collapsed;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = VoltTheme.of(context);
    final history = ref.watch(recentHistoryProvider);
    final hideGenerated = ref.watch(hideGeneratedHistoryProvider);
    final filter = ref.watch(historyFilterProvider);
    // No top border: the pane resizer above draws that line now, and a second
    // one here overflows the section when it collapses to header height.
    return Container(
      decoration: BoxDecoration(color: t.panel),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: 'HISTORY',
            collapsed: collapsed,
            onToggle: onToggle,
            actions: [
              IconButton(
                icon: Icon(
                  FluentIcons.search,
                  size: 12,
                  color: filter.open ? t.accent : t.textLow,
                ),
                onPressed: ref.read(historyFilterProvider.notifier).toggle,
              ),
              Tooltip(
                message: hideGenerated
                    ? 'Showing only what you ran'
                    : 'Showing everything that ran',
                child: IconButton(
                  icon: Icon(
                    hideGenerated
                        ? FluentIcons.filter_solid
                        : FluentIcons.filter,
                    size: 12,
                    color: hideGenerated ? t.accent : t.textLow,
                  ),
                  onPressed: () =>
                      ref.read(hideGeneratedHistoryProvider.notifier).toggle(),
                ),
              ),
            ],
          ),
          if (!collapsed)
            FilterRow(
              state: filter,
              placeholder: 'Filter SQL…',
              onChanged: ref.read(historyFilterProvider.notifier).set,
            ),
          Expanded(
            child: history.when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) => _pad(t, '$e'),
              data: (all) {
                final list = all
                    .where((e) => !hideGenerated || !e.source.isGenerated)
                    .where((e) => matchesFilter(e.sql, filter.text))
                    .toList();
                if (list.isEmpty) {
                  return _pad(t, switch ((all.isEmpty, filter.active)) {
                    (true, _) => '(no history)',
                    (_, true) => '(no match)',
                    _ => '(nothing you ran by hand)',
                  });
                }
                return ListView(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  children: [for (final e in list) _row(context, ref, e)],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Says who wrote the statement, for anything the user didn't type.
  Widget _sourceTag(VoltTokens t, HistorySource source) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
    decoration: BoxDecoration(
      border: Border.all(color: t.hairline),
      borderRadius: BorderRadius.circular(3),
    ),
    child: Text(
      source.label,
      style: TextStyle(color: t.textMid, fontSize: 9, letterSpacing: 0.3),
    ),
  );

  Widget _pad(VoltTokens t, String s) => Padding(
    padding: const EdgeInsets.all(12),
    child: Text(s, style: TextStyle(color: t.textLow, fontSize: 12)),
  );

  /// "just now" · "14:32" · "Mar 4 14:32".
  ///
  /// The stamp was always stored and never shown, so "did I run that before or
  /// after the deploy?" had no answer. Relative for the last hour (the common
  /// "what did I just do" case), clock time for today, date beyond that.
  static String _when(DateTime at) {
    final now = DateTime.now();
    final ago = now.difference(at);
    if (ago.inMinutes < 1) return 'just now';
    if (ago.inMinutes < 60) return '${ago.inMinutes}m ago';
    final hhmm =
        '${at.hour.toString().padLeft(2, '0')}:'
        '${at.minute.toString().padLeft(2, '0')}';
    final sameDay =
        at.year == now.year && at.month == now.month && at.day == now.day;
    if (sameDay) return hhmm;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[at.month - 1]} ${at.day} $hhmm';
  }

  Widget _row(BuildContext context, WidgetRef ref, HistoryEntry e) {
    final t = VoltTheme.of(context);
    final ok = e.status == HistoryStatus.ok;
    final meta = [
      _when(e.startedAt),
      if (ok) '${e.rowCount ?? 0} rows' else (e.errorKind ?? 'error'),
      '${e.durationMs} ms',
    ].join(' · ');
    return ContextMenuRegion(
      actions: [
        MenuAction(
          'Copy SQL',
          () => Clipboard.setData(ClipboardData(text: e.sql)),
          icon: FluentIcons.copy,
        ),
        MenuAction(
          'Load into Editor',
          () => ref.read(requestedQueryProvider.notifier).request(e.sql),
          icon: FluentIcons.open_file,
        ),
        // Explicit, because a plain click only loads — history holds the
        // UPDATEs that grid edits generate, so running must be deliberate.
        MenuAction(
          'Run',
          () => ref
              .read(requestedQueryProvider.notifier)
              .request(e.sql, run: true),
          icon: FluentIcons.play,
        ),
        MenuAction.divider,
        MenuAction(
          'Delete Entry',
          () => _deleteEntry(context, ref, e),
          icon: FluentIcons.delete,
        ),
        MenuAction(
          'Clear History…',
          () => _clearHistory(context, ref),
          icon: FluentIcons.clear,
        ),
      ],
      child: HoverButton(
        onPressed: () =>
            ref.read(requestedQueryProvider.notifier).request(e.sql),
        builder: (context, states) => Container(
          color: states.isHovered ? t.accent.withValues(alpha: 0.08) : null,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: ok ? t.success : t.danger,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.sql.replaceAll('\n', ' '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        // Generated statements are dimmed rather than hidden:
                        // they really ran, so they stay auditable, but they
                        // shouldn't compete with what you typed.
                        color: e.source.isGenerated ? t.textMid : t.textHigh,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                    Row(
                      children: [
                        if (e.source.isGenerated) ...[
                          _sourceTag(t, e.source),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Text(
                            meta,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: t.textLow, fontSize: 10.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteEntry(
    BuildContext context,
    WidgetRef ref,
    HistoryEntry e,
  ) async {
    final id = e.id;
    if (id == null) return;
    final yes = await confirm(
      context,
      title: 'Delete this history entry?',
      message: 'This removes one entry. It cannot be undone.',
    );
    if (yes) await ref.read(historyRepositoryProvider).delete(id);
  }

  Future<void> _clearHistory(BuildContext context, WidgetRef ref) async {
    final yes = await confirm(
      context,
      title: 'Clear all query history?',
      message:
          'Every recorded statement is removed, including the UPDATEs '
          'generated by grid edits. This cannot be undone.',
      confirmLabel: 'Clear all',
    );
    if (yes) await ref.read(historyRepositoryProvider).clear();
  }
}
