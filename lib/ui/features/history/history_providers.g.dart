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
