// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'history_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app's drift store — one instance for the app's lifetime.

@ProviderFor(localStore)
final localStoreProvider = LocalStoreProvider._();

/// The app's drift store — one instance for the app's lifetime.

final class LocalStoreProvider
    extends $FunctionalProvider<LocalStore, LocalStore, LocalStore>
    with $Provider<LocalStore> {
  /// The app's drift store — one instance for the app's lifetime.
  LocalStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'localStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$localStoreHash();

  @$internal
  @override
  $ProviderElement<LocalStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LocalStore create(Ref ref) {
    return localStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LocalStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LocalStore>(value),
    );
  }
}

String _$localStoreHash() => r'cfc19ab85e864c81c0417c9bcd0e205c7aff266e';

@ProviderFor(historyRepository)
final historyRepositoryProvider = HistoryRepositoryProvider._();

final class HistoryRepositoryProvider
    extends
        $FunctionalProvider<
          HistoryRepository,
          HistoryRepository,
          HistoryRepository
        >
    with $Provider<HistoryRepository> {
  HistoryRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'historyRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$historyRepositoryHash();

  @$internal
  @override
  $ProviderElement<HistoryRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  HistoryRepository create(Ref ref) {
    return historyRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HistoryRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HistoryRepository>(value),
    );
  }
}

String _$historyRepositoryHash() => r'b261b9b7b51faa0e9d38ebba046d822e8c31769c';

/// Reactive recent query history for the sidebar (drift `.watch()`).

@ProviderFor(recentHistory)
final recentHistoryProvider = RecentHistoryProvider._();

/// Reactive recent query history for the sidebar (drift `.watch()`).

final class RecentHistoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<HistoryEntry>>,
          List<HistoryEntry>,
          Stream<List<HistoryEntry>>
        >
    with
        $FutureModifier<List<HistoryEntry>>,
        $StreamProvider<List<HistoryEntry>> {
  /// Reactive recent query history for the sidebar (drift `.watch()`).
  RecentHistoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recentHistoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recentHistoryHash();

  @$internal
  @override
  $StreamProviderElement<List<HistoryEntry>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<HistoryEntry>> create(Ref ref) {
    return recentHistory(ref);
  }
}

String _$recentHistoryHash() => r'5acf59e0c529afffa49ad0543affc0b4c5b9cb98';

/// Whether the panel hides statements the app composed (grid edits, Table
/// Info's exact `count(*)`) rather than ones the user typed.
///
/// Session-scoped, and **off** by default: showing everything that actually ran
/// against the database is the honest default, and a filter you have to turn on
/// can't quietly hide a destructive UPDATE from you.

@ProviderFor(HideGeneratedHistory)
final hideGeneratedHistoryProvider = HideGeneratedHistoryProvider._();

/// Whether the panel hides statements the app composed (grid edits, Table
/// Info's exact `count(*)`) rather than ones the user typed.
///
/// Session-scoped, and **off** by default: showing everything that actually ran
/// against the database is the honest default, and a filter you have to turn on
/// can't quietly hide a destructive UPDATE from you.
final class HideGeneratedHistoryProvider
    extends $NotifierProvider<HideGeneratedHistory, bool> {
  /// Whether the panel hides statements the app composed (grid edits, Table
  /// Info's exact `count(*)`) rather than ones the user typed.
  ///
  /// Session-scoped, and **off** by default: showing everything that actually ran
  /// against the database is the honest default, and a filter you have to turn on
  /// can't quietly hide a destructive UPDATE from you.
  HideGeneratedHistoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'hideGeneratedHistoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$hideGeneratedHistoryHash();

  @$internal
  @override
  HideGeneratedHistory create() => HideGeneratedHistory();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$hideGeneratedHistoryHash() =>
    r'586444e6f4ab8dedddf8cdf72dc756b25709cb70';

/// Whether the panel hides statements the app composed (grid edits, Table
/// Info's exact `count(*)`) rather than ones the user typed.
///
/// Session-scoped, and **off** by default: showing everything that actually ran
/// against the database is the honest default, and a filter you have to turn on
/// can't quietly hide a destructive UPDATE from you.

abstract class _$HideGeneratedHistory extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The history panel's filter box: whether it's showing, and its text. Matches
/// against the SQL.

@ProviderFor(HistoryFilter)
final historyFilterProvider = HistoryFilterProvider._();

/// The history panel's filter box: whether it's showing, and its text. Matches
/// against the SQL.
final class HistoryFilterProvider
    extends $NotifierProvider<HistoryFilter, FilterState> {
  /// The history panel's filter box: whether it's showing, and its text. Matches
  /// against the SQL.
  HistoryFilterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'historyFilterProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$historyFilterHash();

  @$internal
  @override
  HistoryFilter create() => HistoryFilter();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FilterState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FilterState>(value),
    );
  }
}

String _$historyFilterHash() => r'f8e6549220c50f5eb66e5d785df430e89fe290b0';

/// The history panel's filter box: whether it's showing, and its text. Matches
/// against the SQL.

abstract class _$HistoryFilter extends $Notifier<FilterState> {
  FilterState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<FilterState, FilterState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<FilterState, FilterState>,
              FilterState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
