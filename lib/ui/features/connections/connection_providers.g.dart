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
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
