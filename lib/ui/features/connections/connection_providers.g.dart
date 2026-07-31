// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connection_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$connectionRepositoryHash() =>
    r'38deafead5c0773ad50d3aaa23a19a298e66b5e0';

/// See also [connectionRepository].
@ProviderFor(connectionRepository)
final connectionRepositoryProvider = Provider<ConnectionRepository>.internal(
  connectionRepository,
  name: r'connectionRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$connectionRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ConnectionRepositoryRef = ProviderRef<ConnectionRepository>;
String _$savedConnectionsHash() => r'0780c746af6d92926e509d961525e4415806d484';

/// Reactive list of saved connections (drift `.watch()`).
///
/// Copied from [savedConnections].
@ProviderFor(savedConnections)
final savedConnectionsProvider =
    AutoDisposeStreamProvider<List<Connection>>.internal(
      savedConnections,
      name: r'savedConnectionsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$savedConnectionsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SavedConnectionsRef = AutoDisposeStreamProviderRef<List<Connection>>;
String _$secretStoreHash() => r'f64f2669b369366a7738c9788089e3843d4fefef';

/// The credentials vault (ADR-0006). Encrypted file in the app-support dir; the
/// derived key lives in memory only, so it starts **locked** each launch.
///
/// Copied from [secretStore].
@ProviderFor(secretStore)
final secretStoreProvider = FutureProvider<SecretStore>.internal(
  secretStore,
  name: r'secretStoreProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$secretStoreHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SecretStoreRef = FutureProviderRef<SecretStore>;
String _$vaultLockHash() => r'c08f880268e103a02c98eb6b62d22c6c30b0a364';

/// Reactive vault lock state (unlocked?), updated by unlock/lock actions so the
/// UI can show the padlock. Session-scoped.
///
/// Copied from [VaultLock].
@ProviderFor(VaultLock)
final vaultLockProvider = AutoDisposeNotifierProvider<VaultLock, bool>.internal(
  VaultLock.new,
  name: r'vaultLockProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$vaultLockHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$VaultLock = AutoDisposeNotifier<bool>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
