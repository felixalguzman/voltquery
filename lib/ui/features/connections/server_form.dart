import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../../data/drivers/driver_factory.dart';
import '../../../domain/drivers/driver_error.dart';
import '../../../domain/drivers/result.dart';
import '../../../domain/models/connection.dart';
import '../../../domain/models/engine.dart';

/// A secret-free [Connection] plus the password to hand to the vault.
typedef ServerFormResult = ({Connection connection, String password});

/// Connection form for a server engine (Postgres / MySQL) with an inline
/// **Test connection**. The #14 wizard's server branch.
Future<ServerFormResult?> showServerConnectionDialog(BuildContext context,
    {required Engine engine}) {
  return showDialog<ServerFormResult>(
    context: context,
    builder: (_) => _ServerDialog(engine: engine),
  );
}

enum _Test { idle, testing, ok, error }

class _ServerDialog extends StatefulWidget {
  const _ServerDialog({required this.engine});
  final Engine engine;

  @override
  State<_ServerDialog> createState() => _ServerDialogState();
}

class _ServerDialogState extends State<_ServerDialog> {
  late final _name = TextEditingController(text: _isPg ? 'Postgres' : 'MySQL');
  final _host = TextEditingController(text: 'localhost');
  late final _port = TextEditingController(text: '${_isPg ? 5432 : 3306}');
  late final _user =
      TextEditingController(text: _isPg ? 'postgres' : 'root');
  final _password = TextEditingController();
  late final _database =
      TextEditingController(text: _isPg ? 'postgres' : '');

  _Test _test = _Test.idle;
  String _testMsg = '';

  bool get _isPg => widget.engine == Engine.postgres;
  String get _dbLabel => _isPg ? 'PostgreSQL' : 'MySQL';

  @override
  void dispose() {
    for (final c in [_name, _host, _port, _user, _password, _database]) {
      c.dispose();
    }
    super.dispose();
  }

  Connection _connection({required bool forSave}) {
    final id = forSave ? const Uuid().v4() : 'test';
    return Connection(
      id: id,
      name: _name.text.trim().isEmpty ? _host.text.trim() : _name.text.trim(),
      engine: widget.engine,
      host: _host.text.trim(),
      port: int.tryParse(_port.text.trim()) ?? (_isPg ? 5432 : 3306),
      username: _user.text.trim(),
      credentialRef: forSave ? id : null,
      defaultDatabase:
          _database.text.trim().isEmpty ? null : _database.text.trim(),
    );
  }

  Future<void> _runTest() async {
    setState(() {
      _test = _Test.testing;
      _testMsg = '';
    });
    try {
      final session = await driverFor(widget.engine)
          .connect(_connection(forSave: false), secret: _password.text);
      var server = 'Connected';
      try {
        final result = await session.execute('SELECT version()');
        if (result is RowsResult) {
          final rows = await result.cursor.fetch(1);
          final v = rows.first.values.first?.toString();
          if (v != null && v.isNotEmpty) server = v.split(' ').take(2).join(' ');
          await result.cursor.close();
        }
      } catch (_) {/* version is best-effort */}
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
      password: _password.text,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 480),
      title: Text('New $_dbLabel connection'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
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
            Expanded(child: _field('Password', _password, obscure: true)),
          ]),
          _field('Database', _database),
          const SizedBox(height: 6),
          _testRow(),
        ],
      ),
      actions: [
        Button(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context)),
        FilledButton(onPressed: _save, child: const Text('Save & connect')),
      ],
    );
  }

  Widget _testRow() => Row(children: [
        Button(
          onPressed: _test == _Test.testing ? null : _runTest,
          child: const Text('⚡ Test connection'),
        ),
        const SizedBox(width: 10),
        Expanded(child: _status()),
      ]);

  Widget _status() {
    switch (_test) {
      case _Test.idle:
        return const SizedBox.shrink();
      case _Test.testing:
        return const Row(children: [
          SizedBox(width: 12, height: 12, child: ProgressRing(strokeWidth: 2)),
          SizedBox(width: 8),
          Text('Testing…',
              style: TextStyle(color: Color(0xFF9BA1AD), fontSize: 12)),
        ]);
      case _Test.ok:
        return Text('✔ $_testMsg',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF6FE39A), fontSize: 12));
      case _Test.error:
        // Connection errors are the ones you actually need to read and paste
        // into a search — so the full text is selectable, scrollable rather
        // than clipped, and one click copies it.
        return Row(children: [
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 64),
              child: SingleChildScrollView(
                child: SelectableText(
                  '✕ $_testMsg',
                  style: const TextStyle(
                      color: Color(0xFFFF6B6B), fontSize: 12),
                ),
              ),
            ),
          ),
          Tooltip(
            message: 'Copy error',
            child: IconButton(
              icon: const Icon(FluentIcons.copy,
                  size: 12, color: Color(0xFF9BA1AD)),
              onPressed: () =>
                  Clipboard.setData(ClipboardData(text: _testMsg)),
            ),
          ),
        ]);
    }
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
