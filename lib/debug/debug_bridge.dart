import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/sql/sql_statement_splitter.dart';
import '../ui/features/query_workspace/grid_edit_buffer.dart';
import '../ui/features/query_workspace/grid_editability.dart';
import '../ui/features/query_workspace/worksheet_providers.dart';
import '../ui/features/query_workspace/worksheet_state.dart';

/// A debug-only control surface over the VM service.
///
/// Driving the app through Flutter Driver means asserting on *pixels*: you tap
/// a button, screenshot, and read the answer off the picture. That works, but a
/// staged edit is data, not a picture — reading it back as JSON turns a guess
/// into an assertion. It also sidesteps widget selectors entirely, which in
/// this app cost real time (fluent's `Tooltip` is not material's, so neither
/// `find.byTooltip` nor the driver's `ByTooltipMessage` can see it).
///
/// The extensions it registers:
///
/// | method | what it answers |
/// |---|---|
/// | `ext.voltquery.snapshot` | connection, worksheets, and every grid's staged changes **plus the SQL they would generate** |
/// | `ext.voltquery.errors` | Flutter errors since launch — overflows especially, which never throw in release |
/// | `ext.voltquery.runSql` | run a statement in a worksheet and get the outcome back |
///
/// **Debug only.** This opens a control channel into the running isolate, so
/// [registerDebugExtensions] returns immediately unless [kDebugMode]. Nothing
/// in `lib/main.dart` references it either — only `test_driver/app.dart` does,
/// so a release build never links it in at all.
///
/// Call it from a driver entrypoint:
///
/// ```dart
/// void main() {
///   enableFlutterDriverExtension();
///   app.main(onContainerReady: registerDebugExtensions);
/// }
/// ```
void registerDebugExtensions(ProviderContainer container) {
  if (!kDebugMode) return;
  _DebugBridge(container).register();
}

/// One captured Flutter error, flattened to what is worth reading back.
///
/// Public for its own test: the parsing is the only part that can be wrong, and
/// registering a real service extension needs a live VM service.
@visibleForTesting
class CapturedError {
  CapturedError(FlutterErrorDetails details)
    : summary = details.exceptionAsString(),
      library = details.library ?? 'unknown',
      // The overflow message names the pixel count but not the widget; the
      // file:line lives in the information collector, which is where "which
      // Row?" actually comes from.
      location = _locationOf(details);

  final String summary;
  final String library;
  final String? location;

  Map<String, Object?> toJson() => {
    'summary': summary,
    'library': library,
    if (location != null) 'location': location,
  };

  /// First `foo.dart:12:34` mentioned by the error's own diagnostics.
  ///
  /// The raw collector yields a `debugCreator` node that is just a chain of
  /// widget *types*. Turning that into "the relevant error-causing widget was
  /// Row, built at worksheet_view.dart:274" is a transform the framework
  /// applies when it prints — so it has to be applied here too, or the one
  /// field worth having is always null.
  static String? _locationOf(FlutterErrorDetails details) {
    final collect = details.informationCollector;
    if (collect == null) return null;
    Iterable<DiagnosticsNode> nodes;
    try {
      nodes = debugTransformDebugCreator(collect().toList());
    } catch (_) {
      nodes = collect(); // never let diagnostics-of-diagnostics throw
    }
    for (final node in nodes) {
      final match = _dartLocation.firstMatch(node.toStringDeep());
      if (match != null) return match.group(0);
    }
    return null;
  }

  /// File name, not path: the diagnostics carry an absolute `file:///…` URI,
  /// and `worksheet_view.dart:274:14` is the part you actually navigate with.
  /// Excluding `/` from the name is what trims the URI off the front.
  static final _dartLocation = RegExp(r'[\w.-]+\.dart:\d+:\d+');
}

class _DebugBridge {
  _DebugBridge(this.container);

  final ProviderContainer container;

  /// Bounded: a layout error repeats every frame, and an unbounded list would
  /// be a memory leak in the one build where we can least afford surprises.
  static const _maxErrors = 200;
  final _errors = <CapturedError>[];

  void register() {
    _captureErrors();
    _register('snapshot', (_) async => _snapshot());
    _register('errors', (params) async {
      final out = [for (final e in _errors) e.toJson()];
      if (params['clear'] == 'true') _errors.clear();
      return {'count': out.length, 'errors': out};
    });
    _register('runSql', _runSql);
  }

  /// Chains rather than replaces: Flutter's own handler is what prints the
  /// error to the console, and losing that would make the app *quieter* under
  /// test than in normal use.
  void _captureErrors() {
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      if (_errors.length < _maxErrors) _errors.add(CapturedError(details));
      previous?.call(details);
    };
  }

  void _register(
    String name,
    Future<Map<String, Object?>> Function(Map<String, String>) handler,
  ) {
    developer.registerExtension('ext.voltquery.$name', (_, params) async {
      try {
        return developer.ServiceExtensionResponse.result(
          jsonEncode(await handler(params)),
        );
      } catch (e, s) {
        // A thrown extension reports as a transport failure, which reads like
        // the bridge is down rather than like the call was wrong.
        return developer.ServiceExtensionResponse.result(
          jsonEncode({'error': '$e', 'stack': '$s'}),
        );
      }
    });
  }

  /// Walks the app's own tab list rather than enumerating provider elements —
  /// `getAllProviderElements` is `@internal` in Riverpod, and building a debug
  /// tool on a package's private surface trades one blind spot for another.
  /// The tabs are the truth anyway: a grid that no tab owns isn't on screen.
  Map<String, Object?> _snapshot() {
    final conn = container.read(currentConnectionProvider);
    final tabs = container.read(worksheetTabsProvider);

    final grids = <Map<String, Object?>>[];
    for (final id in tabs.ids) {
      for (final (index, rows) in _resultsOf(id).indexed) {
        final gridId = gridIdFor(id, index, rows);
        grids.add(
          _grid(gridId, container.read(gridEditsProvider(gridId)), rows: rows),
        );
      }
    }

    return {
      'connection': {
        'id': conn.id,
        'name': conn.name,
        'engine': conn.engine.name,
      },
      'activeWorksheet': tabs.activeId,
      'worksheets': [for (final id in tabs.ids) _worksheet(id)],
      'grids': grids,
      'errorCount': _errors.length,
    };
  }

  Map<String, Object?> _worksheet(String id) {
    final state = container.read(worksheetProvider(id));
    return {
      'id': id,
      'state': switch (state) {
        WorksheetIdle() => 'idle',
        WorksheetRunning() => 'running',
        WorksheetScript() => 'script',
        WorksheetRows() => 'rows',
        WorksheetMessage() => 'message',
        WorksheetFailure() => 'failure',
      },
      'inTransaction': container.read(worksheetTxProvider(id)),
      if (state is WorksheetScript)
        'outcomes': [
          for (final o in state.outcomes)
            {
              'index': o.index,
              'sql': o.sql,
              'result': switch (o.result) {
                WorksheetRows(:final rows, :final durationMs, :final capped) =>
                  {
                    'kind': 'rows',
                    'rows': rows.length,
                    'durationMs': durationMs,
                    'capped': capped,
                    'editable': (o.result as WorksheetRows).editability != null,
                  },
                WorksheetMessage(:final text) => {
                  'kind': 'message',
                  'text': text,
                },
                WorksheetFailure(:final error) => {
                  'kind': 'failure',
                  'error': error.message,
                  'errorKind': error.kind.name,
                },
                _ => {'kind': 'other'},
              },
            },
        ],
    };
  }

  /// A grid's staged changes **and the statements they would run**.
  ///
  /// The SQL is the answer worth having: it is the thing the user is asked to
  /// approve, and generating it here through the same [GridEditBuffer.toSql]
  /// and [primaryKeyValues] the grid uses means this can't drift into
  /// describing statements the app would never send.
  Map<String, Object?> _grid(
    String gridId,
    GridEditBuffer buf, {
    required WorksheetRows rows,
  }) {
    final out = <String, Object?>{
      'gridId': gridId,
      'edits': [
        for (final e in buf.edits.values)
          {
            'row': e.rowIndex,
            'column': e.column,
            'from': '${e.oldValue}',
            'to': '${e.newValue}',
          },
      ],
      'deletes': buf.deletes.toList()..sort(),
      'inserts': [
        for (final r in buf.inserts)
          {'id': r.id, 'values': _stringify(r.values)},
      ],
    };

    final editability = rows.editability;
    if (editability == null) return out;

    out['statements'] = buf.toSql(
      editability: editability,
      dialect: SqlDialect.of(container.read(currentConnectionProvider).engine),
      pkValuesFor: (i) =>
          primaryKeyValues(editability, rows.fields, rows.rows, i),
    );
    return out;
  }

  /// A worksheet's row-returning results, in the order they became sub-tabs —
  /// which is what makes the index half of a [gridIdFor] meaningful.
  List<WorksheetRows> _resultsOf(String worksheetId) {
    final state = container.read(worksheetProvider(worksheetId));
    return switch (state) {
      WorksheetScript(:final outcomes) => [
        for (final o in outcomes)
          if (o.result case final WorksheetRows r) r,
      ],
      WorksheetRows() => [state],
      _ => const <WorksheetRows>[],
    };
  }

  Future<Map<String, Object?>> _runSql(Map<String, String> params) async {
    final sql = params['sql'];
    if (sql == null || sql.isEmpty) {
      return {'error': 'missing required parameter: sql'};
    }
    // Defaults to the worksheet the app opens with, so the common case is a
    // one-parameter call.
    final id = params['worksheetId'] ?? 'ws-0';
    await container.read(worksheetProvider(id).notifier).run(sql);
    return _worksheet(id);
  }

  static Map<String, String> _stringify(Map<String, Object?> values) => {
    for (final e in values.entries) e.key: '${e.value}',
  };
}
