import 'package:cryptography/cryptography.dart'
    show SecretBoxAuthenticationError;
import 'package:file_selector/file_selector.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/volt_tokens.dart';
import '../../core/theme/engine_brand.dart';

import '../../../data/services/secret_store.dart';
import '../../../domain/models/connection.dart';
import '../../../domain/models/connection_options.dart';
import '../../../domain/models/engine.dart';
import '../query_workspace/worksheet_providers.dart';
import '../settings/settings_providers.dart';
import 'connection_providers.dart';
import 'master_password_dialog.dart';
import '../../core/menu/confirm.dart';
import '../../core/menu/context_menu.dart';
import '../../core/widgets/section_header.dart';
import 'server_form.dart';

/// Saved connections + the built-in demo. Click to switch (rebuilds the
/// sessions); "+" adds a SQLite file; hover a saved one to delete. Wires the
/// #14 wizard's connection-list role — the full add-wizard arrives with Postgres.
class ConnectionsPanel extends ConsumerWidget {
  const ConnectionsPanel({super.key, this.collapsed = false, this.onToggle});

  final bool collapsed;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = VoltTheme.of(context);
    // Riverpod 3: `value` is the nullable accessor; `valueOrNull` is gone.
    final saved =
        ref.watch(savedConnectionsProvider).value ?? const <Connection>[];
    final activeId = ref.watch(currentConnectionProvider).id;
    final unlocked = ref.watch(vaultLockProvider);

    return Container(
      decoration: BoxDecoration(color: t.panel),
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

  Widget _header(BuildContext context, WidgetRef ref, bool unlocked) {
    final t = VoltTheme.of(context);
    return SectionHeader(
      title: 'CONNECTIONS',
      collapsed: collapsed,
      onToggle: onToggle,
      actions: [
        IconButton(
          icon: Icon(
            unlocked ? FluentIcons.unlock : FluentIcons.lock,
            size: 12,
            color: unlocked ? t.accent : t.textMid,
          ),
          onPressed: () => _toggleLock(context, ref, unlocked),
        ),
        IconButton(
          icon: Icon(FluentIcons.add, size: 12, color: t.textMid),
          onPressed: () => _addMenu(context, ref),
        ),
      ],
    );
  }

  Future<void> _toggleLock(
    BuildContext context,
    WidgetRef ref,
    bool unlocked,
  ) async {
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
    BuildContext context,
    WidgetRef ref,
    SecretStore store,
  ) async {
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
          child: const Text('OK'),
        ),
      ],
    ),
  );

  /// Switches to [c]; if it needs a vault secret and the vault is locked,
  /// unlock first so the connection doesn't fail auth with a null password.
  Future<void> _select(
    BuildContext context,
    WidgetRef ref,
    Connection c,
  ) async {
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
        constraints: const BoxConstraints(maxWidth: 360),
        title: const Text('New connection'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 4),
            _choice(ctx, 'sqlite', Engine.sqlite, 'SQLite file…'),
            const SizedBox(height: 8),
            _choice(ctx, 'pg', Engine.postgres, 'PostgreSQL…'),
            const SizedBox(height: 8),
            _choice(ctx, 'mysql', Engine.mysql, 'MySQL / MariaDB…'),
          ],
        ),
        actions: [
          Button(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
    if (choice == 'sqlite') await _addSqlite(ref);
    if (choice == 'pg' && context.mounted) {
      await _addServer(context, ref, Engine.postgres);
    }
    if (choice == 'mysql' && context.mounted) {
      await _addServer(context, ref, Engine.mysql);
    }
  }

  /// A full-width engine choice for the New-connection dialog — stacked (not
  /// crammed into the actions Row) so long labels never wrap, with the engine's
  /// brand glyph in its brand colour.
  Widget _choice(BuildContext ctx, String value, Engine engine, String label) {
    final (icon, color) = engineBrand(engine);
    return Button(
      onPressed: () => Navigator.pop(ctx, value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 10),
            Text(label),
          ],
        ),
      ),
    );
  }

  Future<void> _addServer(
    BuildContext context,
    WidgetRef ref,
    Engine engine,
  ) async {
    final settings = ref.read(settingsProvider);
    final result = await showServerConnectionDialog(
      context,
      engine: engine,
      defaults: ConnectionOptions(
        sslMode: settings.defaultSslMode,
        connectTimeoutSeconds: settings.defaultConnectTimeoutSeconds,
      ),
    );
    if (!context.mounted) return;
    await _persist(context, ref, result, activate: true);
  }

  /// Reopens the form on a saved connection. Same dialog, prefilled — keeping
  /// the id, so the vault entry and history stay attached to it.
  Future<void> _editServer(
    BuildContext context,
    WidgetRef ref,
    Connection c,
  ) async {
    final result = await showServerConnectionDialog(
      context,
      engine: c.engine,
      existing: c,
    );
    if (!context.mounted) return;
    // Re-select only if it's already the active one, so editing a connection
    // in the background doesn't yank the workspace over to it.
    final isActive = ref.read(currentConnectionProvider).id == c.id;
    await _persist(context, ref, result, activate: isActive);
  }

  /// Saves a form result: writes the secret **only when one was entered**, so
  /// editing without touching the password leaves the vault entry intact.
  Future<void> _persist(
    BuildContext context,
    WidgetRef ref,
    ServerFormResult? result, {
    required bool activate,
  }) async {
    if (result == null || !context.mounted) return;
    final password = result.password;
    final ref_ = result.connection.credentialRef;

    final ssh = result.connection.options.ssh;
    final writes = <String, String>{
      if (password != null && ref_ != null) ref_: password,
      if (result.sshPassword case final p? when ssh.passwordRef != null)
        ssh.passwordRef!: p,
      if (result.sshPassphrase case final p? when ssh.passphraseRef != null)
        ssh.passphraseRef!: p,
    };
    if (writes.isNotEmpty) {
      final store = await ref.read(secretStoreProvider.future);
      if (!context.mounted) return;
      if (!await _unlockVault(context, ref, store)) return;
      for (final e in writes.entries) {
        await store.write(e.key, e.value);
      }
    }
    await ref.read(connectionRepositoryProvider).save(result.connection);
    if (activate) {
      ref.read(currentConnectionProvider.notifier).set(result.connection);
    }
  }

  /// Copies a saved connection, minting a new id so the two are independent.
  /// The secret is *not* copied — the vault is keyed by id, and duplicating a
  /// credential silently would be a surprising thing for a UI to do.
  Future<void> _duplicate(WidgetRef ref, Connection c) async {
    final id = const Uuid().v4();
    await ref
        .read(connectionRepositoryProvider)
        .save(
          Connection(
            id: id,
            name: '${c.name} (copy)',
            engine: c.engine,
            host: c.host,
            port: c.port,
            username: c.username,
            credentialRef: id,
            sqlitePath: c.sqlitePath,
            defaultDatabase: c.defaultDatabase,
            options: c.options,
          ),
        );
  }

  Widget _row(
    BuildContext context,
    WidgetRef ref,
    Connection c,
    String activeId, {
    bool builtIn = false,
  }) {
    final t = VoltTheme.of(context);
    final active = c.id == activeId;
    final (IconData icon, Color color) = engineBrand(c.engine);
    return ContextMenuRegion(
      actions: [
        if (!builtIn) ...[
          MenuAction(
            'Edit…',
            () => _editServer(context, ref, c),
            icon: FluentIcons.edit,
          ),
          MenuAction(
            'Duplicate',
            () => _duplicate(ref, c),
            icon: FluentIcons.copy,
          ),
          MenuAction.divider,
        ],
        MenuAction(
          'Copy Name',
          () => Clipboard.setData(ClipboardData(text: c.name)),
          icon: FluentIcons.text_field,
        ),
        if (!builtIn) ...[
          MenuAction.divider,
          MenuAction(
            'Delete…',
            () => _confirmDelete(context, ref, c, activeId),
            icon: FluentIcons.delete,
          ),
        ],
      ],
      child: HoverButton(
        onPressed: () => _select(context, ref, c),
        builder: (context, states) => Container(
          color: active ? t.accentWash : (states.isHovered ? t.hover : null),
          padding: EdgeInsets.only(
            left: c.options.colorTag == null ? 12 : 8,
            right: 6,
          ),
          height: 30,
          child: Row(
            children: [
              // Environment tag, when set: a red bar down the row is the
              // conventional "this is production" cue, and it needs to be visible
              // before you run anything, not buried in a settings dialog.
              if (c.options.colorTag case final tag?) ...[
                Container(
                  width: 3,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Color(tag),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 5),
              ],
              // Brand glyph (left). Right stays free for a live status dot (#14).
              SizedBox(width: 16, child: Icon(icon, size: 15, color: color)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  c.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active ? t.accent : t.textHigh,
                    fontSize: 12.5,
                  ),
                ),
              ),
              if (!builtIn && states.isHovered)
                IconButton(
                  icon: Icon(FluentIcons.delete, size: 11, color: t.textMid),
                  onPressed: () => _delete(ref, c, activeId),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Deleting a saved connection also drops its vault secret — leaving an
  /// orphaned credential behind would be a small, silent data leak.
  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Connection c,
    String activeId,
  ) async {
    final yes = await confirm(
      context,
      title: 'Delete "${c.name}"?',
      message:
          'The saved connection and its stored password are removed. '
          'This cannot be undone.',
    );
    if (!yes) return;
    await _delete(ref, c, activeId);
  }

  Future<void> _addSqlite(WidgetRef ref) async {
    const group = XTypeGroup(
      label: 'SQLite',
      extensions: ['db', 'sqlite', 'sqlite3'],
    );
    final file = await openFile(acceptedTypeGroups: [group]);
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
    // Drop the vault entry too. Removing the connection while leaving its
    // password behind orphans a secret nothing can reach or clean up.
    final refs = [
      c.credentialRef,
      c.options.ssh.passwordRef,
      c.options.ssh.passphraseRef,
    ].nonNulls;
    if (refs.isNotEmpty) {
      try {
        final store = await ref.read(secretStoreProvider.future);
        if (!store.isLocked) {
          for (final r in refs) {
            await store.delete(r);
          }
        }
      } catch (_) {
        // A locked or unreadable vault must not block removing the connection;
        // the row is already gone and that's what the user asked for.
      }
    }
    if (c.id == activeId) {
      ref.read(currentConnectionProvider.notifier).set(demoConnection);
    }
  }
}
