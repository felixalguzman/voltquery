import 'package:cryptography/cryptography.dart' show SecretBoxAuthenticationError;
import 'package:file_selector/file_selector.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../data/services/secret_store.dart';
import '../../../domain/models/connection.dart';
import '../../../domain/models/engine.dart';
import '../query_workspace/worksheet_providers.dart';
import 'connection_providers.dart';
import 'master_password_dialog.dart';
import 'postgres_form.dart';

// TODO(theming #7): unify tokens into ui/core/theme.
const _panel = Color(0xFF16181D);
const _hair = Color(0xFF262A31);
const _accent = Color(0xFF2FE6FF);
const _accentDim = Color(0x1F2FE6FF);
const _textHi = Color(0xFFE6E8EC);
const _textMid = Color(0xFF9BA1AD);
const _textLo = Color(0xFF5A6069);
const _sqliteBadge = Color(0xFF8A93A3);
const _pgBadge = Color(0xFF4E9BF0);

/// Saved connections + the built-in demo. Click to switch (rebuilds the
/// sessions); "+" adds a SQLite file; hover a saved one to delete. Wires the
/// #14 wizard's connection-list role — the full add-wizard arrives with Postgres.
class ConnectionsPanel extends ConsumerWidget {
  const ConnectionsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedConnectionsProvider).valueOrNull ??
        const <Connection>[];
    final activeId = ref.watch(currentConnectionProvider).id;
    final unlocked = ref.watch(vaultLockProvider);

    return Container(
      decoration: const BoxDecoration(color: _panel),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(context, ref, unlocked),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: [
                _row(context, ref, demoConnection, activeId, builtIn: true),
                for (final c in saved) _row(context, ref, c, activeId),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, WidgetRef ref, bool unlocked) =>
      Container(
        height: 30,
        padding: const EdgeInsets.only(left: 12, right: 6),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _hair)),
        ),
        child: Row(children: [
          const Text('CONNECTIONS',
              style: TextStyle(
                  color: _textLo,
                  fontSize: 10.5,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w600)),
          const Spacer(),
          IconButton(
            icon: Icon(unlocked ? FluentIcons.unlock : FluentIcons.lock,
                size: 12, color: unlocked ? _accent : _textMid),
            onPressed: () => _toggleLock(context, ref, unlocked),
          ),
          IconButton(
            icon: const Icon(FluentIcons.add, size: 12, color: _textMid),
            onPressed: () => _addMenu(context, ref),
          ),
        ]),
      );

  Future<void> _toggleLock(
      BuildContext context, WidgetRef ref, bool unlocked) async {
    final store = await ref.read(secretStoreProvider.future);
    if (unlocked) {
      store.lock();
      ref.read(vaultLockProvider.notifier).set(false);
      return;
    }
    if (!context.mounted) return;
    await _unlockVault(context, ref, store);
  }

  /// Ensures the vault is unlocked (creating it on first run). Returns true on
  /// success.
  Future<bool> _unlockVault(
      BuildContext context, WidgetRef ref, SecretStore store) async {
    if (!store.isLocked) return true;
    final pw = await showMasterPasswordDialog(context, isNew: !store.exists);
    if (pw == null) return false;
    try {
      await store.unlock(pw);
      ref.read(vaultLockProvider.notifier).set(true);
      return true;
    } on SecretBoxAuthenticationError {
      if (context.mounted) await _error(context, 'Wrong master password.');
      return false;
    }
  }

  Future<void> _error(BuildContext context, String message) => showDialog(
        context: context,
        builder: (ctx) => ContentDialog(
          content: Text(message),
          actions: [
            FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK')),
          ],
        ),
      );

  /// Switches to [c]; if it needs a vault secret and the vault is locked,
  /// unlock first so the connection doesn't fail auth with a null password.
  Future<void> _select(
      BuildContext context, WidgetRef ref, Connection c) async {
    if (c.credentialRef != null) {
      final store = await ref.read(secretStoreProvider.future);
      if (store.isLocked) {
        if (!context.mounted) return;
        if (!await _unlockVault(context, ref, store)) return;
      }
    }
    ref.read(currentConnectionProvider.notifier).set(c);
  }

  Future<void> _addMenu(BuildContext context, WidgetRef ref) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: const Text('New connection'),
        actions: [
          Button(
              child: const Text('SQLite file…'),
              onPressed: () => Navigator.pop(ctx, 'sqlite')),
          FilledButton(
              child: const Text('PostgreSQL…'),
              onPressed: () => Navigator.pop(ctx, 'pg')),
          Button(child: const Text('Cancel'), onPressed: () => Navigator.pop(ctx)),
        ],
      ),
    );
    if (choice == 'sqlite') await _addSqlite(ref);
    if (choice == 'pg' && context.mounted) await _addPostgres(context, ref);
  }

  Future<void> _addPostgres(BuildContext context, WidgetRef ref) async {
    final result = await showPostgresConnectionDialog(context);
    if (result == null || !context.mounted) return;
    final store = await ref.read(secretStoreProvider.future);
    if (!context.mounted) return;
    if (!await _unlockVault(context, ref, store)) return;
    await store.write(result.connection.credentialRef!, result.password);
    await ref.read(connectionRepositoryProvider).save(result.connection);
    ref.read(currentConnectionProvider.notifier).set(result.connection);
  }

  Widget _row(BuildContext context, WidgetRef ref, Connection c, String activeId,
      {bool builtIn = false}) {
    final active = c.id == activeId;
    final isPg = c.engine == Engine.postgres;
    return HoverButton(
      onPressed: () => _select(context, ref, c),
      builder: (context, states) => Container(
        color: active ? _accentDim : (states.isHovered ? const Color(0x14FFFFFF) : null),
        padding: const EdgeInsets.only(left: 12, right: 6),
        height: 30,
        child: Row(children: [
          Container(
            width: 16,
            height: 16,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: isPg ? _pgBadge : _sqliteBadge,
                borderRadius: BorderRadius.circular(3)),
            child: Text(isPg ? 'P' : 'S',
                style: const TextStyle(
                    color: Color(0xFF08121C),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace')),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(c.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: active ? _accent : _textHi, fontSize: 12.5)),
          ),
          if (!builtIn && states.isHovered)
            IconButton(
              icon: const Icon(FluentIcons.delete, size: 11, color: _textMid),
              onPressed: () => _delete(ref, c, activeId),
            ),
        ]),
      ),
    );
  }

  Future<void> _addSqlite(WidgetRef ref) async {
    const group = XTypeGroup(
        label: 'SQLite', extensions: ['db', 'sqlite', 'sqlite3']);
    final file = await openFile(acceptedTypeGroups: const [group]);
    if (file == null) return;
    final conn = Connection(
      id: const Uuid().v4(),
      name: file.name,
      engine: Engine.sqlite,
      sqlitePath: file.path,
    );
    await ref.read(connectionRepositoryProvider).save(conn);
    ref.read(currentConnectionProvider.notifier).set(conn);
  }

  Future<void> _delete(WidgetRef ref, Connection c, String activeId) async {
    await ref.read(connectionRepositoryProvider).delete(c.id);
    if (c.id == activeId) {
      ref.read(currentConnectionProvider.notifier).set(demoConnection);
    }
  }
}
