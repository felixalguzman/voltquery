import 'package:riverpod/riverpod.dart' show Ref;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/drivers/driver_factory.dart';
import '../query_workspace/worksheet_providers.dart';
import 'schema_repository.dart';

part 'schema_providers.g.dart';

/// The lazy schema tree's cache for the **active** connection (ADR-0008).
///
/// Wraps the per-Connection introspection Session's [SchemaIntrospector] in a
/// [SchemaRepository]. Rebuilds when the current connection changes (the
/// introspection session rebuilds) — a new connection gets a fresh, empty cache.
/// Refresh = `ref.invalidate(schemaRepositoryProvider)`: same session, cleared
/// cache (no reconnect).
@riverpod
Future<SchemaRepository> schemaRepository(Ref ref) async {
  final session = await ref.watch(introspectionSessionProvider.future);
  final engine = ref.watch(currentConnectionProvider).engine;
  return SchemaRepository(
    introspector: session.schema,
    capabilities: driverFor(engine).capabilities,
  );
}
