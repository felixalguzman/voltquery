import 'package:fluent_ui/fluent_ui.dart';

import '../../core/theme/volt_tokens.dart';

import '../../../domain/export/result_export.dart';


/// Which rows leave the app.
enum ExportScope {
  /// What the grid holds — the render-capped slice, already in memory.
  visible,

  /// Every row the query returns, by running it again and streaming the answer.
  all,
}

/// Where they go.
enum ExportSink { clipboard, file }

/// Everything the caller needs to perform the export.
class ExportRequest {
  ExportRequest({
    required this.format,
    required this.options,
    required this.scope,
    required this.sink,
  });

  final ExportFormat format;
  final ExportOptions options;
  final ExportScope scope;
  final ExportSink sink;
}

/// Picks a format, a scope and a destination.
///
/// The scope choice is the reason this is a dialog rather than a submenu. The
/// grid holds a **capped** slice of the result, so "export" without a choice
/// would hand someone a fraction of their table and not mention it — the kind
/// of quiet wrong answer that gets found a week later in a spreadsheet.
class ExportDialog extends StatefulWidget {
  const ExportDialog({
    super.key,
    required this.visibleRows,
    required this.capped,
    required this.canExportAll,
    required this.defaultOptions,
  });

  /// How many rows the grid is holding right now.
  final int visibleRows;

  /// Whether more rows exist than were materialized.
  final bool capped;

  /// False when the source statement isn't known, so re-running is impossible
  /// and [ExportScope.all] can't be offered honestly.
  final bool canExportAll;

  final ExportOptions defaultOptions;

  @override
  State<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<ExportDialog> {
  VoltTokens get t => VoltTheme.of(context);
  late ExportFormat _format = ExportFormat.csv;
  late ExportOptions _options = widget.defaultOptions;
  // Default to the whole result when the visible slice is known to be partial:
  // the safe default is the one that doesn't silently drop rows.
  late ExportScope _scope = widget.capped && widget.canExportAll
      ? ExportScope.all
      : ExportScope.visible;
  ExportSink _sink = ExportSink.clipboard;
  late final _nullController =
      TextEditingController(text: widget.defaultOptions.nullText);

  @override
  void dispose() {
    _nullController.dispose();
    super.dispose();
  }

  /// Streaming to the clipboard makes no sense for a whole large result, and
  /// Markdown can't stream at all — both stay allowed, but the warning says so.
  bool get _isLargeClipboard =>
      _sink == ExportSink.clipboard && _scope == ExportScope.all;

  @override
  Widget build(BuildContext context) {
    final t = VoltTheme.of(context);
    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 480),
      title: const Text('Export results', style: TextStyle(fontSize: 16)),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _label('Format'),
          ComboBox<ExportFormat>(
            value: _format,
            isExpanded: true,
            items: [
              for (final f in ExportFormat.values)
                ComboBoxItem(value: f, child: Text(f.label)),
            ],
            onChanged: (v) => setState(() => _format = v ?? _format),
          ),
          const SizedBox(height: 14),
          _label('Rows'),
          _radio(
            'Visible rows (${widget.visibleRows})'
            '${widget.capped ? ' — capped' : ''}',
            selected: _scope == ExportScope.visible,
            onTap: () => setState(() => _scope = ExportScope.visible),
          ),
          if (widget.canExportAll)
            _radio(
              'All rows — re-runs the query',
              selected: _scope == ExportScope.all,
              onTap: () => setState(() => _scope = ExportScope.all),
            ),
          if (widget.capped && _scope == ExportScope.visible)
            _warning(
              'More rows matched than were loaded. This exports the first '
              '${widget.visibleRows} only.',
            ),
          if (!widget.canExportAll && widget.capped)
            _warning(
              'The source statement is unknown, so only the loaded rows can '
              'be exported.',
            ),
          const SizedBox(height: 14),
          _label('Destination'),
          _radio(
            'Copy to clipboard',
            selected: _sink == ExportSink.clipboard,
            onTap: () => setState(() => _sink = ExportSink.clipboard),
          ),
          _radio(
            'Save to file…',
            selected: _sink == ExportSink.file,
            onTap: () => setState(() => _sink = ExportSink.file),
          ),
          if (_isLargeClipboard)
            _warning('A whole result on the clipboard can be very large.'),
          const SizedBox(height: 14),
          Checkbox(
            checked: _options.includeHeader,
            onChanged: (v) => setState(
              () => _options = _options.copyWith(includeHeader: v ?? true),
            ),
            content: Text('Include column names',
                style: TextStyle(color: t.textHigh, fontSize: 12.5)),
          ),
          // JSON and INSERT both have a real null, so the substitution would be
          // a lie there; only the text formats need it.
          if (_format != ExportFormat.json &&
              _format != ExportFormat.sqlInsert) ...[
            const SizedBox(height: 10),
            _label('Show NULL as'),
            TextBox(
              controller: _nullController,
              placeholder: 'empty',
              style: TextStyle(color: t.textHigh, fontSize: 12.5),
              onChanged: (v) =>
                  _options = _options.copyWith(nullText: v),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'CSV has no null, so this is also what an empty string looks '
                'like.',
                style: TextStyle(color: t.textLow, fontSize: 11),
              ),
            ),
          ],
        ],
      ),
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(ExportRequest(
            format: _format,
            options: _options,
            scope: _scope,
            sink: _sink,
          )),
          child: Text(
            _sink == ExportSink.clipboard ? 'Copy' : 'Save…',
          ),
        ),
      ],
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            color: t.textLow,
            fontSize: 10,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  /// Hand-rolled rather than fluent's `RadioButton`: that one moved to
  /// Flutter's group-registry API and wants a `RadioGroup` ancestor per set,
  /// which is a lot of ceremony for three choices in a dialog.
  Widget _radio(
    String label, {
    required bool selected,
    required VoidCallback onTap,
  }) =>
      HoverButton(
        onPressed: onTap,
        builder: (context, states) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: states.isHovered ? t.hoverSoft : null,
            borderRadius: BorderRadius.circular(3),
          ),
          child: Row(children: [
            Icon(
              selected ? FluentIcons.radio_btn_on : FluentIcons.radio_btn_off,
              size: 14,
              color: selected ? t.accent : t.textLow,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? t.textHigh : t.textMid,
                  fontSize: 12.5,
                ),
              ),
            ),
          ]),
        ),
      );

  Widget _warning(String text) => Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: t.canvas,
          border: Border.all(color: t.hairline),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(FluentIcons.warning, size: 11, color: t.warning),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                style: TextStyle(color: t.textMid, fontSize: 11.5),
              ),
            ),
          ],
        ),
      );
}
