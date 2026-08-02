// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The text last selected in a worksheet editor, if it looks like a name.
///
/// Seeds the search dialog: opening a search with the thing you just
/// highlighted already typed in is the difference between a search box and a
/// search. Only short single-line selections qualify — highlighting a whole
/// query then hitting search means you want to search, not to look up that
/// entire statement as an identifier.

@ProviderFor(EditorSelection)
final editorSelectionProvider = EditorSelectionProvider._();

/// The text last selected in a worksheet editor, if it looks like a name.
///
/// Seeds the search dialog: opening a search with the thing you just
/// highlighted already typed in is the difference between a search box and a
/// search. Only short single-line selections qualify — highlighting a whole
/// query then hitting search means you want to search, not to look up that
/// entire statement as an identifier.
final class EditorSelectionProvider
    extends $NotifierProvider<EditorSelection, String> {
  /// The text last selected in a worksheet editor, if it looks like a name.
  ///
  /// Seeds the search dialog: opening a search with the thing you just
  /// highlighted already typed in is the difference between a search box and a
  /// search. Only short single-line selections qualify — highlighting a whole
  /// query then hitting search means you want to search, not to look up that
  /// entire statement as an identifier.
  EditorSelectionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'editorSelectionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$editorSelectionHash();

  @$internal
  @override
  EditorSelection create() => EditorSelection();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$editorSelectionHash() => r'7d5bf0c33111c143970625b382a02f8e7a6df1b8';

/// The text last selected in a worksheet editor, if it looks like a name.
///
/// Seeds the search dialog: opening a search with the thing you just
/// highlighted already typed in is the difference between a search box and a
/// search. Only short single-line selections qualify — highlighting a whole
/// query then hitting search means you want to search, not to look up that
/// entire statement as an identifier.

abstract class _$EditorSelection extends $Notifier<String> {
  String build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String, String>,
              String,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Runs one search across every source.
///
/// Sources are queried **concurrently** and a failure in one doesn't take the
/// others down — a Postgres connection that rejects the catalog query should
/// still let you find the statement in your history.

@ProviderFor(searchResults)
final searchResultsProvider = SearchResultsFamily._();

/// Runs one search across every source.
///
/// Sources are queried **concurrently** and a failure in one doesn't take the
/// others down — a Postgres connection that rejects the catalog query should
/// still let you find the statement in your history.

final class SearchResultsProvider
    extends
        $FunctionalProvider<
          AsyncValue<SearchResults>,
          SearchResults,
          FutureOr<SearchResults>
        >
    with $FutureModifier<SearchResults>, $FutureProvider<SearchResults> {
  /// Runs one search across every source.
  ///
  /// Sources are queried **concurrently** and a failure in one doesn't take the
  /// others down — a Postgres connection that rejects the catalog query should
  /// still let you find the statement in your history.
  SearchResultsProvider._({
    required SearchResultsFamily super.from,
    required (String, SearchFilter) super.argument,
  }) : super(
         retry: null,
         name: r'searchResultsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$searchResultsHash();

  @override
  String toString() {
    return r'searchResultsProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<SearchResults> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SearchResults> create(Ref ref) {
    final argument = this.argument as (String, SearchFilter);
    return searchResults(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is SearchResultsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$searchResultsHash() => r'c60ba13cc0b8b2bc4712e5ffdc7c26da0cba6c0f';

/// Runs one search across every source.
///
/// Sources are queried **concurrently** and a failure in one doesn't take the
/// others down — a Postgres connection that rejects the catalog query should
/// still let you find the statement in your history.

final class SearchResultsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<SearchResults>,
          (String, SearchFilter)
        > {
  SearchResultsFamily._()
    : super(
        retry: null,
        name: r'searchResultsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Runs one search across every source.
  ///
  /// Sources are queried **concurrently** and a failure in one doesn't take the
  /// others down — a Postgres connection that rejects the catalog query should
  /// still let you find the statement in your history.

  SearchResultsProvider call(String query, SearchFilter filter) =>
      SearchResultsProvider._(argument: (query, filter), from: this);

  @override
  String toString() => r'searchResultsProvider';
}
