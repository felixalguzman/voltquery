import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/volt_tokens.dart';

import '../../../data/services/known_hosts.dart';
import '../../core/menu/confirm.dart';
import '../query_workspace/worksheet_providers.dart';


/// The SSH bastions whose host keys have been accepted (`known_hosts.json`).
///
/// Trust-on-first-use without a way to review or revoke is only half a trust
/// model: a key accepted at a prompt is otherwise permanent and invisible.
class KnownHostsSection extends ConsumerStatefulWidget {
  const KnownHostsSection({super.key});

  @override
  ConsumerState<KnownHostsSection> createState() => _KnownHostsSectionState();
}

class _KnownHostsSectionState extends ConsumerState<KnownHostsSection> {
  VoltTokens get t => VoltTheme.of(context);
  late Future<List<KnownHost>> _hosts = _load();

  Future<List<KnownHost>> _load() async {
    final store = await ref.read(knownHostsProvider.future);
    return store.entries();
  }

  void _reload() => setState(() => _hosts = _load());

  @override
  Widget build(BuildContext context) {
    final t = VoltTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Trusted SSH hosts',
            style: TextStyle(fontSize: 12.5, color: t.textHigh)),
        const SizedBox(height: 3),
        Text(
          'Bastions whose host key you accepted. Revoking one means the next '
          'connection prompts again — do that if a server was rebuilt, or if '
          'you accepted a key you did not recognise.',
          style: TextStyle(fontSize: 11, height: 1.35, color: t.textMid),
        ),
        const SizedBox(height: 10),
        FutureBuilder<List<KnownHost>>(
          future: _hosts,
          builder: (context, snap) {
            if (snap.hasError) {
              return Text('Could not read known hosts: ${snap.error}',
                  style:
                      TextStyle(color: t.danger, fontSize: 11.5));
            }
            if (!snap.hasData) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                    width: 16,
                    height: 16,
                    child: ProgressRing(strokeWidth: 2)),
              );
            }
            final hosts = snap.data!;
            if (hosts.isEmpty) {
              return Text('No hosts trusted yet.',
                  style: TextStyle(
                      fontSize: 11.5,
                      color: t.textLow,
                      fontStyle: FontStyle.italic));
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [for (final h in hosts) _row(h)],
            );
          },
        ),
      ],
    );
  }

  Widget _row(KnownHost h) => Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: t.hairline)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText('${h.host}:${h.port}',
                      style: TextStyle(
                          fontSize: 12, fontFamily: 'monospace', color: t.textHigh)),
                  const SizedBox(height: 2),
                  // Selectable so it can be compared against `ssh-keyscan`
                  // output by copy-paste rather than by squinting.
                  SelectableText(
                    h.keyType.isEmpty
                        ? h.fingerprint
                        : '${h.keyType}  ${h.fingerprint}',
                    style: TextStyle(
                        fontSize: 10.5,
                        fontFamily: 'monospace',
                        color: t.textMid),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Button(
              onPressed: () => _revoke(h),
              child: const Text('Revoke'),
            ),
          ],
        ),
      );

  Future<void> _revoke(KnownHost h) async {
    final ok = await confirm(
      context,
      title: 'Revoke ${h.host}:${h.port}?',
      message: 'The next connection through this bastion will prompt you to '
          'verify its host key again.',
      confirmLabel: 'Revoke',
    );
    if (!ok) return;
    final store = await ref.read(knownHostsProvider.future);
    await store.forget(h.host, h.port);
    if (mounted) _reload();
  }
}
