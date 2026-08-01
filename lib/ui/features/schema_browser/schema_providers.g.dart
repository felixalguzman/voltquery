// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'schema_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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
