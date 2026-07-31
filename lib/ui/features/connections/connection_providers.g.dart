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
String _$sessionSecretsHash() => r'84efcd0b51a13a32fbf61f0fe1a5457e74d13aae';

/// In-memory session secrets keyed by connection id. **PLACEHOLDER** for the
/// credentials vault (ADR-0006) — held in memory only, never persisted, lost on
/// quit. Replace with the SecretStore (keychain / encrypted vault).
///
/// Copied from [SessionSecrets].
@ProviderFor(SessionSecrets)
final sessionSecretsProvider =
    NotifierProvider<SessionSecrets, Map<String, String>>.internal(
      SessionSecrets.new,
      name: r'sessionSecretsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$sessionSecretsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$SessionSecrets = Notifier<Map<String, String>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
