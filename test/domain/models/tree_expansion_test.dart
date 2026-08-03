import 'package:flutter_test/flutter_test.dart';
import 'package:voltquery/domain/models/tree_expansion.dart';

/// Remembering which schema-tree nodes were open.
void main() {
  group('paths', () {
    test('segments join and split back', () {
      final path = TreeExpansion.pathOf(['public', 'orders']);
      expect(path, 'public/orders');
      expect(TreeExpansion.segmentsOf(path), ['public', 'orders']);
    });

    test('a name containing a slash is not two levels of tree', () {
      // Legal, rare, and silently corrupting without escaping.
      final path = TreeExpansion.pathOf(['public', 'a/b']);
      expect(TreeExpansion.depthOf(path), 2);
      expect(TreeExpansion.segmentsOf(path), ['public', 'a/b']);
    });

    test('a literal percent survives the escape', () {
      final path = TreeExpansion.pathOf(['public', '100%_done']);
      expect(TreeExpansion.segmentsOf(path), ['public', '100%_done']);
    });
  });

  group('expand and collapse', () {
    test('expanding is idempotent and keeps the order opened', () {
      var e = const TreeExpansion().expand('public');
      e = e.expand('public/orders').expand('public');
      expect(e.paths, ['public', 'public/orders']);
    });

    test('collapsing a node forgets its children too', () {
      // Otherwise the child would silently re-open the parent on restore.
      var e = const TreeExpansion()
          .expand('public')
          .expand('public/orders')
          .expand('public/orders/Indexes')
          .expand('public/customers');
      e = e.collapse('public/orders');
      expect(e.paths, ['public', 'public/customers']);
    });

    test('collapsing a prefix-sharing sibling leaves it alone', () {
      // `public/order` must not take `public/order_items` with it.
      final e = const TreeExpansion()
          .expand('public/order')
          .expand('public/order_items')
          .collapse('public/order');
      expect(e.paths, ['public/order_items']);
    });
  });

  group('restoreOrder', () {
    test('shallow nodes first, so a parent is loaded before its child', () {
      final e = const TreeExpansion()
          .expand('public/orders/Indexes')
          .expand('public')
          .expand('public/orders');
      expect(e.restoreOrder(), [
        'public',
        'public/orders',
        'public/orders/Indexes',
      ]);
    });

    test('a path whose parent is closed is dropped as unreachable', () {
      final e = const TreeExpansion().expand('public/orders/Indexes');
      expect(e.restoreOrder(), isEmpty);
    });

    test('the cap keeps a huge saved state from stalling the tree', () {
      var e = const TreeExpansion();
      for (var i = 0; i < 200; i++) {
        e = e.expand('s$i');
      }
      expect(e.restoreOrder(cap: 50), hasLength(50));
      // Breadth-first means the cap costs depth, not the top of the tree.
      expect(e.restoreOrder(cap: 50).first, 's0');
    });

    test('the default cap is the documented one', () {
      var e = const TreeExpansion();
      for (var i = 0; i < kExpansionRestoreCap + 10; i++) {
        e = e.expand('s$i');
      }
      expect(e.restoreOrder(), hasLength(kExpansionRestoreCap));
    });
  });

  test('prune drops what no longer resolves', () {
    // A dropped table shouldn't be an error on connect, just gone.
    final e = const TreeExpansion()
        .expand('public')
        .expand('public/gone')
        .expand('public/orders');
    expect(e.prune((p) => p != 'public/gone').paths, ['public', 'public/orders']);
  });

  group('encode / decode', () {
    test('round trips', () {
      final e = const TreeExpansion().expand('public').expand('public/orders');
      expect(TreeExpansion.decode(e.encode()), e);
    });

    test('anything unreadable means "nothing was open"', () {
      // Costs one re-expansion; an exception on connect would cost the sidebar.
      for (final raw in [null, '', 'not json', '{"a":1}', '[1, 2, 3]']) {
        expect(TreeExpansion.decode(raw).isEmpty, isTrue, reason: '$raw');
      }
    });

    test('a partly-valid list keeps the strings', () {
      expect(TreeExpansion.decode('["public", 7, "", "public/orders"]').paths,
          ['public', 'public/orders']);
    });
  });
}
