import 'package:fluent_ui/fluent_ui.dart';

/// Prompts for the vault master password (ADR-0006). [isNew] = first-run create
/// (with confirm + "not recoverable" warning); otherwise unlock. Returns the
/// password, or null if cancelled.
Future<String?> showMasterPasswordDialog(BuildContext context,
    {required bool isNew}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _MasterPasswordDialog(isNew: isNew),
  );
}

class _MasterPasswordDialog extends StatefulWidget {
  const _MasterPasswordDialog({required this.isNew});
  final bool isNew;

  @override
  State<_MasterPasswordDialog> createState() => _MasterPasswordDialogState();
}

class _MasterPasswordDialogState extends State<_MasterPasswordDialog> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    final pw = _password.text;
    if (pw.isEmpty) {
      setState(() => _error = 'Enter a password');
      return;
    }
    if (widget.isNew && pw != _confirm.text) {
      setState(() => _error = 'Passwords do not match');
      return;
    }
    Navigator.pop(context, pw);
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 420),
      title: Text(widget.isNew ? 'Create master password' : 'Unlock vault'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InfoLabel(
            label: 'Master password',
            child: TextBox(
              controller: _password,
              obscureText: true,
              autofocus: true,
              onSubmitted: (_) => _submit(),
            ),
          ),
          if (widget.isNew) ...[
            const SizedBox(height: 10),
            InfoLabel(
              label: 'Confirm',
              child: TextBox(controller: _confirm, obscureText: true),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            widget.isNew
                ? '⚠ Not recoverable — VoltQuery cannot reset it. Encrypts your saved connection secrets.'
                : 'Unlocks your saved secrets for this session.',
            style: const TextStyle(color: Color(0xFF9BA1AD), fontSize: 11.5),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 12)),
          ],
        ],
      ),
      actions: [
        Button(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context)),
        FilledButton(
            onPressed: _submit,
            child: Text(widget.isNew ? 'Create' : 'Unlock')),
      ],
    );
  }
}
