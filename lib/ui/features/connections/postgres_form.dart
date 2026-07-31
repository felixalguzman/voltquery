import 'package:fluent_ui/fluent_ui.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/models/connection.dart';
import '../../../domain/models/engine.dart';

/// Result of the Postgres form — a secret-free [Connection] plus the password to
/// hand to the (in-memory) secret store.
typedef PostgresFormResult = ({Connection connection, String password});

Future<PostgresFormResult?> showPostgresConnectionDialog(BuildContext context) {
  return showDialog<PostgresFormResult>(
    context: context,
    builder: (_) => const _PostgresDialog(),
  );
}

/// Minimal connection form (the #14 wizard's Postgres branch). The full
/// two-pane wizard + real credential vault land later; this holds the password
/// in memory only.
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

  @override
  void dispose() {
    for (final c in [_name, _host, _port, _user, _password, _database]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final id = const Uuid().v4();
    final connection = Connection(
      id: id,
      name: _name.text.trim().isEmpty ? _host.text.trim() : _name.text.trim(),
      engine: Engine.postgres,
      host: _host.text.trim(),
      port: int.tryParse(_port.text.trim()) ?? 5432,
      username: _user.text.trim(),
      credentialRef: id, // secret keyed by connection id (vault placeholder)
      defaultDatabase: _database.text.trim(),
    );
    Navigator.pop(context, (connection: connection, password: _password.text));
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 460),
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
