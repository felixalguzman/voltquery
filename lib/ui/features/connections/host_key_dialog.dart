import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';

import '../../core/theme/volt_tokens.dart';

import '../../../data/services/known_hosts.dart';

/// Asks whether to trust an SSH bastion's host key.
///
/// Two very different situations share this dialog, and the difference is the
/// whole point:
///
/// - **unknown** — first connection. Routine; `ssh(1)` asks the same thing.
/// - **changed** — this host answered with a *different* key than last time.
///   Either it was rebuilt, or something is impersonating it. That has to look
///   alarming rather than like another confirmation to click through.
Future<bool> showHostKeyDialog(
  BuildContext context, {
  required HostKeyVerdict verdict,
  required String host,
  required int port,
  required String fingerprint,
}) async {
  final changed = verdict == HostKeyVerdict.changed;
  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) {
      final t = VoltTheme.of(context);
      return ContentDialog(
        constraints: const BoxConstraints(maxWidth: 520),
        title: Row(
          children: [
            Icon(
              changed ? FluentIcons.warning : FluentIcons.lock,
              size: 16,
              color: changed ? t.danger : t.warning,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                changed ? 'This host key has CHANGED' : 'Unrecognised SSH host',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              changed
                  ? '$host:$port presented a different key than the one you '
                        'previously trusted.\n\n'
                        'This happens legitimately when a server is rebuilt or '
                        'rekeyed — but it is also exactly what a machine-in-the-'
                        'middle looks like. Do not continue unless you know the '
                        'host changed.'
                  : "You haven't connected to $host:$port before. Check that "
                        'this fingerprint matches the server — for example against '
                        '`ssh-keyscan $host`.',
              style: TextStyle(
                color: changed ? t.danger : t.textMid,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: t.canvas,
                border: Border.all(color: t.hairline),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      fingerprint,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: t.textHigh,
                      ),
                    ),
                  ),
                  Tooltip(
                    message: 'Copy fingerprint',
                    child: IconButton(
                      icon: Icon(FluentIcons.copy, size: 12, color: t.textMid),
                      onPressed: () =>
                          Clipboard.setData(ClipboardData(text: fingerprint)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Button(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          // Not a FilledButton on the changed path: the safe choice shouldn't be
          // the one styled as the obvious default.
          if (changed)
            Button(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Trust the new key'),
            )
          else
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Trust and connect'),
            ),
        ],
      );
    },
  );
  return accepted ?? false;
}
