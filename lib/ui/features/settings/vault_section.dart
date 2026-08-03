import 'package:cryptography/cryptography.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/volt_tokens.dart';

import '../connections/connection_providers.dart';
import '../connections/master_password_dialog.dart';
import 'settings_providers.dart';

// Palette lives in ui/core/theme (#7); these are local names for it.
const _accent = VoltPalette.accent;
const _text = VoltPalette.textHigh;
const _textMid = VoltPalette.textMid;
const _err = VoltPalette.danger;

/// Credentials vault controls (ADR-0006): lock state, re-keying, auto-lock.
class VaultSection extends ConsumerStatefulWidget {
  const VaultSection({super.key});

  @override
  ConsumerState<VaultSection> createState() => _VaultSectionState();
}

class _VaultSectionState extends ConsumerState<VaultSection> {
  String? _message;
  bool _messageIsError = false;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final unlocked = ref.watch(vaultLockProvider);
    final autoLock = ref.watch(settingsProvider).vaultAutoLockMinutes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(unlocked ? FluentIcons.unlock : FluentIcons.lock,
                size: 13, color: unlocked ? _accent : _textMid),
            const SizedBox(width: 8),
            Text(unlocked ? 'Vault unlocked' : 'Vault locked',
                style: const TextStyle(fontSize: 12.5, color: _text)),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Your saved connection passwords and SSH keys, encrypted with your '
          'master password. It is never stored — only a key derived from it, '
          'in memory, while unlocked.',
          style: TextStyle(fontSize: 11, height: 1.35, color: _textMid),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Button(
              onPressed: _busy ? null : _changePassword,
              child: const Text('Change master password'),
            ),
            const SizedBox(width: 8),
            if (unlocked)
              Button(onPressed: _lockNow, child: const Text('Lock now')),
          ],
        ),
        if (_message != null) ...[
          const SizedBox(height: 8),
          Text(_message!,
              style: TextStyle(
                  fontSize: 11.5, color: _messageIsError ? _err : _accent)),
        ],
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Auto-lock after (minutes)',
                      style: TextStyle(fontSize: 12.5, color: _text)),
                  SizedBox(height: 3),
                  Text(
                    'Re-locks the vault after this long without input. 0 keeps '
                    'it unlocked until you quit.',
                    style:
                        TextStyle(fontSize: 11, height: 1.35, color: _textMid),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 120,
              child: NumberBox<int>(
                value: autoLock,
                min: 0,
                max: 1440,
                mode: SpinButtonPlacementMode.inline,
                clearButton: false,
                onChanged: (v) => v == null
                    ? null
                    : ref
                        .read(settingsProvider.notifier)
                        .edit((p) => p.copyWith(vaultAutoLockMinutes: v)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _lockNow() async {
    final store = await ref.read(secretStoreProvider.future);
    store.lock();
    ref.read(vaultLockProvider.notifier).set(false);
    setState(() {
      _message = 'Vault locked.';
      _messageIsError = false;
    });
  }

  Future<void> _changePassword() async {
    final store = await ref.read(secretStoreProvider.future);
    if (!store.exists) {
      setState(() {
        _message = 'No vault yet — one is created the first time you save a '
            'connection password.';
        _messageIsError = true;
      });
      return;
    }
    if (!mounted) return;
    final entered = await showChangeMasterPasswordDialog(context);
    if (entered == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await store.changeMasterPassword(entered.current, entered.next);
      if (!mounted) return;
      setState(() {
        _message = 'Master password changed. Your saved secrets are unchanged.';
        _messageIsError = false;
      });
    } on SecretBoxAuthenticationError {
      if (!mounted) return;
      setState(() {
        _message = 'Wrong current password. Nothing was changed.';
        _messageIsError = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = 'Could not change the master password: $e';
        _messageIsError = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
