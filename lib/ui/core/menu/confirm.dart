import 'package:fluent_ui/fluent_ui.dart';

// TODO(theming #7): unify tokens into ui/core/theme.
const _textMid = Color(0xFF9BA1AD);

/// Asks before doing something irreversible.
///
/// The app has no undo, so anything that destroys data or state gets one of
/// these — the same principle as the grid's Review & Apply panel: nothing
/// unrecoverable happens on a single click.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => ContentDialog(
      constraints: const BoxConstraints(maxWidth: 420),
      title: Text(title, style: const TextStyle(fontSize: 16)),
      content: Text(
        message,
        style: const TextStyle(color: _textMid, fontSize: 12.5),
      ),
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
