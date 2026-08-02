import 'package:flutter_test/flutter_test.dart';
import 'package:voltquery/ui/features/search/search_providers.dart';

/// The parts of search that don't need a database.
void main() {
  group('SearchResults', () {
    test('an empty result is empty from both sources', () {
      expect(const SearchResults().isEmpty, isTrue);
      expect(const SearchResults().total, 0);
    });

    test('a schema failure is distinct from no schema matches', () {
      // These look identical in an empty list, and only one of them means the
      // table isn't there — the dialog has to be able to tell them apart.
      const failed = SearchResults(schemaError: 'boom');
      const empty = SearchResults();

      expect(failed.schemaError, isNotNull);
      expect(empty.schemaError, isNull);
      expect(failed.isEmpty, isTrue, reason: 'both render as no rows');
    });
  });

  group('kMinSearchLength', () {
    test('is more than one character', () {
      // One character matches most of a real schema; the floor is what keeps a
      // stray keystroke from becoming a full catalog scan on a server.
      expect(kMinSearchLength, greaterThan(1));
    });
  });
}
