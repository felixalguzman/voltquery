import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../domain/models/history_entry.dart';
import '../../../domain/models/schema.dart';
import '../history/history_providers.dart';
import '../schema_browser/schema_providers.dart';

part 'search_providers.g.dart';

/// Everything one search turned up, per source.
class SearchResults {
  const SearchResults({
    this.schema = const [],
    this.history = const [],
    this.schemaError,
  });

  final List<SchemaSearchHit> schema;
  final List<HistoryEntry> history;

  /// Non-null when the catalog query failed. Surfaced rather than swallowed:
  /// "no tables matched" and "the server refused the query" look identical in
  /// an empty list, and only one of them means the table isn't there.
  final Object? schemaError;

  bool get isEmpty => schema.isEmpty && history.isEmpty;
  int get total => schema.length + history.length;
}

/// The text last selected in a worksheet editor, if it looks like a name.
///
/// Seeds the search dialog: opening a search with the thing you just
/// highlighted already typed in is the difference between a search box and a
/// search. Only short single-line selections qualify — highlighting a whole
/// query then hitting search means you want to search, not to look up that
/// entire statement as an identifier.
@Riverpod(keepAlive: true)
class EditorSelection extends _$EditorSelection {
  @override
  String build() => '';

  static const _maxLength = 64;

  void set(String raw) {
    final text = raw.trim();
    final usable =
        text.isNotEmpty && text.length <= _maxLength && !text.contains('\n');
    final next = usable ? text : '';
    if (next != state) state = next;
  }
}

/// Which kinds of result the dialog is asking for.
///
/// Not merely a filter on the way out: [SchemaIntrospector.search] shares one
/// row limit between objects and columns, and objects are collected first — so
/// a pattern matching many table names can spend the entire budget before a
/// single column is considered. Narrowing to columns is what makes yours
/// findable. Skipping a source skips its query outright.
enum SearchFilter {
  all('All'),
  tables('Tables & views'),
  columns('Columns'),
  history('History');

  const SearchFilter(this.label);
  final String label;

  bool get includesSchema => this != SearchFilter.history;
  bool get includesHistory =>
      this == SearchFilter.all || this == SearchFilter.history;

  SearchScope get scope => switch (this) {
    SearchFilter.tables => SearchScope.objects,
    SearchFilter.columns => SearchScope.columns,
    _ => SearchScope.all,
  };
}

/// Shortest query that will actually run.
///
/// A single character matches most of a real schema. Measured on SQLite the
/// cost tracks the row *limit* rather than the schema size (10k columns, limit
/// 200: ~5ms), but a server's `information_schema` is a network round-trip over
/// a much less predictable planner — MySQL before 8.0 builds those rows on
/// demand. Two characters costs nothing to require and removes the worst case.
const kMinSearchLength = 2;

/// Runs one search across every source.
///
/// Sources are queried **concurrently** and a failure in one doesn't take the
/// others down — a Postgres connection that rejects the catalog query should
/// still let you find the statement in your history.
@riverpod
Future<SearchResults> searchResults(
  Ref ref,
  String query,
  SearchFilter filter,
) async {
  if (query.trim().length < kMinSearchLength) return const SearchResults();

  final repo = await ref.watch(schemaRepositoryProvider.future);
  final history = ref.watch(historyRepositoryProvider);

  final results = await Future.wait([
    if (filter.includesSchema)
      repo
          .search(query, scope: filter.scope)
          .then<Object>((v) => v)
          .catchError((Object e) => e)
    else
      Future<Object>.value(const <SchemaSearchHit>[]),
    if (filter.includesHistory)
      history.search(query)
    else
      Future.value(const <HistoryEntry>[]),
  ]);

  final schemaResult = results[0];
  return SearchResults(
    schema: schemaResult is List<SchemaSearchHit> ? schemaResult : const [],
    schemaError: schemaResult is List<SchemaSearchHit> ? null : schemaResult,
    history: results[1] as List<HistoryEntry>,
  );
}
