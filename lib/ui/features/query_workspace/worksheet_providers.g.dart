// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'worksheet_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The connection the workspace currently targets.

@ProviderFor(CurrentConnection)
final currentConnectionProvider = CurrentConnectionProvider._();

/// The connection the workspace currently targets.
final class CurrentConnectionProvider
    extends $NotifierProvider<CurrentConnection, Connection> {
  /// The connection the workspace currently targets.
  CurrentConnectionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentConnectionProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentConnectionHash();

  @$internal
  @override
  CurrentConnection create() => CurrentConnection();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Connection value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Connection>(value),
    );
  }
}

String _$currentConnectionHash() => r'75053f761b67941dfce7f50bc910c6c3be69b4cb';

/// The connection the workspace currently targets.

abstract class _$CurrentConnection extends $Notifier<Connection> {
  Connection build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<Connection, Connection>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Connection, Connection>,
              Connection,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Dedicated **per-Connection introspection Session** (ADR-0008), distinct from
/// the per-Worksheet sessions. Kept alive so it seeds + holds the shared demo.

@ProviderFor(introspectionSession)
final introspectionSessionProvider = IntrospectionSessionProvider._();

/// Dedicated **per-Connection introspection Session** (ADR-0008), distinct from
/// the per-Worksheet sessions. Kept alive so it seeds + holds the shared demo.

final class IntrospectionSessionProvider
    extends $FunctionalProvider<AsyncValue<Session>, Session, FutureOr<Session>>
    with $FutureModifier<Session>, $FutureProvider<Session> {
  /// Dedicated **per-Connection introspection Session** (ADR-0008), distinct from
  /// the per-Worksheet sessions. Kept alive so it seeds + holds the shared demo.
  IntrospectionSessionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'introspectionSessionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$introspectionSessionHash();

  @$internal
  @override
  $FutureProviderElement<Session> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Session> create(Ref ref) {
    return introspectionSession(ref);
  }
}

String _$introspectionSessionHash() =>
    r'd54f74462cf3d3e1888f091bd6e012584366bbe3';

/// The live Session for one Worksheet (ADR-0002/0004): each owns its own,
/// tx-isolated. autoDispose (default) — closing a tab closes the Session.

@ProviderFor(worksheetSession)
final worksheetSessionProvider = WorksheetSessionFamily._();

/// The live Session for one Worksheet (ADR-0002/0004): each owns its own,
/// tx-isolated. autoDispose (default) — closing a tab closes the Session.

final class WorksheetSessionProvider
    extends $FunctionalProvider<AsyncValue<Session>, Session, FutureOr<Session>>
    with $FutureModifier<Session>, $FutureProvider<Session> {
  /// The live Session for one Worksheet (ADR-0002/0004): each owns its own,
  /// tx-isolated. autoDispose (default) — closing a tab closes the Session.
  WorksheetSessionProvider._({
    required WorksheetSessionFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'worksheetSessionProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$worksheetSessionHash();

  @override
  String toString() {
    return r'worksheetSessionProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Session> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Session> create(Ref ref) {
    final argument = this.argument as String;
    return worksheetSession(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is WorksheetSessionProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$worksheetSessionHash() => r'4d6734dba4f04fff7bea153db3f7ccc6de6cc9c1';

/// The live Session for one Worksheet (ADR-0002/0004): each owns its own,
/// tx-isolated. autoDispose (default) — closing a tab closes the Session.

final class WorksheetSessionFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Session>, String> {
  WorksheetSessionFamily._()
    : super(
        retry: null,
        name: r'worksheetSessionProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The live Session for one Worksheet (ADR-0002/0004): each owns its own,
  /// tx-isolated. autoDispose (default) — closing a tab closes the Session.

  WorksheetSessionProvider call(String worksheetId) =>
      WorksheetSessionProvider._(argument: worksheetId, from: this);

  @override
  String toString() => r'worksheetSessionProvider';
}

/// Tables + views of the active connection (via the introspection session).

@ProviderFor(schemaTables)
final schemaTablesProvider = SchemaTablesProvider._();

/// Tables + views of the active connection (via the introspection session).

final class SchemaTablesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<TableInfo>>,
          List<TableInfo>,
          FutureOr<List<TableInfo>>
        >
    with $FutureModifier<List<TableInfo>>, $FutureProvider<List<TableInfo>> {
  /// Tables + views of the active connection (via the introspection session).
  SchemaTablesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'schemaTablesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$schemaTablesHash();

  @$internal
  @override
  $FutureProviderElement<List<TableInfo>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<TableInfo>> create(Ref ref) {
    return schemaTables(ref);
  }
}

String _$schemaTablesHash() => r'5c4b4f0f194daa2610fa398ed0d979517343c998';

/// A query the sidebar or history asks the *active* worksheet to load.

@ProviderFor(RequestedQuery)
final requestedQueryProvider = RequestedQueryProvider._();

/// A query the sidebar or history asks the *active* worksheet to load.
final class RequestedQueryProvider
    extends $NotifierProvider<RequestedQuery, QueryRequest?> {
  /// A query the sidebar or history asks the *active* worksheet to load.
  RequestedQueryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'requestedQueryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$requestedQueryHash();

  @$internal
  @override
  RequestedQuery create() => RequestedQuery();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(QueryRequest? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<QueryRequest?>(value),
    );
  }
}

String _$requestedQueryHash() => r'857b39d74466322e822a597ce62c9275986fd2d7';

/// A query the sidebar or history asks the *active* worksheet to load.

abstract class _$RequestedQuery extends $Notifier<QueryRequest?> {
  QueryRequest? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<QueryRequest?, QueryRequest?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<QueryRequest?, QueryRequest?>,
              QueryRequest?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// One-shot initial SQL for a **freshly opened** Worksheet — the sidebar's
/// "open table" opens a *new* tab (never clobbering the current editor) and
/// seeds it here. The Worksheet consumes + clears its seed on first build.
///
/// **keepAlive**: nobody *watches* this (only `put`/`take`), so an autoDispose
/// provider would reset to `{}` in the microtask between opening the tab and the
/// new Worksheet's `initState` reading the seed — losing it.

@ProviderFor(WorksheetSeeds)
final worksheetSeedsProvider = WorksheetSeedsProvider._();

/// One-shot initial SQL for a **freshly opened** Worksheet — the sidebar's
/// "open table" opens a *new* tab (never clobbering the current editor) and
/// seeds it here. The Worksheet consumes + clears its seed on first build.
///
/// **keepAlive**: nobody *watches* this (only `put`/`take`), so an autoDispose
/// provider would reset to `{}` in the microtask between opening the tab and the
/// new Worksheet's `initState` reading the seed — losing it.
final class WorksheetSeedsProvider
    extends $NotifierProvider<WorksheetSeeds, Map<String, WorksheetSeed>> {
  /// One-shot initial SQL for a **freshly opened** Worksheet — the sidebar's
  /// "open table" opens a *new* tab (never clobbering the current editor) and
  /// seeds it here. The Worksheet consumes + clears its seed on first build.
  ///
  /// **keepAlive**: nobody *watches* this (only `put`/`take`), so an autoDispose
  /// provider would reset to `{}` in the microtask between opening the tab and the
  /// new Worksheet's `initState` reading the seed — losing it.
  WorksheetSeedsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'worksheetSeedsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$worksheetSeedsHash();

  @$internal
  @override
  WorksheetSeeds create() => WorksheetSeeds();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, WorksheetSeed> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, WorksheetSeed>>(value),
    );
  }
}

String _$worksheetSeedsHash() => r'6ff508a10f5dfecc5081e54492d5be7b873a43f0';

/// One-shot initial SQL for a **freshly opened** Worksheet — the sidebar's
/// "open table" opens a *new* tab (never clobbering the current editor) and
/// seeds it here. The Worksheet consumes + clears its seed on first build.
///
/// **keepAlive**: nobody *watches* this (only `put`/`take`), so an autoDispose
/// provider would reset to `{}` in the microtask between opening the tab and the
/// new Worksheet's `initState` reading the seed — losing it.

abstract class _$WorksheetSeeds extends $Notifier<Map<String, WorksheetSeed>> {
  Map<String, WorksheetSeed> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<Map<String, WorksheetSeed>, Map<String, WorksheetSeed>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                Map<String, WorksheetSeed>,
                Map<String, WorksheetSeed>
              >,
              Map<String, WorksheetSeed>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Accepted SSH host keys, so a bastion's identity is verified rather than
/// assumed. See [KnownHostsStore].

@ProviderFor(knownHosts)
final knownHostsProvider = KnownHostsProvider._();

/// Accepted SSH host keys, so a bastion's identity is verified rather than
/// assumed. See [KnownHostsStore].

final class KnownHostsProvider
    extends
        $FunctionalProvider<
          AsyncValue<KnownHostsStore>,
          KnownHostsStore,
          FutureOr<KnownHostsStore>
        >
    with $FutureModifier<KnownHostsStore>, $FutureProvider<KnownHostsStore> {
  /// Accepted SSH host keys, so a bastion's identity is verified rather than
  /// assumed. See [KnownHostsStore].
  KnownHostsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'knownHostsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$knownHostsHash();

  @$internal
  @override
  $FutureProviderElement<KnownHostsStore> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<KnownHostsStore> create(Ref ref) {
    return knownHosts(ref);
  }
}

String _$knownHostsHash() => r'a0d70f0d59e6e38bb5fade90dc2a1acf1d63a368';

/// Asks the user whether to trust an unrecognised (or changed) SSH host key.
///
/// Null until the UI registers one, and a null prompt means the tunnel refuses
/// the key: an unverified bastion should fail closed, not silently connect.

@ProviderFor(HostKeyPrompt)
final hostKeyPromptProvider = HostKeyPromptProvider._();

/// Asks the user whether to trust an unrecognised (or changed) SSH host key.
///
/// Null until the UI registers one, and a null prompt means the tunnel refuses
/// the key: an unverified bastion should fail closed, not silently connect.
final class HostKeyPromptProvider
    extends
        $NotifierProvider<
          HostKeyPrompt,
          Future<bool> Function(HostKeyVerdict, String)?
        > {
  /// Asks the user whether to trust an unrecognised (or changed) SSH host key.
  ///
  /// Null until the UI registers one, and a null prompt means the tunnel refuses
  /// the key: an unverified bastion should fail closed, not silently connect.
  HostKeyPromptProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'hostKeyPromptProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$hostKeyPromptHash();

  @$internal
  @override
  HostKeyPrompt create() => HostKeyPrompt();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(
    Future<bool> Function(HostKeyVerdict, String)? value,
  ) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<Future<bool> Function(HostKeyVerdict, String)?>(
            value,
          ),
    );
  }
}

String _$hostKeyPromptHash() => r'a37c5e6c3262794e7c9791981cd553d98ef0a704';

/// Asks the user whether to trust an unrecognised (or changed) SSH host key.
///
/// Null until the UI registers one, and a null prompt means the tunnel refuses
/// the key: an unverified bastion should fail closed, not silently connect.

abstract class _$HostKeyPrompt
    extends $Notifier<Future<bool> Function(HostKeyVerdict, String)?> {
  Future<bool> Function(HostKeyVerdict, String)? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              Future<bool> Function(HostKeyVerdict, String)?,
              Future<bool> Function(HostKeyVerdict, String)?
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                Future<bool> Function(HostKeyVerdict, String)?,
                Future<bool> Function(HostKeyVerdict, String)?
              >,
              Future<bool> Function(HostKeyVerdict, String)?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Which table each worksheet was opened for, when it came from the schema
/// tree.
///
/// Lets a second click on the same table return to the tab it already has
/// rather than opening another one — clicking five tables should leave five
/// tabs, not five per click.

@ProviderFor(WorksheetOrigins)
final worksheetOriginsProvider = WorksheetOriginsProvider._();

/// Which table each worksheet was opened for, when it came from the schema
/// tree.
///
/// Lets a second click on the same table return to the tab it already has
/// rather than opening another one — clicking five tables should leave five
/// tabs, not five per click.
final class WorksheetOriginsProvider
    extends $NotifierProvider<WorksheetOrigins, Map<String, String>> {
  /// Which table each worksheet was opened for, when it came from the schema
  /// tree.
  ///
  /// Lets a second click on the same table return to the tab it already has
  /// rather than opening another one — clicking five tables should leave five
  /// tabs, not five per click.
  WorksheetOriginsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'worksheetOriginsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$worksheetOriginsHash();

  @$internal
  @override
  WorksheetOrigins create() => WorksheetOrigins();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, String>>(value),
    );
  }
}

String _$worksheetOriginsHash() => r'c6954a5d84191c8f02b51e4463123ef7814ecb5f';

/// Which table each worksheet was opened for, when it came from the schema
/// tree.
///
/// Lets a second click on the same table return to the tab it already has
/// rather than opening another one — clicking five tables should leave five
/// tabs, not five per click.

abstract class _$WorksheetOrigins extends $Notifier<Map<String, String>> {
  Map<String, String> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<Map<String, String>, Map<String, String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Map<String, String>, Map<String, String>>,
              Map<String, String>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Watches settings, so changing the render cap takes effect on the next run
/// rather than the next launch.

@ProviderFor(worksheetRunner)
final worksheetRunnerProvider = WorksheetRunnerProvider._();

/// Watches settings, so changing the render cap takes effect on the next run
/// rather than the next launch.

final class WorksheetRunnerProvider
    extends
        $FunctionalProvider<WorksheetRunner, WorksheetRunner, WorksheetRunner>
    with $Provider<WorksheetRunner> {
  /// Watches settings, so changing the render cap takes effect on the next run
  /// rather than the next launch.
  WorksheetRunnerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'worksheetRunnerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$worksheetRunnerHash();

  @$internal
  @override
  $ProviderElement<WorksheetRunner> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  WorksheetRunner create(Ref ref) {
    return worksheetRunner(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WorksheetRunner value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WorksheetRunner>(value),
    );
  }
}

String _$worksheetRunnerHash() => r'b5c89e54403b1a8b238c73a2a480b3c642743def';

/// Pending cell edits for one result grid, keyed `<worksheetId>:<resultIndex>`
/// so each result sub-tab stages independently.
///
/// **keepAlive**: the grid rebuilds as the user types elsewhere; an autoDispose
/// buffer would silently drop staged edits.

@ProviderFor(GridEdits)
final gridEditsProvider = GridEditsFamily._();

/// Pending cell edits for one result grid, keyed `<worksheetId>:<resultIndex>`
/// so each result sub-tab stages independently.
///
/// **keepAlive**: the grid rebuilds as the user types elsewhere; an autoDispose
/// buffer would silently drop staged edits.
final class GridEditsProvider
    extends $NotifierProvider<GridEdits, GridEditBuffer> {
  /// Pending cell edits for one result grid, keyed `<worksheetId>:<resultIndex>`
  /// so each result sub-tab stages independently.
  ///
  /// **keepAlive**: the grid rebuilds as the user types elsewhere; an autoDispose
  /// buffer would silently drop staged edits.
  GridEditsProvider._({
    required GridEditsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'gridEditsProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$gridEditsHash();

  @override
  String toString() {
    return r'gridEditsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  GridEdits create() => GridEdits();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GridEditBuffer value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GridEditBuffer>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is GridEditsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$gridEditsHash() => r'28df9704b11e314a4740d5578fdd8541b4fb05e0';

/// Pending cell edits for one result grid, keyed `<worksheetId>:<resultIndex>`
/// so each result sub-tab stages independently.
///
/// **keepAlive**: the grid rebuilds as the user types elsewhere; an autoDispose
/// buffer would silently drop staged edits.

final class GridEditsFamily extends $Family
    with
        $ClassFamilyOverride<
          GridEdits,
          GridEditBuffer,
          GridEditBuffer,
          GridEditBuffer,
          String
        > {
  GridEditsFamily._()
    : super(
        retry: null,
        name: r'gridEditsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// Pending cell edits for one result grid, keyed `<worksheetId>:<resultIndex>`
  /// so each result sub-tab stages independently.
  ///
  /// **keepAlive**: the grid rebuilds as the user types elsewhere; an autoDispose
  /// buffer would silently drop staged edits.

  GridEditsProvider call(String gridId) =>
      GridEditsProvider._(argument: gridId, from: this);

  @override
  String toString() => r'gridEditsProvider';
}

/// Pending cell edits for one result grid, keyed `<worksheetId>:<resultIndex>`
/// so each result sub-tab stages independently.
///
/// **keepAlive**: the grid rebuilds as the user types elsewhere; an autoDispose
/// buffer would silently drop staged edits.

abstract class _$GridEdits extends $Notifier<GridEditBuffer> {
  late final _$args = ref.$arg as String;
  String get gridId => _$args;

  GridEditBuffer build(String gridId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<GridEditBuffer, GridEditBuffer>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<GridEditBuffer, GridEditBuffer>,
              GridEditBuffer,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

@ProviderFor(WorksheetCommands)
final worksheetCommandsProvider = WorksheetCommandsProvider._();

final class WorksheetCommandsProvider
    extends $NotifierProvider<WorksheetCommands, WorksheetCommandEvent?> {
  WorksheetCommandsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'worksheetCommandsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$worksheetCommandsHash();

  @$internal
  @override
  WorksheetCommands create() => WorksheetCommands();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WorksheetCommandEvent? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WorksheetCommandEvent?>(value),
    );
  }
}

String _$worksheetCommandsHash() => r'68885aa59a0780c054e9674b0baa24539f494a92';

abstract class _$WorksheetCommands extends $Notifier<WorksheetCommandEvent?> {
  WorksheetCommandEvent? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<WorksheetCommandEvent?, WorksheetCommandEvent?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<WorksheetCommandEvent?, WorksheetCommandEvent?>,
              WorksheetCommandEvent?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Run-loop error policy (ADR-0007). Default **stop-on-error**; toggled to
/// continue-on-error from the worksheet toolbar. Global (kept alive) so it
/// persists across worksheet rebuilds.

@ProviderFor(ContinueOnError)
final continueOnErrorProvider = ContinueOnErrorProvider._();

/// Run-loop error policy (ADR-0007). Default **stop-on-error**; toggled to
/// continue-on-error from the worksheet toolbar. Global (kept alive) so it
/// persists across worksheet rebuilds.
final class ContinueOnErrorProvider
    extends $NotifierProvider<ContinueOnError, bool> {
  /// Run-loop error policy (ADR-0007). Default **stop-on-error**; toggled to
  /// continue-on-error from the worksheet toolbar. Global (kept alive) so it
  /// persists across worksheet rebuilds.
  ContinueOnErrorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'continueOnErrorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$continueOnErrorHash();

  @$internal
  @override
  ContinueOnError create() => ContinueOnError();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$continueOnErrorHash() => r'55541eed319adbd206cb1bc2177f23fd25a8c422';

/// Run-loop error policy (ADR-0007). Default **stop-on-error**; toggled to
/// continue-on-error from the worksheet toolbar. Global (kept alive) so it
/// persists across worksheet rebuilds.

abstract class _$ContinueOnError extends $Notifier<bool> {
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

/// Per-Worksheet transaction mode (ADR-0007). Off = autocommit (each statement
/// commits immediately). On = manual: the app issues `begin()` before the first
/// run and holds the tx open until the user Commits/Rolls back.

@ProviderFor(ManualCommit)
final manualCommitProvider = ManualCommitFamily._();

/// Per-Worksheet transaction mode (ADR-0007). Off = autocommit (each statement
/// commits immediately). On = manual: the app issues `begin()` before the first
/// run and holds the tx open until the user Commits/Rolls back.
final class ManualCommitProvider extends $NotifierProvider<ManualCommit, bool> {
  /// Per-Worksheet transaction mode (ADR-0007). Off = autocommit (each statement
  /// commits immediately). On = manual: the app issues `begin()` before the first
  /// run and holds the tx open until the user Commits/Rolls back.
  ManualCommitProvider._({
    required ManualCommitFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'manualCommitProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$manualCommitHash();

  @override
  String toString() {
    return r'manualCommitProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ManualCommit create() => ManualCommit();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ManualCommitProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$manualCommitHash() => r'c2dbf046401069ca3f4410c2ded85af1653f55fd';

/// Per-Worksheet transaction mode (ADR-0007). Off = autocommit (each statement
/// commits immediately). On = manual: the app issues `begin()` before the first
/// run and holds the tx open until the user Commits/Rolls back.

final class ManualCommitFamily extends $Family
    with $ClassFamilyOverride<ManualCommit, bool, bool, bool, String> {
  ManualCommitFamily._()
    : super(
        retry: null,
        name: r'manualCommitProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Per-Worksheet transaction mode (ADR-0007). Off = autocommit (each statement
  /// commits immediately). On = manual: the app issues `begin()` before the first
  /// run and holds the tx open until the user Commits/Rolls back.

  ManualCommitProvider call(String worksheetId) =>
      ManualCommitProvider._(argument: worksheetId, from: this);

  @override
  String toString() => r'manualCommitProvider';
}

/// Per-Worksheet transaction mode (ADR-0007). Off = autocommit (each statement
/// commits immediately). On = manual: the app issues `begin()` before the first
/// run and holds the tx open until the user Commits/Rolls back.

abstract class _$ManualCommit extends $Notifier<bool> {
  late final _$args = ref.$arg as String;
  String get worksheetId => _$args;

  bool build(String worksheetId);
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
    return element.handleCreate(ref, () => build(_$args));
  }
}

/// Whether a manual transaction is currently open for a Worksheet — the single
/// source of truth for the Commit/Rollback affordances (drivers don't reliably
/// report `inTransaction` for pg/mysql, so we track it app-side).

@ProviderFor(WorksheetTx)
final worksheetTxProvider = WorksheetTxFamily._();

/// Whether a manual transaction is currently open for a Worksheet — the single
/// source of truth for the Commit/Rollback affordances (drivers don't reliably
/// report `inTransaction` for pg/mysql, so we track it app-side).
final class WorksheetTxProvider extends $NotifierProvider<WorksheetTx, bool> {
  /// Whether a manual transaction is currently open for a Worksheet — the single
  /// source of truth for the Commit/Rollback affordances (drivers don't reliably
  /// report `inTransaction` for pg/mysql, so we track it app-side).
  WorksheetTxProvider._({
    required WorksheetTxFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'worksheetTxProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$worksheetTxHash();

  @override
  String toString() {
    return r'worksheetTxProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  WorksheetTx create() => WorksheetTx();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is WorksheetTxProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$worksheetTxHash() => r'13f160b782ff77fb38c96fd3fbf48b4016b2670a';

/// Whether a manual transaction is currently open for a Worksheet — the single
/// source of truth for the Commit/Rollback affordances (drivers don't reliably
/// report `inTransaction` for pg/mysql, so we track it app-side).

final class WorksheetTxFamily extends $Family
    with $ClassFamilyOverride<WorksheetTx, bool, bool, bool, String> {
  WorksheetTxFamily._()
    : super(
        retry: null,
        name: r'worksheetTxProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Whether a manual transaction is currently open for a Worksheet — the single
  /// source of truth for the Commit/Rollback affordances (drivers don't reliably
  /// report `inTransaction` for pg/mysql, so we track it app-side).

  WorksheetTxProvider call(String worksheetId) =>
      WorksheetTxProvider._(argument: worksheetId, from: this);

  @override
  String toString() => r'worksheetTxProvider';
}

/// Whether a manual transaction is currently open for a Worksheet — the single
/// source of truth for the Commit/Rollback affordances (drivers don't reliably
/// report `inTransaction` for pg/mysql, so we track it app-side).

abstract class _$WorksheetTx extends $Notifier<bool> {
  late final _$args = ref.$arg as String;
  String get worksheetId => _$args;

  bool build(String worksheetId);
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
    return element.handleCreate(ref, () => build(_$args));
  }
}

/// Per-Worksheet result state (family keyed by WorksheetId).

@ProviderFor(Worksheet)
final worksheetProvider = WorksheetFamily._();

/// Per-Worksheet result state (family keyed by WorksheetId).
final class WorksheetProvider
    extends $NotifierProvider<Worksheet, WorksheetResult> {
  /// Per-Worksheet result state (family keyed by WorksheetId).
  WorksheetProvider._({
    required WorksheetFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'worksheetProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$worksheetHash();

  @override
  String toString() {
    return r'worksheetProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  Worksheet create() => Worksheet();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WorksheetResult value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WorksheetResult>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is WorksheetProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$worksheetHash() => r'53eddabac30a036b19f7a176deba598e76073464';

/// Per-Worksheet result state (family keyed by WorksheetId).

final class WorksheetFamily extends $Family
    with
        $ClassFamilyOverride<
          Worksheet,
          WorksheetResult,
          WorksheetResult,
          WorksheetResult,
          String
        > {
  WorksheetFamily._()
    : super(
        retry: null,
        name: r'worksheetProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Per-Worksheet result state (family keyed by WorksheetId).

  WorksheetProvider call(String worksheetId) =>
      WorksheetProvider._(argument: worksheetId, from: this);

  @override
  String toString() => r'worksheetProvider';
}

/// Per-Worksheet result state (family keyed by WorksheetId).

abstract class _$Worksheet extends $Notifier<WorksheetResult> {
  late final _$args = ref.$arg as String;
  String get worksheetId => _$args;

  WorksheetResult build(String worksheetId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<WorksheetResult, WorksheetResult>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<WorksheetResult, WorksheetResult>,
              WorksheetResult,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

@ProviderFor(WorksheetTabs)
final worksheetTabsProvider = WorksheetTabsProvider._();

final class WorksheetTabsProvider
    extends $NotifierProvider<WorksheetTabs, WorksheetTabsState> {
  WorksheetTabsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'worksheetTabsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$worksheetTabsHash();

  @$internal
  @override
  WorksheetTabs create() => WorksheetTabs();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WorksheetTabsState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WorksheetTabsState>(value),
    );
  }
}

String _$worksheetTabsHash() => r'c105f6dbbaf1a250e8cdbe104722dbe97f0b47b9';

abstract class _$WorksheetTabs extends $Notifier<WorksheetTabsState> {
  WorksheetTabsState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<WorksheetTabsState, WorksheetTabsState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<WorksheetTabsState, WorksheetTabsState>,
              WorksheetTabsState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
