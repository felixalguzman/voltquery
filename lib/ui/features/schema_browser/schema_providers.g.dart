// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'schema_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$schemaRepositoryHash() => r'd385950048e7ea1e89e46c9d78ccbb8accade3f4';

/// The lazy schema tree's cache for the **active** connection (ADR-0008).
///
/// Wraps the per-Connection introspection Session's [SchemaIntrospector] in a
/// [SchemaRepository]. Rebuilds when the current connection changes (the
/// introspection session rebuilds) — a new connection gets a fresh, empty cache.
/// Refresh = `ref.invalidate(schemaRepositoryProvider)`: same session, cleared
/// cache (no reconnect).
///
/// Copied from [schemaRepository].
@ProviderFor(schemaRepository)
final schemaRepositoryProvider =
    AutoDisposeFutureProvider<SchemaRepository>.internal(
      schemaRepository,
      name: r'schemaRepositoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$schemaRepositoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SchemaRepositoryRef = AutoDisposeFutureProviderRef<SchemaRepository>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
