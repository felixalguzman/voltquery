// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'history_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$localStoreHash() => r'cfc19ab85e864c81c0417c9bcd0e205c7aff266e';

/// The app's drift store — one instance for the app's lifetime.
///
/// Copied from [localStore].
@ProviderFor(localStore)
final localStoreProvider = Provider<LocalStore>.internal(
  localStore,
  name: r'localStoreProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$localStoreHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LocalStoreRef = ProviderRef<LocalStore>;
String _$historyRepositoryHash() => r'b261b9b7b51faa0e9d38ebba046d822e8c31769c';

/// See also [historyRepository].
@ProviderFor(historyRepository)
final historyRepositoryProvider = Provider<HistoryRepository>.internal(
  historyRepository,
  name: r'historyRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$historyRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef HistoryRepositoryRef = ProviderRef<HistoryRepository>;
String _$recentHistoryHash() => r'5acf59e0c529afffa49ad0543affc0b4c5b9cb98';

/// Reactive recent query history for the sidebar (drift `.watch()`).
///
/// Copied from [recentHistory].
@ProviderFor(recentHistory)
final recentHistoryProvider =
    AutoDisposeStreamProvider<List<HistoryEntry>>.internal(
      recentHistory,
      name: r'recentHistoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$recentHistoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef RecentHistoryRef = AutoDisposeStreamProviderRef<List<HistoryEntry>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
