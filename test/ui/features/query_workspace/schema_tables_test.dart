import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltquery/ui/features/query_workspace/worksheet_providers.dart';

/// Seam: schemaTablesProvider introspects the active session's tables — the
/// data behind the schema sidebar.
void main() {
  test('lists the tables of the active (demo) session', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final tables = await container.read(schemaTablesProvider.future);

    expect(tables.map((t) => t.name), contains('customers'));
  });
}
