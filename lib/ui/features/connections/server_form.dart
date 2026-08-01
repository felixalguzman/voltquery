import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../../data/drivers/driver_factory.dart';
import '../../../domain/drivers/driver_error.dart';
import '../../../domain/models/connection_options.dart';
import '../../../domain/models/ssl_mode.dart';
import '../../../domain/drivers/result.dart';
import '../../../domain/models/connection.dart';
import '../../../domain/models/engine.dart';

/// A secret-free [Connection] plus the password to hand to the vault.
///
/// [password] is null when editing and the field was left untouched — meaning
/// "keep the stored secret". An empty string is a real (if unwise) password, so
/// the two cases can't be collapsed.
typedef ServerFormResult = ({Connection connection, String? password});

/// Connection form for a server engine (Postgres / MySQL) with an inline
/// **Test connection**. The #14 wizard's server branch.
///
/// Pass [existing] to edit a saved connection instead of creating one: the same
/// form, prefilled, keeping the id and credential ref so the vault entry and any
/// history stay attached.
Future<ServerFormResult?> showServerConnectionDialog(
  BuildContext context, {
  required Engine engine,
  Connection? existing,
}) {
  return showDialog<ServerFormResult>(
    context: context,
    builder: (_) => _ServerDialog(engine: engine, existing: existing),
  );
}

enum _Test { idle, testing, ok, error }

class _ServerDialog extends StatefulWidget {
  const _ServerDialog({required this.engine, this.existing});
  final Engine engine;

  /// Non-null when editing a saved connection.
  final Connection? existing;

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
      _existing?.options ?? const ConnectionOptions();
  late final _caCert =
      TextEditingController(text: _existing?.options.caCertPath ?? '');
  int _tab = 0;

  SslMode get _ssl => _options.sslMode;

  _Test _test = _Test.idle;
  String _testMsg = '';

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
      _setResult(_Test.error, '${e.kind.name}: ${e.message}');
    } catch (e) {
      _setResult(_Test.error, e.toString());
    }
  }

  void _setResult(_Test test, String msg) {
    if (!mounted) return;
    setState(() {
      _test = test;
      _testMsg = msg;
    });
  }

  void _save() {
    Navigator.pop(context, (
      connection: _connection(forSave: true),
      // Editing with the field untouched means "keep the stored secret". An
      // empty string is a real password, so null is the only way to say
      // "unchanged" without silently wiping the vault entry.
      password: _isEdit && _password.text.isEmpty ? null : _password.text,
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
          SizedBox(
            height: 268,
            child: SingleChildScrollView(child: _tabBody()),
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

  Widget _testRow() => Row(
    children: [
      Button(
        onPressed: _test == _Test.testing ? null : _runTest,
        child: const Text('⚡ Test connection'),
      ),
      const SizedBox(width: 10),
      Expanded(child: _status()),
    ],
  );

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
              style: TextStyle(color: Color(0xFF9BA1AD), fontSize: 12),
            ),
          ],
        );
      case _Test.ok:
        return Text(
          '✔ $_testMsg',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xFF6FE39A), fontSize: 12),
        );
      case _Test.error:
        // Connection errors are the ones you actually need to read and paste
        // into a search — so the full text is selectable, scrollable rather
        // than clipped, and one click copies it.
        return Row(
          children: [
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 64),
                child: SingleChildScrollView(
                  child: SelectableText(
                    '✕ $_testMsg',
                    style: const TextStyle(
                      color: Color(0xFFFF6B6B),
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
            Tooltip(
              message: 'Copy error',
              child: IconButton(
                icon: const Icon(
                  FluentIcons.copy,
                  size: 12,
                  color: Color(0xFF9BA1AD),
                ),
                onPressed: () =>
                    Clipboard.setData(ClipboardData(text: _testMsg)),
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
                        ? const Color(0x222FE6FF)
                        : (states.isHovered ? const Color(0x14FFFFFF) : null),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _tab == i
                          ? const Color(0xFF2FE6FF)
                          : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    _tabs[i],
                    style: TextStyle(
                      fontSize: 12,
                      color: _tab == i
                          ? const Color(0xFF2FE6FF)
                          : const Color(0xFF9BA1AD),
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
              style: TextStyle(color: Color(0xFF5A6069), fontSize: 10.5),
            ),
          ),
        ],
      );

  Widget _sshTab() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'SSH tunnelling is not implemented yet.\n\n'
          'It will live here: host, port, user, key file or password, and an '
          'optional jump host.',
          style: TextStyle(color: Color(0xFF9BA1AD), fontSize: 12),
        ),
      );

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
                const TextStyle(fontSize: 12, color: Color(0xFF9BA1AD)),
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
            style: TextStyle(color: Color(0xFF5A6069), fontSize: 10.5),
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
        labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF9BA1AD)),
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
                            ? const Color(0xFFE6E8EC)
                            : const Color(0xFF3A4049),
                        width: _options.colorTag == c ? 2 : 1,
                      ),
                    ),
                    child: c == null
                        ? const Icon(FluentIcons.clear,
                            size: 9, color: Color(0xFF5A6069))
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
        labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF9BA1AD)),
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
              style: const TextStyle(color: Color(0xFF5A6069), fontSize: 10.5),
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
