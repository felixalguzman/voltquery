import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
                      children: [for (final e in list) _row(ref, e)],
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

  Widget _row(WidgetRef ref, HistoryEntry e) {
    final ok = e.status == HistoryStatus.ok;
    final meta = ok
        ? '${e.rowCount ?? 0} rows · ${e.durationMs} ms'
        : (e.errorKind ?? 'error');
    return HoverButton(
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
    );
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
