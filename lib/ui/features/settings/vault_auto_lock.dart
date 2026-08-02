import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../connections/connection_providers.dart';
import 'settings_providers.dart';

/// Re-locks the credentials vault after a stretch with no input, per
/// `AppSettings.vaultAutoLockMinutes`.
///
/// Wraps the app rather than living in a provider because "idle" is a UI fact:
/// it needs the pointer and keyboard streams. Locking only drops the derived
/// key from memory — nothing is lost, the next connection that needs a secret
/// prompts to unlock.
class VaultAutoLock extends ConsumerStatefulWidget {
  const VaultAutoLock({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<VaultAutoLock> createState() => _VaultAutoLockState();
}

class _VaultAutoLockState extends ConsumerState<VaultAutoLock> {
  /// Coarse on purpose: this decides *when to check*, not the timeout itself,
  /// so a minute of slack costs nothing and a per-second timer would burn
  /// wakeups for the entire session.
  static const _tick = Duration(seconds: 30);

  DateTime _lastActivity = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_tick, (_) => _maybeLock());
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    _timer?.cancel();
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent _) {
    _lastActivity = DateTime.now();
    return false; // observe only — never swallow the event
  }

  void _poke([PointerEvent? _]) => _lastActivity = DateTime.now();

  Future<void> _maybeLock() async {
    final minutes = ref.read(settingsProvider).vaultAutoLockMinutes;
    if (minutes <= 0) return;
    if (!ref.read(vaultLockProvider)) return; // already locked
    if (DateTime.now().difference(_lastActivity) < Duration(minutes: minutes)) {
      return;
    }
    final store = await ref.read(secretStoreProvider.future);
    store.lock();
    if (mounted) ref.read(vaultLockProvider.notifier).set(false);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      // Listening in the capture phase so activity registers even over widgets
      // that absorb the gesture (the grid, the editor).
      behavior: HitTestBehavior.translucent,
      onPointerDown: _poke,
      onPointerMove: _poke,
      onPointerSignal: _poke,
      child: widget.child,
    );
  }
}
