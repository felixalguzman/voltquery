import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/menu/confirm.dart';
import '../../core/menu/context_menu.dart';

import '../../../domain/models/history_entry.dart';
import '../query_workspace/worksheet_providers.dart';
import 'history_providers.dart';

// TODO(theming #7): unify tokens into ui/core/theme.
const _panel = Color(0xFF16181D);
const _hair = Color(0xFF262A31);
const _accent = Color(0xFF2FE6FF);
const _textHi = Color(0xFFE6E8EC);
const _textMid = Color(0xFF9BA1AD);
const _textLo = Color(0xFF5A6069);
const _ok = Color(0xFF6FE39A);
const _err = Color(0xFFFF6B6B);

/// Recent query history (persisted, ADR-0005). Click an entry to reload its SQL
/// into the active worksheet.
class HistoryPanel extends ConsumerWidget {
  const HistoryPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(recentHistoryProvider);
    return Container(
      decoration: const BoxDecoration(
        color: _panel,
        border: Border(top: BorderSide(color: _hair)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Header(),
          Expanded(
            child: history.when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) => _pad('$e'),
              data: (list) => list.isEmpty
                  ? _pad('(no history)')
                  : ListView(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      children: [for (final e in list) _row(context, ref, e)],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pad(String s) => Padding(
      padding: const EdgeInsets.all(12),
      child: Text(s, style: const TextStyle(color: _textLo, fontSize: 12)));

  Widget _row(BuildContext context, WidgetRef ref, HistoryEntry e) {
    final ok = e.status == HistoryStatus.ok;
    final meta = ok
        ? '${e.rowCount ?? 0} rows · ${e.durationMs} ms'
        : (e.errorKind ?? 'error');
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
        color: states.isHovered ? _accent.withValues(alpha: 0.08) : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: Row(children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
                color: ok ? _ok : _err, shape: BoxShape.circle),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.sql.replaceAll('\n', ' '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: _textHi, fontSize: 12, fontFamily: 'monospace'),
                ),
                Text(meta,
                    style: const TextStyle(color: _textLo, fontSize: 10.5)),
              ],
            ),
          ),
        ]),
        ),
      ),
    );
  }

  Future<void> _deleteEntry(
      BuildContext context, WidgetRef ref, HistoryEntry e) async {
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
      message: 'Every recorded statement is removed, including the UPDATEs '
          'generated by grid edits. This cannot be undone.',
      confirmLabel: 'Clear all',
    );
    if (yes) await ref.read(historyRepositoryProvider).clear();
  }
}

class _Header extends StatelessWidget {
  const _Header();
  @override
  Widget build(BuildContext context) => Container(
        height: 30,
        padding: const EdgeInsets.only(left: 12),
        alignment: Alignment.centerLeft,
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _hair)),
        ),
        child: const Text('HISTORY',
            style: TextStyle(
                color: _textMid,
                fontSize: 10.5,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w600)),
      );
}
