import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/drivers/driver_factory.dart';
import '../../core/widgets/filter_field.dart';
import '../query_workspace/worksheet_providers.dart';
import 'schema_repository.dart';

part 'schema_providers.g.dart';

/// The schema tree's filter box: whether it's showing, and its text.
///
/// A provider rather than local state because the toggle lives in the section
/// header while the matching happens inside the tree, and those are separate
/// widgets by design (the header is shared across all three sidebar sections).
@riverpod
class SchemaFilter extends _$SchemaFilter {
  @override
  FilterState build() => const FilterState();

  void set(String value) => state = FilterState(open: true, text: value);

  /// Closing clears: a hidden filter that is still narrowing the tree would be
  /// a panel silently lying about how many tables you have.
  void toggle() => state =
      state.open ? const FilterState() : const FilterState(open: true);
}

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
