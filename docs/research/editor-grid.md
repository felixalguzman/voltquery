# Research: re_editor SQL highlighting + pluto_grid large result sets

Resolves #6

---

## 1. re_editor + re_highlight

### Package versions

| Package | Version | Publisher |
|---|---|---|
| re_editor | 0.10.0 | reqable.com (verified) |
| re_highlight | 0.0.3 | reqable.com |

Sources: [pub.dev/packages/re_editor](https://pub.dev/packages/re_editor), [pub.dev/packages/re_highlight](https://pub.dev/packages/re_highlight)

---

### 1.1 Does re_highlight ship SQL out of the box?

Yes. re_highlight is a Dart port of highlight.js v11.9.0 and ships language definitions for all ~100 languages that highlight.js bundles. The `lib/languages/` directory in the GitHub repo confirms both:

- `lib/languages/sql.dart` — generic SQL (SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER, DROP, MERGE, window functions, CTEs, JSON operators, CASE, aggregate/analytic functions, and standard comment styles `--` and `/* */`)
- `lib/languages/pgsql.dart` — PostgreSQL-specific dialect

Source: [github.com/reqable/re-highlight — lib/languages/](https://github.com/reqable/re-highlight/tree/main/lib/languages)

The `lib/languages/all.dart` barrel file imports every bundled language, making `builtinAllLanguages` available as a single constant.

---

### 1.2 Language registration API

Languages are registered by calling `registerLanguages()` on a `Highlight` instance, passing a `Map<String, Mode>`. When using re_highlight standalone (outside re_editor):

```dart
final Highlight highlight = Highlight();
highlight.registerLanguages(builtinAllLanguages); // registers all ~100 built-ins
```

To register only SQL:

```dart
import 'package:re_highlight/languages/sql.dart';

highlight.registerLanguages({'sql': langSql});
```

The map key is the language identifier string used later when invoking highlighting. When wiring into re_editor (see section 1.4), language registration happens through `CodeHighlightTheme` instead of directly on a `Highlight` instance.

Source: [github.com/reqable/re-highlight README](https://raw.githubusercontent.com/reqable/re-highlight/main/README.md)

---

### 1.3 Theme application

Themes are `Map<String, TextStyle>` constants defined in `lib/styles/`. There are roughly 75 built-in top-level themes plus an additional set under `lib/styles/base16/`. Notable themes include:

- `atomOneDarkTheme`, `atomOneLightTheme`
- `githubTheme`, `githubDarkTheme`
- `nordTheme`
- `monokaiTheme`, `monokaiSublimeTheme`
- `vsTheme`, `vs2015Theme`
- `tokyoNightDarkTheme`, `tokyoNightLightTheme`
- `nightOwlTheme`
- `stackoverflowDarkTheme`, `stackoverflowLightTheme`

When used standalone (outside re_editor), themes are applied through a `TextSpanRenderer`, which converts a `HighlightResult` into Flutter `TextSpan` objects:

```dart
import 'package:re_highlight/styles/atom-one-dark.dart';

final TextSpanRenderer renderer = TextSpanRenderer(defaultTextStyle, atomOneDarkTheme);
result.render(renderer);
final TextSpan? span = renderer.span;
```

When used through re_editor, the theme map is passed directly to `CodeHighlightTheme` (see section 1.4).

Source: [github.com/reqable/re-highlight — lib/styles/](https://github.com/reqable/re-highlight/tree/main/lib/styles)

---

### 1.4 Wiring re_editor to re_highlight

re_editor consumes re_highlight through the `CodeHighlightTheme` class, passed as the `codeTheme` property of `CodeEditorStyle`. No separate `Highlight` instance management is needed — `CodeHighlightTheme` takes a `languages` map and a `theme` map directly:

```dart
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/sql.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';

CodeEditor(
  style: CodeEditorStyle(
    codeTheme: CodeHighlightTheme(
      languages: {
        'sql': CodeHighlightThemeMode(mode: langSql),
      },
      theme: atomOneDarkTheme,
    ),
  ),
  controller: CodeLineEditingController(),
);
```

Key classes and their roles:

| Class | Role |
|---|---|
| `CodeEditor` | Main editor widget |
| `CodeEditorStyle` | Style container passed to `CodeEditor.style` |
| `CodeHighlightTheme` | Holds the language map and theme map; bridges re_editor to re_highlight |
| `CodeHighlightThemeMode` | Wraps a single `Mode` (language definition from re_highlight) |
| `CodeLineEditingController` | Manages editor content |
| `CodeScrollController` | Handles independent horizontal + vertical scrolling |

Source: [github.com/reqable/re-editor README](https://raw.githubusercontent.com/reqable/re-editor/main/README.md), [pub.dev/packages/re_editor](https://pub.dev/packages/re_editor)

---

## 2. pluto_grid

### Package version

| Package | Version | Min Flutter |
|---|---|---|
| pluto_grid | 8.1.0 | 3.38.0 |

Source: [pub.dev/packages/pluto_grid](https://pub.dev/packages/pluto_grid)

---

### 2.1 Row virtualization

pluto_grid renders rows with `ListView.builder`, which means only visible rows are built as widgets. The `itemExtent` is set to `stateManager.rowTotalHeight` (a fixed uniform row height), enabling O(1) calculation of which rows are in the viewport without constructing off-screen rows:

```dart
ListView.builder(
  controller: _verticalScroll,
  itemCount: _rows.length,
  itemExtent: stateManager.rowTotalHeight,
  addRepaintBoundaries: false,
  itemBuilder: (ctx, i) { /* builds PlutoBaseRow */ },
)
```

The grid can hold a large `_rows` list in memory while only rendering the visible slice. The virtualization is native Flutter `ListView.builder` — there is no additional custom virtualization layer. Row height is uniform and fixed; variable-height rows are not supported.

Source: [github.com/bosskmk/pluto_grid — lib/src/ui/pluto_body_rows.dart](https://github.com/bosskmk/pluto_grid/blob/master/lib/src/ui/pluto_body_rows.dart)

---

### 2.2 Lazy / server-side pagination

Two distinct plugins handle server-driven data:

**`PlutoLazyPagination`** — page-at-a-time server fetch. A footer widget that replaces rows on each page turn by calling an async `fetch` callback:

```dart
typedef PlutoLazyPaginationFetch =
    Future<PlutoLazyPaginationResponse> Function(PlutoLazyPaginationRequest);

class PlutoLazyPaginationRequest {
  final int page;
  final PlutoColumn? sortColumn;   // current sort column (if any)
  final List<PlutoRow> filterRows; // current filter state
}

class PlutoLazyPaginationResponse {
  final int totalPage; // for rendering pagination buttons
  final List<PlutoRow> rows;
}

// Usage
createFooter: (stateManager) => PlutoLazyPagination(
  initialPage: 1,
  fetchWithSorting: true,    // pass sort state to fetch callback
  fetchWithFiltering: true,  // pass filter state to fetch callback
  fetch: myFetchCallback,
  stateManager: stateManager,
),
```

**`PlutoInfinityScrollRows`** — cursor-based infinite scroll. Appends rows as the user scrolls to the bottom (or uses arrow keys / PageDown past the last row):

```dart
typedef PlutoInfinityScrollRowsFetch =
    Future<PlutoInfinityScrollRowsResponse> Function(PlutoInfinityScrollRowsRequest);

class PlutoInfinityScrollRowsRequest {
  final PlutoRow? lastRow;         // null = load from beginning; else cursor row
  final PlutoColumn? sortColumn;
  final List<PlutoRow> filterRows;
}

class PlutoInfinityScrollRowsResponse {
  final bool isLast; // signal that all data has been returned
  final List<PlutoRow> rows;
}

// Usage
createFooter: (s) => PlutoInfinityScrollRows(
  fetch: myScrollFetch,
  stateManager: s,
),
```

Both plugins live under `lib/src/plugin/` and are exported from the main package barrel (`lib/pluto_grid.dart`).

Sources:
- [github.com/bosskmk/pluto_grid — lib/src/plugin/pluto_lazy_pagination.dart](https://github.com/bosskmk/pluto_grid/blob/master/lib/src/plugin/pluto_lazy_pagination.dart)
- [github.com/bosskmk/pluto_grid — lib/src/plugin/pluto_infinity_scroll_rows.dart](https://github.com/bosskmk/pluto_grid/blob/master/lib/src/plugin/pluto_infinity_scroll_rows.dart)
- [github.com/bosskmk/pluto_grid — lib/pluto_grid.dart](https://github.com/bosskmk/pluto_grid/blob/master/lib/pluto_grid.dart)

---

### 2.3 Dynamic columns at runtime

Columns can be inserted and removed at runtime via `PlutoGridStateManager`:

```dart
// Insert columns at a given index position
stateManager.insertColumns(int columnIdx, List<PlutoColumn> columns);

// Remove columns
stateManager.removeColumns(List<PlutoColumn> columns);

// Show/hide a column without removing it
stateManager.hideColumn(column, hide);
stateManager.hideColumns(columns, hide);
```

`insertColumns` internally calls `_fillCellsInRows()` to populate cells in all existing rows for each new column, maintaining row/column parity. This means a grid can be constructed from a fully dynamic, query-driven column schema even after initial render.

Source: [github.com/bosskmk/pluto_grid — lib/src/manager/state/column_state.dart](https://github.com/bosskmk/pluto_grid/blob/master/lib/src/manager/state/column_state.dart)

---

### 2.4 Incremental row appending

`PlutoGridStateManager` exposes direct row mutation methods:

```dart
// Append rows to the bottom
stateManager.appendRows(List<PlutoRow> rows);

// Prepend rows at the top
stateManager.prependRows(List<PlutoRow> rows);

// Insert rows at a specific index
stateManager.insertRows(int rowIdx, List<PlutoRow> rows);
```

All three methods call the internal `_insertRows()` and then call `notifyListeners`, triggering a grid re-render. These are the same methods used internally by `PlutoInfinityScrollRows`, so they are stable public API suitable for streaming result appends.

Source: [github.com/bosskmk/pluto_grid — lib/src/manager/state/row_state.dart](https://github.com/bosskmk/pluto_grid/blob/master/lib/src/manager/state/row_state.dart)

---

### 2.5 Hard limits and design constraints

No explicit documented row or column count limits exist in the source or README. Practical constraints for a SQL result grid:

| Constraint | Detail |
|---|---|
| Row height | Fixed and uniform (`stateManager.rowTotalHeight`). Variable-height rows are not natively supported. |
| In-memory rows | All loaded rows must fit in Dart heap. Use `PlutoLazyPagination` or `PlutoInfinityScrollRows` to avoid loading the full result set at once. |
| Sorting / filtering | Both server-driven plugins expose `fetchWithSorting` and `fetchWithFiltering` flags so the server (database) can own these operations rather than the grid. |
| Column types | Built-in types: text, number, select, date, time. For arbitrary SQL result columns, `text` is the safe universal default; `number` can be applied to numeric columns. |
| Flutter version | pluto_grid 8.1.0 requires Flutter 3.38.0+. |

Source: [pub.dev/packages/pluto_grid](https://pub.dev/packages/pluto_grid), [github.com/bosskmk/pluto_grid README](https://raw.githubusercontent.com/bosskmk/pluto_grid/master/README.md)
