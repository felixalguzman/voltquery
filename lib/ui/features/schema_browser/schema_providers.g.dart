// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'schema_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The schema tree's filter box: whether it's showing, and its text.
///
/// A provider rather than local state because the toggle lives in the section
/// header while the matching happens inside the tree, and those are separate
/// widgets by design (the header is shared across all three sidebar sections).

@ProviderFor(SchemaFilter)
final schemaFilterProvider = SchemaFilterProvider._();

/// The schema tree's filter box: whether it's showing, and its text.
///
/// A provider rather than local state because the toggle lives in the section
/// header while the matching happens inside the tree, and those are separate
/// widgets by design (the header is shared across all three sidebar sections).
final class SchemaFilterProvider
    extends $NotifierProvider<SchemaFilter, FilterState> {
  /// The schema tree's filter box: whether it's showing, and its text.
  ///
  /// A provider rather than local state because the toggle lives in the section
  /// header while the matching happens inside the tree, and those are separate
  /// widgets by design (the header is shared across all three sidebar sections).
  SchemaFilterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'schemaFilterProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$schemaFilterHash();

  @$internal
  @override
  SchemaFilter create() => SchemaFilter();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FilterState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FilterState>(value),
    );
  }
}

String _$schemaFilterHash() => r'a943ca247ff7aec7ac15203c76f894f095c68814';

/// The schema tree's filter box: whether it's showing, and its text.
///
/// A provider rather than local state because the toggle lives in the section
/// header while the matching happens inside the tree, and those are separate
/// widgets by design (the header is shared across all three sidebar sections).

abstract class _$SchemaFilter extends $Notifier<FilterState> {
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

/// The lazy schema tree's cache for the **active** connection (ADR-0008).
///
/// Wraps the per-Connection introspection Session's [SchemaIntrospector] in a
/// [SchemaRepository]. Rebuilds when the current connection changes (the
/// introspection session rebuilds) — a new connection gets a fresh, empty cache.
/// Refresh = `ref.invalidate(schemaRepositoryProvider)`: same session, cleared
/// cache (no reconnect).

@ProviderFor(schemaRepository)
final schemaRepositoryProvider = SchemaRepositoryProvider._();

/// The lazy schema tree's cache for the **active** connection (ADR-0008).
///
/// Wraps the per-Connection introspection Session's [SchemaIntrospector] in a
/// [SchemaRepository]. Rebuilds when the current connection changes (the
/// introspection session rebuilds) — a new connection gets a fresh, empty cache.
/// Refresh = `ref.invalidate(schemaRepositoryProvider)`: same session, cleared
/// cache (no reconnect).

final class SchemaRepositoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<SchemaRepository>,
          SchemaRepository,
          FutureOr<SchemaRepository>
        >
    with $FutureModifier<SchemaRepository>, $FutureProvider<SchemaRepository> {
  /// The lazy schema tree's cache for the **active** connection (ADR-0008).
  ///
  /// Wraps the per-Connection introspection Session's [SchemaIntrospector] in a
  /// [SchemaRepository]. Rebuilds when the current connection changes (the
  /// introspection session rebuilds) — a new connection gets a fresh, empty cache.
  /// Refresh = `ref.invalidate(schemaRepositoryProvider)`: same session, cleared
  /// cache (no reconnect).
  SchemaRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'schemaRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$schemaRepositoryHash();

  @$internal
  @override
  $FutureProviderElement<SchemaRepository> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SchemaRepository> create(Ref ref) {
    return schemaRepository(ref);
  }
}

String _$schemaRepositoryHash() => r'd385950048e7ea1e89e46c9d78ccbb8accade3f4';
