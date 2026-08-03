import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/volt_tokens.dart';

import '../../../data/drivers/driver_factory.dart';
import '../../../domain/drivers/driver_error.dart';
import '../../../domain/drivers/driver_error_help.dart';
import '../../../domain/models/connection_options.dart';
import '../../../domain/models/ssh_config.dart';
import '../../../domain/models/ssl_mode.dart';
import '../../../domain/drivers/result.dart';
import '../../../domain/models/connection.dart';
import '../../../domain/models/engine.dart';

/// A secret-free [Connection] plus the password to hand to the vault.
///
/// [password] is null when editing and the field was left untouched — meaning
/// "keep the stored secret". An empty string is a real (if unwise) password, so
/// the two cases can't be collapsed.
typedef ServerFormResult = ({
  Connection connection,
  String? password,
  String? sshPassword,
  String? sshPassphrase,
});

/// Connection form for a server engine (Postgres / MySQL) with an inline
/// **Test connection**. The #14 wizard's server branch.
///
/// Pass [existing] to edit a saved connection instead of creating one: the same
/// form, prefilled, keeping the id and credential ref so the vault entry and any
/// history stay attached.
///
/// [defaults] seeds a **new** connection's options (Settings → Connections). It
/// is ignored when editing — a saved connection's own options always win, or
/// changing a default would silently rewrite connections that already work.
Future<ServerFormResult?> showServerConnectionDialog(
  BuildContext context, {
  required Engine engine,
  Connection? existing,
  ConnectionOptions? defaults,
}) {
  return showDialog<ServerFormResult>(
    context: context,
    builder: (_) => _ServerDialog(
      engine: engine,
      existing: existing,
      defaults: defaults,
    ),
  );
}

enum _Test { idle, testing, ok, error }

class _ServerDialog extends StatefulWidget {
  const _ServerDialog({required this.engine, this.existing, this.defaults});
  final Engine engine;

  /// Non-null when editing a saved connection.
  final Connection? existing;

  /// Starting options for a new connection, from app settings.
  final ConnectionOptions? defaults;

  @override
  State<_ServerDialog> createState() => _ServerDialogState();
}

class _ServerDialogState extends State<_ServerDialog> {
  Connection? get _existing => widget.existing;
  bool get _isEdit => _existing != null;

  late final _name = TextEditingController(
      text: _existing?.name ?? (_isPg ? 'Postgres' : 'MySQL'));
  late final _host =
      TextEditingController(text: _existing?.host ?? 'localhost');
  late final _port = TextEditingController(
      text: '${_existing?.port ?? (_isPg ? 5432 : 3306)}');
  late final _user = TextEditingController(
      text: _existing?.username ?? (_isPg ? 'postgres' : 'root'));
  final _password = TextEditingController();
  late final _database = TextEditingController(
      text: _existing?.defaultDatabase ?? (_isPg ? 'postgres' : ''));

  /// Everything on the Security/Advanced tabs. Defaults to `require` TLS:
  /// encryption is opted out of, and MySQL 8's default auth plugin refuses to
  /// authenticate over a plaintext socket.
  late ConnectionOptions _options =
      _existing?.options ?? widget.defaults ?? const ConnectionOptions();
  late final _caCert =
      TextEditingController(text: _existing?.options.caCertPath ?? '');

  late final _sshHost =
      TextEditingController(text: _existing?.options.ssh.host ?? '');
  late final _sshPort =
      TextEditingController(text: '${_existing?.options.ssh.port ?? 22}');
  late final _sshUser =
      TextEditingController(text: _existing?.options.ssh.username ?? '');
  final _sshPassword = TextEditingController();
  late final _sshKeyPath = TextEditingController(
      text: _existing?.options.ssh.privateKeyPath ?? '');
  final _sshPassphrase = TextEditingController();
  int _tab = 0;

  SslMode get _ssl => _options.sslMode;

  _Test _test = _Test.idle;
  String _testMsg = '';

  /// Kept alongside the message so the failure can be explained, not just
  /// reprinted.
  DriverError? _error;
  bool _showRaw = false;

  /// mysql_client accepts any certificate, so it cannot offer verify-full —
  /// see Capabilities.verifiesTlsCertificates.
  bool get _canVerify =>
      driverFor(widget.engine).capabilities.verifiesTlsCertificates;

  List<SslMode> get _sslModes => [
    SslMode.disable,
    SslMode.require,
    if (_canVerify) SslMode.verifyFull,
  ];

  bool get _isPg => widget.engine == Engine.postgres;
  String get _dbLabel => _isPg ? 'PostgreSQL' : 'MySQL';

  @override
  void dispose() {
    for (final c in [
      _name,
      _host,
      _port,
      _user,
      _password,
      _database,
      _caCert,
      _sshHost,
      _sshPort,
      _sshUser,
      _sshPassword,
      _sshKeyPath,
      _sshPassphrase,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Connection _connection({required bool forSave}) {
    // Editing keeps the id (and so the vault entry and history association);
    // only a brand-new connection mints one.
    final id = _existing?.id ?? (forSave ? const Uuid().v4() : 'test');
    return Connection(
      id: id,
      name: _name.text.trim().isEmpty ? _host.text.trim() : _name.text.trim(),
      engine: widget.engine,
      host: _host.text.trim(),
      port: int.tryParse(_port.text.trim()) ?? (_isPg ? 5432 : 3306),
      username: _user.text.trim(),
      credentialRef: _existing?.credentialRef ?? (forSave ? id : null),
      defaultDatabase: _database.text.trim().isEmpty
          ? null
          : _database.text.trim(),
      options: _options.copyWith(
        caCertPath: _caCert.text.trim().isEmpty ? null : _caCert.text.trim(),
        // Vault keys derived from the connection id, so they travel with it and
        // are removed with it. The secrets themselves never touch the options.
        ssh: _options.ssh.copyWith(
          passwordRef: '$id/ssh-password',
          passphraseRef: '$id/ssh-passphrase',
        ),
      ),
    );
  }

  Future<void> _runTest() async {
    setState(() {
      _test = _Test.testing;
      _testMsg = '';
    });
    try {
      final session = await driverFor(
        widget.engine,
      ).connect(_connection(forSave: false), secret: _password.text);
      var server = 'Connected';
      try {
        final result = await session.execute('SELECT version()');
        if (result is RowsResult) {
          final rows = await result.cursor.fetch(1);
          final v = rows.first.values.first?.toString();
          if (v != null && v.isNotEmpty) {
            server = v.split(' ').take(2).join(' ');
          }
          await result.cursor.close();
        }
      } catch (_) {
        /* version is best-effort */
      }
      await session.close();
      _setResult(_Test.ok, server);
    } on DriverError catch (e) {
      _setResult(_Test.error, '${e.kind.name}: ${e.message}', error: e);
    } catch (e) {
      _setResult(_Test.error, e.toString());
    }
  }

  void _setResult(_Test test, String msg, {DriverError? error}) {
    if (!mounted) return;
    setState(() {
      _test = test;
      _testMsg = msg;
      _error = error;
      _showRaw = false;
    });
  }

  /// Applies a suggested fix and immediately retries — the point of offering it
  /// is to save the trip through the Security tab.
  void _applyRemedy(ErrorRemedy remedy) {
    final mode = DriverErrorHelper.modeFor(remedy);
    if (mode == null) return;
    setState(() => _options = _options.copyWith(sslMode: mode));
    _runTest();
  }

  void _save() {
    // Same rule for every secret: untouched while editing means "keep what's
    // stored", which null expresses and an empty string cannot.
    String? entered(TextEditingController c) =>
        _isEdit && c.text.isEmpty ? null : c.text;
    Navigator.pop(context, (
      connection: _connection(forSave: true),
      password: entered(_password),
      sshPassword: entered(_sshPassword),
      sshPassphrase: entered(_sshPassphrase),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 480),
      title: Text(_isEdit ? 'Edit $_dbLabel connection' : 'New $_dbLabel connection'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tabbed rather than one flat form: SSH alone would add half a
          // dozen more fields, and connection dialogs become unusable that way.
          _tabStrip(),
          const SizedBox(height: 12),
          // maxHeight, not a fixed height: a short tab (SSH, Security) then
          // sizes to its content instead of leaving dead space, and only a tab
          // that genuinely overflows scrolls.
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: Scrollbar(
              child: SingleChildScrollView(
                // Gutter for the scrollbar. Without it the thumb is drawn over
                // the fields themselves, slicing through the right-hand inputs.
                padding: const EdgeInsets.only(right: 14),
                child: _tabBody(),
              ),
            ),
          ),
          const SizedBox(height: 6),
          _testRow(),
        ],
      ),
      actions: [
        Button(
          child: const Text('Cancel'),
          onPressed: () => Navigator.pop(context),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(_isEdit ? 'Save' : 'Save & connect'),
        ),
      ],
    );
  }

  Widget _testRow() {
    // Idle and success are one short line, so they sit beside the button.
    // A failure is a headline plus a hint plus actions — cramming that into
    // half the dialog width wraps it into an unreadable column.
    final inline = _test != _Test.error;
    final button = Button(
      onPressed: _test == _Test.testing ? null : _runTest,
      child: const Text('⚡ Test connection'),
    );
    if (inline) {
      return Row(
        children: [
          button,
          const SizedBox(width: 10),
          Expanded(child: _status()),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(alignment: Alignment.centerLeft, child: button),
        const SizedBox(height: 8),
        _status(),
      ],
    );
  }

  Widget _status() {
    switch (_test) {
      case _Test.idle:
        return const SizedBox.shrink();
      case _Test.testing:
        return const Row(
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: ProgressRing(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text(
              'Testing…',
              style: TextStyle(color: VoltPalette.textMid, fontSize: 12),
            ),
          ],
        );
      case _Test.ok:
        return Text(
          '✔ $_testMsg',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: VoltPalette.success, fontSize: 12),
        );
      case _Test.error:
        // The driver's own text explains the failure to whoever wrote the
        // driver, not to the person looking at this dialog — the postgres
        // package answers "no SSL" by naming a Dart constructor. Lead with what
        // to do; keep the raw message one click away for searching.
        final help = DriverErrorHelper(widget.engine).help(
          _error ?? DriverError(DriverErrorKind.unknown, _testMsg),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1, right: 6),
                  child: Icon(FluentIcons.error_badge,
                      size: 12, color: VoltPalette.danger),
                ),
                Expanded(
                  child: Text(
                    help.headline,
                    style: const TextStyle(
                        color: VoltPalette.danger, fontSize: 12),
                  ),
                ),
              ],
            ),
            if (help.hint case final hint?)
              Padding(
                padding: const EdgeInsets.only(left: 18, top: 3),
                child: Text(
                  hint,
                  style: const TextStyle(
                      color: VoltPalette.textMid, fontSize: 11),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(left: 18, top: 6),
              child: Row(
                children: [
                  // A fix we can apply beats an instruction to go and apply it.
                  if (help.remedy case final remedy?) ...[
                    Button(
                      onPressed: () => _applyRemedy(remedy),
                      child: Text(help.remedyLabel ?? 'Fix',
                          style: const TextStyle(fontSize: 11)),
                    ),
                    const SizedBox(width: 8),
                  ],
                  HoverButton(
                    onPressed: () => setState(() => _showRaw = !_showRaw),
                    builder: (context, states) => Text(
                      _showRaw ? 'Hide details' : 'Details',
                      style: const TextStyle(
                          color: VoltPalette.accent, fontSize: 11),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Copy error',
                    child: IconButton(
                      icon: const Icon(FluentIcons.copy,
                          size: 12, color: VoltPalette.textMid),
                      onPressed: () =>
                          Clipboard.setData(ClipboardData(text: _testMsg)),
                    ),
                  ),
                ],
              ),
            ),
            if (_showRaw)
              Padding(
                padding: const EdgeInsets.only(left: 18, top: 4),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 72),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      _testMsg,
                      style: const TextStyle(
                          color: VoltPalette.textLow,
                          fontSize: 10.5,
                          fontFamily: 'monospace'),
                    ),
                  ),
                ),
              ),
          ],
        );
    }
  }

  static const _tabs = ['General', 'Security', 'SSH', 'Advanced'];

  Widget _tabStrip() => Row(
        children: [
          for (var i = 0; i < _tabs.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: HoverButton(
                onPressed: () => setState(() => _tab = i),
                builder: (context, states) => Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _tab == i
                        ? VoltPalette.accentWash
                        : (states.isHovered ? VoltPalette.hover : null),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _tab == i
                          ? VoltPalette.accent
                          : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    _tabs[i],
                    style: TextStyle(
                      fontSize: 12,
                      color: _tab == i
                          ? VoltPalette.accent
                          : VoltPalette.textMid,
                    ),
                  ),
                ),
              ),
            ),
        ],
      );

  Widget _tabBody() => switch (_tab) {
        0 => _generalTab(),
        1 => _securityTab(),
        2 => _sshTab(),
        _ => _advancedTab(),
      };

  Widget _generalTab() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _field('Name', _name),
          Row(children: [
            Expanded(flex: 3, child: _field('Host', _host)),
            const SizedBox(width: 10),
            Expanded(child: _field('Port', _port)),
          ]),
          Row(children: [
            Expanded(child: _field('User', _user)),
            const SizedBox(width: 10),
            Expanded(
              child: _field(
                _isEdit ? 'Password (unchanged)' : 'Password',
                _password,
                obscure: true,
              ),
            ),
          ]),
          _field('Database', _database),
          _colorTagField(),
        ],
      );

  Widget _securityTab() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sslField(),
          const SizedBox(height: 4),
          Checkbox(
            checked: _options.readOnly,
            onChanged: (v) =>
                setState(() => _options = _options.copyWith(readOnly: v)),
            content: const Text('Read-only (block grid edits)',
                style: TextStyle(fontSize: 12)),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 26, top: 2),
            child: Text(
              'Stops VoltQuery generating DML for this connection. A UI guard, '
              'not a server-side permission.',
              style: TextStyle(color: VoltPalette.textLow, fontSize: 10.5),
            ),
          ),
        ],
      );

  Widget _sshTab() {
    final ssh = _options.ssh;
    void update(SshConfig next) =>
        setState(() => _options = _options.copyWith(ssh: next));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Checkbox(
          checked: ssh.enabled,
          onChanged: (v) => update(ssh.copyWith(enabled: v ?? false)),
          content: const Text('Connect through an SSH tunnel',
              style: TextStyle(fontSize: 12)),
        ),
        const Padding(
          padding: EdgeInsets.only(left: 26, top: 2, bottom: 8),
          child: Text(
            'The database host and port above are resolved on the far side of '
            'the tunnel — "localhost" means localhost as the bastion sees it.',
            style: TextStyle(color: VoltPalette.textLow, fontSize: 10.5),
          ),
        ),
        if (ssh.enabled) ...[
          Row(children: [
            Expanded(
              flex: 3,
              child: _plainField('SSH host', _sshHost,
                  onChanged: (v) => update(ssh.copyWith(host: v.trim()))),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _plainField('Port', _sshPort,
                  onChanged: (v) => update(
                      ssh.copyWith(port: int.tryParse(v.trim()) ?? 22))),
            ),
          ]),
          _plainField('SSH user', _sshUser,
              onChanged: (v) => update(ssh.copyWith(username: v.trim()))),
          InfoLabel(
            label: 'Authentication',
            labelStyle:
                const TextStyle(fontSize: 12, color: VoltPalette.textMid),
            child: ComboBox<SshAuthMode>(
              value: ssh.authMode,
              isExpanded: true,
              items: [
                for (final m in SshAuthMode.values)
                  ComboBoxItem(
                    value: m,
                    child: Text(m.label, style: const TextStyle(fontSize: 12)),
                  ),
              ],
              onChanged: (m) =>
                  update(ssh.copyWith(authMode: m ?? ssh.authMode)),
            ),
          ),
          const SizedBox(height: 10),
          if (ssh.authMode == SshAuthMode.password)
            _plainField('SSH password', _sshPassword, obscure: true)
          else ...[
            _plainField('Private key file', _sshKeyPath,
                onChanged: (v) =>
                    update(ssh.copyWith(privateKeyPath: v.trim()))),
            _plainField('Key passphrase (if any)', _sshPassphrase,
                obscure: true),
          ],
        ],
      ],
    );
  }

  /// A labelled text field that reports changes — the SSH fields write straight
  /// into the options object rather than being read back at save time, so the
  /// enabled/auth-mode branches above always reflect what's typed.
  Widget _plainField(String label, TextEditingController c,
      {bool obscure = false, ValueChanged<String>? onChanged}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InfoLabel(
        label: label,
        labelStyle: const TextStyle(fontSize: 12, color: VoltPalette.textMid),
        child: TextBox(
          controller: c,
          obscureText: obscure,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _advancedTab() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.engine == Engine.sqlite)
            Checkbox(
              checked: _options.enforceForeignKeys,
              onChanged: (v) => setState(
                  () => _options = _options.copyWith(enforceForeignKeys: v)),
              content: const Text('Enforce foreign keys',
                  style: TextStyle(fontSize: 12)),
            ),
          InfoLabel(
            label: 'Connect timeout (seconds)',
            labelStyle:
                const TextStyle(fontSize: 12, color: VoltPalette.textMid),
            child: NumberBox<int>(
              value: _options.connectTimeoutSeconds,
              min: 1,
              max: 300,
              mode: SpinButtonPlacementMode.inline,
              onChanged: (v) => setState(() =>
                  _options = _options.copyWith(connectTimeoutSeconds: v ?? 15)),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Driver properties (engine-specific pass-through) are stored with '
            'the connection; an editor for them comes with the SSH slice.',
            style: TextStyle(color: VoltPalette.textLow, fontSize: 10.5),
          ),
        ],
      );

  /// Red-means-production. Surfaced in the connections list so the environment
  /// is unmistakable before you run anything.
  Widget _colorTagField() {
    const swatches = <int?>[
      null,
      0xFFFF6B6B, // production
      0xFFE8B84B, // staging
      0xFF6FE39A, // development
      0xFF2FE6FF,
      0xFFB98CFF,
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InfoLabel(
        label: 'Colour tag',
        labelStyle: const TextStyle(fontSize: 12, color: VoltPalette.textMid),
        child: Row(
          children: [
            for (final c in swatches)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: HoverButton(
                  onPressed: () =>
                      setState(() => _options = ConnectionOptions(
                            sslMode: _options.sslMode,
                            caCertPath: _options.caCertPath,
                            enforceForeignKeys: _options.enforceForeignKeys,
                            colorTag: c,
                            readOnly: _options.readOnly,
                            connectTimeoutSeconds:
                                _options.connectTimeoutSeconds,
                            driverProperties: _options.driverProperties,
                          )),
                  builder: (context, states) => Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: c == null ? Colors.transparent : Color(c),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _options.colorTag == c
                            ? VoltPalette.textHigh
                            : VoltPalette.chip,
                        width: _options.colorTag == c ? 2 : 1,
                      ),
                    ),
                    child: c == null
                        ? const Icon(FluentIcons.clear,
                            size: 9, color: VoltPalette.textLow)
                        : null,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sslField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InfoLabel(
        label: 'TLS',
        labelStyle: const TextStyle(fontSize: 12, color: VoltPalette.textMid),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ComboBox<SslMode>(
              value: _ssl,
              isExpanded: true,
              items: [
                for (final m in _sslModes)
                  ComboBoxItem(
                    value: m,
                    child: Text(m.label, style: const TextStyle(fontSize: 12)),
                  ),
              ],
              onChanged: (m) => setState(
                  () => _options = _options.copyWith(sslMode: m ?? _ssl)),
            ),
            const SizedBox(height: 4),
            Text(
              _canVerify
                  ? _ssl.description
                  : '${_ssl.description}  MySQL cannot verify certificates.',
              style: const TextStyle(color: VoltPalette.textLow, fontSize: 10.5),
            ),
            // Only meaningful when the certificate is actually checked.
            if (_ssl == SslMode.verifyFull) ...[
              const SizedBox(height: 8),
              _field('CA certificate (optional, PEM)', _caCert),
            ],
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController c, {bool obscure = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InfoLabel(
        label: label,
        child: TextBox(controller: c, obscureText: obscure),
      ),
    );
  }
}
