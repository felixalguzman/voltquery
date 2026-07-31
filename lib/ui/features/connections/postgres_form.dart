import 'package:fluent_ui/fluent_ui.dart';
import 'package:uuid/uuid.dart';

import '../../../data/drivers/driver_factory.dart';
import '../../../domain/drivers/driver_error.dart';
import '../../../domain/drivers/result.dart';
import '../../../domain/models/connection.dart';
import '../../../domain/models/engine.dart';

/// Result of the Postgres form — a secret-free [Connection] plus the password to
/// hand to the vault.
typedef PostgresFormResult = ({Connection connection, String password});

Future<PostgresFormResult?> showPostgresConnectionDialog(BuildContext context) {
  return showDialog<PostgresFormResult>(
    context: context,
    builder: (_) => const _PostgresDialog(),
  );
}

enum _Test { idle, testing, ok, error }

/// Minimal connection form (the #14 wizard's Postgres branch) with an inline
/// **Test connection** that connects + reports the server version or the
/// normalized error, without saving.
class _PostgresDialog extends StatefulWidget {
  const _PostgresDialog();

  @override
  State<_PostgresDialog> createState() => _PostgresDialogState();
}

class _PostgresDialogState extends State<_PostgresDialog> {
  final _name = TextEditingController(text: 'Postgres');
  final _host = TextEditingController(text: 'localhost');
  final _port = TextEditingController(text: '5432');
  final _user = TextEditingController(text: 'postgres');
  final _password = TextEditingController();
  final _database = TextEditingController(text: 'postgres');

  _Test _test = _Test.idle;
  String _testMsg = '';

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
      engine: Engine.postgres,
      host: _host.text.trim(),
      port: int.tryParse(_port.text.trim()) ?? 5432,
      username: _user.text.trim(),
      credentialRef: forSave ? id : null,
      defaultDatabase: _database.text.trim(),
    );
  }

  Future<void> _runTest() async {
    setState(() {
      _test = _Test.testing;
      _testMsg = '';
    });
    try {
      final session = await driverFor(Engine.postgres)
          .connect(_connection(forSave: false), secret: _password.text);
      String server = 'Connected';
      try {
        final result = await session.execute('SELECT version()');
        if (result is RowsResult) {
          final rows = await result.cursor.fetch(1);
          final v = rows.first.values.first as String?;
          if (v != null) server = v.split(' ').take(2).join(' '); // "PostgreSQL 17.0"
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
      title: const Text('New PostgreSQL connection'),
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

  Widget _testRow() {
    return Row(children: [
      Button(
        onPressed: _test == _Test.testing ? null : _runTest,
        child: const Text('⚡ Test connection'),
      ),
      const SizedBox(width: 10),
      Expanded(child: _status()),
    ]);
  }

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
        return Text('✕ $_testMsg',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 12));
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
