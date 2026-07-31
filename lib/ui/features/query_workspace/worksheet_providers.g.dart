// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'worksheet_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$introspectionSessionHash() =>
    r'b1bbcb87c828fc6842ae64be71763dcf843aa90f';

/// Dedicated **per-Connection introspection Session** (ADR-0008), distinct from
/// the per-Worksheet sessions. Kept alive so it seeds + holds the shared demo.
///
/// Copied from [introspectionSession].
@ProviderFor(introspectionSession)
final introspectionSessionProvider = FutureProvider<Session>.internal(
  introspectionSession,
  name: r'introspectionSessionProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$introspectionSessionHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef IntrospectionSessionRef = FutureProviderRef<Session>;
String _$worksheetSessionHash() => r'707c097a2c43b6652c768b9f24f02158da2bf543';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// The live Session for one Worksheet (ADR-0002/0004): each owns its own,
/// tx-isolated. autoDispose (default) — closing a tab closes the Session.
///
/// Copied from [worksheetSession].
@ProviderFor(worksheetSession)
const worksheetSessionProvider = WorksheetSessionFamily();

/// The live Session for one Worksheet (ADR-0002/0004): each owns its own,
/// tx-isolated. autoDispose (default) — closing a tab closes the Session.
///
/// Copied from [worksheetSession].
class WorksheetSessionFamily extends Family<AsyncValue<Session>> {
  /// The live Session for one Worksheet (ADR-0002/0004): each owns its own,
  /// tx-isolated. autoDispose (default) — closing a tab closes the Session.
  ///
  /// Copied from [worksheetSession].
  const WorksheetSessionFamily();

  /// The live Session for one Worksheet (ADR-0002/0004): each owns its own,
  /// tx-isolated. autoDispose (default) — closing a tab closes the Session.
  ///
  /// Copied from [worksheetSession].
  WorksheetSessionProvider call(String worksheetId) {
    return WorksheetSessionProvider(worksheetId);
  }

  @override
  WorksheetSessionProvider getProviderOverride(
    covariant WorksheetSessionProvider provider,
  ) {
    return call(provider.worksheetId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'worksheetSessionProvider';
}

/// The live Session for one Worksheet (ADR-0002/0004): each owns its own,
/// tx-isolated. autoDispose (default) — closing a tab closes the Session.
///
/// Copied from [worksheetSession].
class WorksheetSessionProvider extends AutoDisposeFutureProvider<Session> {
  /// The live Session for one Worksheet (ADR-0002/0004): each owns its own,
  /// tx-isolated. autoDispose (default) — closing a tab closes the Session.
  ///
  /// Copied from [worksheetSession].
  WorksheetSessionProvider(String worksheetId)
    : this._internal(
        (ref) => worksheetSession(ref as WorksheetSessionRef, worksheetId),
        from: worksheetSessionProvider,
        name: r'worksheetSessionProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$worksheetSessionHash,
        dependencies: WorksheetSessionFamily._dependencies,
        allTransitiveDependencies:
            WorksheetSessionFamily._allTransitiveDependencies,
        worksheetId: worksheetId,
      );

  WorksheetSessionProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.worksheetId,
  }) : super.internal();

  final String worksheetId;

  @override
  Override overrideWith(
    FutureOr<Session> Function(WorksheetSessionRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: WorksheetSessionProvider._internal(
        (ref) => create(ref as WorksheetSessionRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        worksheetId: worksheetId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<Session> createElement() {
    return _WorksheetSessionProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is WorksheetSessionProvider &&
        other.worksheetId == worksheetId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, worksheetId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin WorksheetSessionRef on AutoDisposeFutureProviderRef<Session> {
  /// The parameter `worksheetId` of this provider.
  String get worksheetId;
}

class _WorksheetSessionProviderElement
    extends AutoDisposeFutureProviderElement<Session>
    with WorksheetSessionRef {
  _WorksheetSessionProviderElement(super.provider);

  @override
  String get worksheetId => (origin as WorksheetSessionProvider).worksheetId;
}

String _$schemaTablesHash() => r'5c4b4f0f194daa2610fa398ed0d979517343c998';

/// Tables + views of the active connection (via the introspection session).
///
/// Copied from [schemaTables].
@ProviderFor(schemaTables)
final schemaTablesProvider =
    AutoDisposeFutureProvider<List<TableInfo>>.internal(
      schemaTables,
      name: r'schemaTablesProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$schemaTablesHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SchemaTablesRef = AutoDisposeFutureProviderRef<List<TableInfo>>;
String _$worksheetRunnerHash() => r'9405638bb3eea57d1e21e8b6c06fac79e78486ae';

/// See also [worksheetRunner].
@ProviderFor(worksheetRunner)
final worksheetRunnerProvider = AutoDisposeProvider<WorksheetRunner>.internal(
  worksheetRunner,
  name: r'worksheetRunnerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$worksheetRunnerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef WorksheetRunnerRef = AutoDisposeProviderRef<WorksheetRunner>;
String _$currentConnectionHash() => r'75053f761b67941dfce7f50bc910c6c3be69b4cb';

/// The connection the workspace currently targets.
///
/// Copied from [CurrentConnection].
@ProviderFor(CurrentConnection)
final currentConnectionProvider =
    AutoDisposeNotifierProvider<CurrentConnection, Connection>.internal(
      CurrentConnection.new,
      name: r'currentConnectionProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$currentConnectionHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$CurrentConnection = AutoDisposeNotifier<Connection>;
String _$requestedQueryHash() => r'502e7cd3a6f853a0fbddba30b17c0ba1e83dcfa5';

/// A query the sidebar asks the *active* worksheet to load + run.
///
/// Copied from [RequestedQuery].
@ProviderFor(RequestedQuery)
final requestedQueryProvider =
    AutoDisposeNotifierProvider<RequestedQuery, String?>.internal(
      RequestedQuery.new,
      name: r'requestedQueryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$requestedQueryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$RequestedQuery = AutoDisposeNotifier<String?>;
String _$worksheetHash() => r'a9cd2143b39d0298f28ce51e0cc9156738cfe1f8';

abstract class _$Worksheet
    extends BuildlessAutoDisposeNotifier<WorksheetResult> {
  late final String worksheetId;

  WorksheetResult build(String worksheetId);
}

/// Per-Worksheet result state (family keyed by WorksheetId).
///
/// Copied from [Worksheet].
@ProviderFor(Worksheet)
const worksheetProvider = WorksheetFamily();

/// Per-Worksheet result state (family keyed by WorksheetId).
///
/// Copied from [Worksheet].
class WorksheetFamily extends Family<WorksheetResult> {
  /// Per-Worksheet result state (family keyed by WorksheetId).
  ///
  /// Copied from [Worksheet].
  const WorksheetFamily();

  /// Per-Worksheet result state (family keyed by WorksheetId).
  ///
  /// Copied from [Worksheet].
  WorksheetProvider call(String worksheetId) {
    return WorksheetProvider(worksheetId);
  }

  @override
  WorksheetProvider getProviderOverride(covariant WorksheetProvider provider) {
    return call(provider.worksheetId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'worksheetProvider';
}

/// Per-Worksheet result state (family keyed by WorksheetId).
///
/// Copied from [Worksheet].
class WorksheetProvider
    extends AutoDisposeNotifierProviderImpl<Worksheet, WorksheetResult> {
  /// Per-Worksheet result state (family keyed by WorksheetId).
  ///
  /// Copied from [Worksheet].
  WorksheetProvider(String worksheetId)
    : this._internal(
        () => Worksheet()..worksheetId = worksheetId,
        from: worksheetProvider,
        name: r'worksheetProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$worksheetHash,
        dependencies: WorksheetFamily._dependencies,
        allTransitiveDependencies: WorksheetFamily._allTransitiveDependencies,
        worksheetId: worksheetId,
      );

  WorksheetProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.worksheetId,
  }) : super.internal();

  final String worksheetId;

  @override
  WorksheetResult runNotifierBuild(covariant Worksheet notifier) {
    return notifier.build(worksheetId);
  }

  @override
  Override overrideWith(Worksheet Function() create) {
    return ProviderOverride(
      origin: this,
      override: WorksheetProvider._internal(
        () => create()..worksheetId = worksheetId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        worksheetId: worksheetId,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<Worksheet, WorksheetResult>
  createElement() {
    return _WorksheetProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is WorksheetProvider && other.worksheetId == worksheetId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, worksheetId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin WorksheetRef on AutoDisposeNotifierProviderRef<WorksheetResult> {
  /// The parameter `worksheetId` of this provider.
  String get worksheetId;
}

class _WorksheetProviderElement
    extends AutoDisposeNotifierProviderElement<Worksheet, WorksheetResult>
    with WorksheetRef {
  _WorksheetProviderElement(super.provider);

  @override
  String get worksheetId => (origin as WorksheetProvider).worksheetId;
}

String _$worksheetTabsHash() => r'bdeb62d5a31a2fed4bef3017eb48d2dc3f4569bc';

/// See also [WorksheetTabs].
@ProviderFor(WorksheetTabs)
final worksheetTabsProvider =
    AutoDisposeNotifierProvider<WorksheetTabs, WorksheetTabsState>.internal(
      WorksheetTabs.new,
      name: r'worksheetTabsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$worksheetTabsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$WorksheetTabs = AutoDisposeNotifier<WorksheetTabsState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
