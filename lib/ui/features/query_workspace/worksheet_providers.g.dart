// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'worksheet_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$introspectionSessionHash() =>
    r'd54f74462cf3d3e1888f091bd6e012584366bbe3';

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
String _$worksheetSessionHash() => r'4d6734dba4f04fff7bea153db3f7ccc6de6cc9c1';

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
String _$worksheetSeedsHash() => r'fca6e88af46bd186fafc223bb043397085b9c0b6';

/// One-shot initial SQL for a **freshly opened** Worksheet — the sidebar's
/// "open table" opens a *new* tab (never clobbering the current editor) and
/// seeds it here. The Worksheet consumes + clears its seed on first build.
///
/// **keepAlive**: nobody *watches* this (only `put`/`take`), so an autoDispose
/// provider would reset to `{}` in the microtask between opening the tab and the
/// new Worksheet's `initState` reading the seed — losing it.
///
/// Copied from [WorksheetSeeds].
@ProviderFor(WorksheetSeeds)
final worksheetSeedsProvider =
    NotifierProvider<WorksheetSeeds, Map<String, String>>.internal(
      WorksheetSeeds.new,
      name: r'worksheetSeedsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$worksheetSeedsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$WorksheetSeeds = Notifier<Map<String, String>>;
String _$worksheetCommandsHash() => r'68885aa59a0780c054e9674b0baa24539f494a92';

/// See also [WorksheetCommands].
@ProviderFor(WorksheetCommands)
final worksheetCommandsProvider =
    NotifierProvider<WorksheetCommands, WorksheetCommandEvent?>.internal(
      WorksheetCommands.new,
      name: r'worksheetCommandsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$worksheetCommandsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$WorksheetCommands = Notifier<WorksheetCommandEvent?>;
String _$continueOnErrorHash() => r'55541eed319adbd206cb1bc2177f23fd25a8c422';

/// Run-loop error policy (ADR-0007). Default **stop-on-error**; toggled to
/// continue-on-error from the worksheet toolbar. Global (kept alive) so it
/// persists across worksheet rebuilds.
///
/// Copied from [ContinueOnError].
@ProviderFor(ContinueOnError)
final continueOnErrorProvider =
    NotifierProvider<ContinueOnError, bool>.internal(
      ContinueOnError.new,
      name: r'continueOnErrorProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$continueOnErrorHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ContinueOnError = Notifier<bool>;
String _$manualCommitHash() => r'c2dbf046401069ca3f4410c2ded85af1653f55fd';

abstract class _$ManualCommit extends BuildlessAutoDisposeNotifier<bool> {
  late final String worksheetId;

  bool build(String worksheetId);
}

/// Per-Worksheet transaction mode (ADR-0007). Off = autocommit (each statement
/// commits immediately). On = manual: the app issues `begin()` before the first
/// run and holds the tx open until the user Commits/Rolls back.
///
/// Copied from [ManualCommit].
@ProviderFor(ManualCommit)
const manualCommitProvider = ManualCommitFamily();

/// Per-Worksheet transaction mode (ADR-0007). Off = autocommit (each statement
/// commits immediately). On = manual: the app issues `begin()` before the first
/// run and holds the tx open until the user Commits/Rolls back.
///
/// Copied from [ManualCommit].
class ManualCommitFamily extends Family<bool> {
  /// Per-Worksheet transaction mode (ADR-0007). Off = autocommit (each statement
  /// commits immediately). On = manual: the app issues `begin()` before the first
  /// run and holds the tx open until the user Commits/Rolls back.
  ///
  /// Copied from [ManualCommit].
  const ManualCommitFamily();

  /// Per-Worksheet transaction mode (ADR-0007). Off = autocommit (each statement
  /// commits immediately). On = manual: the app issues `begin()` before the first
  /// run and holds the tx open until the user Commits/Rolls back.
  ///
  /// Copied from [ManualCommit].
  ManualCommitProvider call(String worksheetId) {
    return ManualCommitProvider(worksheetId);
  }

  @override
  ManualCommitProvider getProviderOverride(
    covariant ManualCommitProvider provider,
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
  String? get name => r'manualCommitProvider';
}

/// Per-Worksheet transaction mode (ADR-0007). Off = autocommit (each statement
/// commits immediately). On = manual: the app issues `begin()` before the first
/// run and holds the tx open until the user Commits/Rolls back.
///
/// Copied from [ManualCommit].
class ManualCommitProvider
    extends AutoDisposeNotifierProviderImpl<ManualCommit, bool> {
  /// Per-Worksheet transaction mode (ADR-0007). Off = autocommit (each statement
  /// commits immediately). On = manual: the app issues `begin()` before the first
  /// run and holds the tx open until the user Commits/Rolls back.
  ///
  /// Copied from [ManualCommit].
  ManualCommitProvider(String worksheetId)
    : this._internal(
        () => ManualCommit()..worksheetId = worksheetId,
        from: manualCommitProvider,
        name: r'manualCommitProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$manualCommitHash,
        dependencies: ManualCommitFamily._dependencies,
        allTransitiveDependencies:
            ManualCommitFamily._allTransitiveDependencies,
        worksheetId: worksheetId,
      );

  ManualCommitProvider._internal(
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
  bool runNotifierBuild(covariant ManualCommit notifier) {
    return notifier.build(worksheetId);
  }

  @override
  Override overrideWith(ManualCommit Function() create) {
    return ProviderOverride(
      origin: this,
      override: ManualCommitProvider._internal(
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
  AutoDisposeNotifierProviderElement<ManualCommit, bool> createElement() {
    return _ManualCommitProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ManualCommitProvider && other.worksheetId == worksheetId;
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
mixin ManualCommitRef on AutoDisposeNotifierProviderRef<bool> {
  /// The parameter `worksheetId` of this provider.
  String get worksheetId;
}

class _ManualCommitProviderElement
    extends AutoDisposeNotifierProviderElement<ManualCommit, bool>
    with ManualCommitRef {
  _ManualCommitProviderElement(super.provider);

  @override
  String get worksheetId => (origin as ManualCommitProvider).worksheetId;
}

String _$worksheetTxHash() => r'13f160b782ff77fb38c96fd3fbf48b4016b2670a';

abstract class _$WorksheetTx extends BuildlessAutoDisposeNotifier<bool> {
  late final String worksheetId;

  bool build(String worksheetId);
}

/// Whether a manual transaction is currently open for a Worksheet — the single
/// source of truth for the Commit/Rollback affordances (drivers don't reliably
/// report `inTransaction` for pg/mysql, so we track it app-side).
///
/// Copied from [WorksheetTx].
@ProviderFor(WorksheetTx)
const worksheetTxProvider = WorksheetTxFamily();

/// Whether a manual transaction is currently open for a Worksheet — the single
/// source of truth for the Commit/Rollback affordances (drivers don't reliably
/// report `inTransaction` for pg/mysql, so we track it app-side).
///
/// Copied from [WorksheetTx].
class WorksheetTxFamily extends Family<bool> {
  /// Whether a manual transaction is currently open for a Worksheet — the single
  /// source of truth for the Commit/Rollback affordances (drivers don't reliably
  /// report `inTransaction` for pg/mysql, so we track it app-side).
  ///
  /// Copied from [WorksheetTx].
  const WorksheetTxFamily();

  /// Whether a manual transaction is currently open for a Worksheet — the single
  /// source of truth for the Commit/Rollback affordances (drivers don't reliably
  /// report `inTransaction` for pg/mysql, so we track it app-side).
  ///
  /// Copied from [WorksheetTx].
  WorksheetTxProvider call(String worksheetId) {
    return WorksheetTxProvider(worksheetId);
  }

  @override
  WorksheetTxProvider getProviderOverride(
    covariant WorksheetTxProvider provider,
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
  String? get name => r'worksheetTxProvider';
}

/// Whether a manual transaction is currently open for a Worksheet — the single
/// source of truth for the Commit/Rollback affordances (drivers don't reliably
/// report `inTransaction` for pg/mysql, so we track it app-side).
///
/// Copied from [WorksheetTx].
class WorksheetTxProvider
    extends AutoDisposeNotifierProviderImpl<WorksheetTx, bool> {
  /// Whether a manual transaction is currently open for a Worksheet — the single
  /// source of truth for the Commit/Rollback affordances (drivers don't reliably
  /// report `inTransaction` for pg/mysql, so we track it app-side).
  ///
  /// Copied from [WorksheetTx].
  WorksheetTxProvider(String worksheetId)
    : this._internal(
        () => WorksheetTx()..worksheetId = worksheetId,
        from: worksheetTxProvider,
        name: r'worksheetTxProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$worksheetTxHash,
        dependencies: WorksheetTxFamily._dependencies,
        allTransitiveDependencies: WorksheetTxFamily._allTransitiveDependencies,
        worksheetId: worksheetId,
      );

  WorksheetTxProvider._internal(
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
  bool runNotifierBuild(covariant WorksheetTx notifier) {
    return notifier.build(worksheetId);
  }

  @override
  Override overrideWith(WorksheetTx Function() create) {
    return ProviderOverride(
      origin: this,
      override: WorksheetTxProvider._internal(
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
  AutoDisposeNotifierProviderElement<WorksheetTx, bool> createElement() {
    return _WorksheetTxProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is WorksheetTxProvider && other.worksheetId == worksheetId;
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
mixin WorksheetTxRef on AutoDisposeNotifierProviderRef<bool> {
  /// The parameter `worksheetId` of this provider.
  String get worksheetId;
}

class _WorksheetTxProviderElement
    extends AutoDisposeNotifierProviderElement<WorksheetTx, bool>
    with WorksheetTxRef {
  _WorksheetTxProviderElement(super.provider);

  @override
  String get worksheetId => (origin as WorksheetTxProvider).worksheetId;
}

String _$worksheetHash() => r'edb653e5ffc3b94e42887681cb993ce71d06ba07';

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

String _$worksheetTabsHash() => r'b6f02373969814b18c88a5a038191d40b0053309';

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
