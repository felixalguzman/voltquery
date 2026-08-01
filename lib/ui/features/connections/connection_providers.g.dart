// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connection_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(connectionRepository)
final connectionRepositoryProvider = ConnectionRepositoryProvider._();

final class ConnectionRepositoryProvider
    extends
        $FunctionalProvider<
          ConnectionRepository,
          ConnectionRepository,
          ConnectionRepository
        >
    with $Provider<ConnectionRepository> {
  ConnectionRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'connectionRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$connectionRepositoryHash();

  @$internal
  @override
  $ProviderElement<ConnectionRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ConnectionRepository create(Ref ref) {
    return connectionRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ConnectionRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ConnectionRepository>(value),
    );
  }
}

String _$connectionRepositoryHash() =>
    r'38deafead5c0773ad50d3aaa23a19a298e66b5e0';

/// Reactive list of saved connections (drift `.watch()`).

@ProviderFor(savedConnections)
final savedConnectionsProvider = SavedConnectionsProvider._();

/// Reactive list of saved connections (drift `.watch()`).

final class SavedConnectionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Connection>>,
          List<Connection>,
          Stream<List<Connection>>
        >
    with $FutureModifier<List<Connection>>, $StreamProvider<List<Connection>> {
  /// Reactive list of saved connections (drift `.watch()`).
  SavedConnectionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'savedConnectionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$savedConnectionsHash();

  @$internal
  @override
  $StreamProviderElement<List<Connection>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Connection>> create(Ref ref) {
    return savedConnections(ref);
  }
}

String _$savedConnectionsHash() => r'0780c746af6d92926e509d961525e4415806d484';

/// The credentials vault (ADR-0006). Encrypted file in the app-support dir; the
/// derived key lives in memory only, so it starts **locked** each launch.

@ProviderFor(secretStore)
final secretStoreProvider = SecretStoreProvider._();

/// The credentials vault (ADR-0006). Encrypted file in the app-support dir; the
/// derived key lives in memory only, so it starts **locked** each launch.

final class SecretStoreProvider
    extends
        $FunctionalProvider<
          AsyncValue<SecretStore>,
          SecretStore,
          FutureOr<SecretStore>
        >
    with $FutureModifier<SecretStore>, $FutureProvider<SecretStore> {
  /// The credentials vault (ADR-0006). Encrypted file in the app-support dir; the
  /// derived key lives in memory only, so it starts **locked** each launch.
  SecretStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'secretStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$secretStoreHash();

  @$internal
  @override
  $FutureProviderElement<SecretStore> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SecretStore> create(Ref ref) {
    return secretStore(ref);
  }
}

String _$secretStoreHash() => r'f64f2669b369366a7738c9788089e3843d4fefef';

/// Reactive vault lock state (unlocked?), updated by unlock/lock actions so the
/// UI can show the padlock. Session-scoped.

@ProviderFor(VaultLock)
final vaultLockProvider = VaultLockProvider._();

/// Reactive vault lock state (unlocked?), updated by unlock/lock actions so the
/// UI can show the padlock. Session-scoped.
final class VaultLockProvider extends $NotifierProvider<VaultLock, bool> {
  /// Reactive vault lock state (unlocked?), updated by unlock/lock actions so the
  /// UI can show the padlock. Session-scoped.
  VaultLockProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vaultLockProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vaultLockHash();

  @$internal
  @override
  VaultLock create() => VaultLock();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$vaultLockHash() => r'c08f880268e103a02c98eb6b62d22c6c30b0a364';

/// Reactive vault lock state (unlocked?), updated by unlock/lock actions so the
/// UI can show the padlock. Session-scoped.

abstract class _$VaultLock extends $Notifier<bool> {
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
