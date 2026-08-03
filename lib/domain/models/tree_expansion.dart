import 'dart:convert';

/// Which schema-tree nodes were open, as **paths** rather than node identities.
///
/// A path is what survives: the tree is lazy, so the objects it was built from
/// are gone by the next launch, and a node's position shifts the moment someone
/// adds a table. `public/orders` still means the same thing tomorrow — and if
/// the table is dropped, it simply stops resolving and is pruned, which is the
/// behaviour you want anyway.
///
/// Segments are the node labels from the root down:
/// `public` · `public/orders` · `public/orders/Indexes`. Engines without a
/// schema level (SQLite, MySQL) start at the object: `orders`.
class TreeExpansion {
  const TreeExpansion([this.paths = const []]);

  /// Expanded paths, in the order they were opened.
  final List<String> paths;

  bool get isEmpty => paths.isEmpty;
  int get length => paths.length;

  bool contains(String path) => paths.contains(path);

  /// A path from its segments, escaping any `/` inside a name.
  ///
  /// Table names containing a slash are rare and legal; without escaping, one
  /// would silently read back as two levels of tree.
  static String pathOf(Iterable<String> segments) =>
      segments.map((s) => s.replaceAll('%', '%25').replaceAll('/', '%2F')).join('/');

  /// The inverse of [pathOf].
  static List<String> segmentsOf(String path) => path
      .split('/')
      .map((s) => s.replaceAll('%2F', '/').replaceAll('%25', '%'))
      .toList();

  /// How deep a path sits. Shallower nodes must be restored first — a child
  /// cannot be expanded before its parent has loaded.
  static int depthOf(String path) => path.split('/').length;

  TreeExpansion expand(String path) =>
      contains(path) ? this : TreeExpansion([...paths, path]);

  /// Collapsing a node also forgets everything under it: those children are
  /// about to be unreachable, and remembering them would silently re-open the
  /// parent on the next restore.
  TreeExpansion collapse(String path) => TreeExpansion([
        for (final p in paths)
          if (p != path && !p.startsWith('$path/')) p,
      ]);

  /// The order to restore in: **breadth-first**, capped.
  ///
  /// Breadth-first because each expansion is a catalog round trip, so restoring
  /// a deep branch before a shallow one leaves the top of the tree empty for
  /// longer. Capped because a saved state of five hundred nodes would stall the
  /// tree behind a burst of queries on every connect — degrading to "most of
  /// it" beats a sidebar that hangs.
  ///
  /// A path whose parent isn't also expanded is dropped: it could never be
  /// reached, so asking for it would only cost a failed lookup.
  List<String> restoreOrder({int cap = kExpansionRestoreCap}) {
    final open = paths.toSet();
    final reachable = [
      for (final (i, p) in paths.indexed)
        if (_parentPresent(p, open)) (i, p),
    ]..sort((a, b) {
        final byDepth = depthOf(a.$2).compareTo(depthOf(b.$2));
        // Dart's sort is not stable, so the tiebreak is explicit: within a
        // depth, restore in the order the user opened them. Without it the cap
        // would drop an arbitrary subset rather than the most recent.
        return byDepth != 0 ? byDepth : a.$1.compareTo(b.$1);
      });
    return [for (final (_, p) in reachable.take(cap)) p];
  }

  static bool _parentPresent(String path, Set<String> open) {
    final cut = path.lastIndexOf('/');
    return cut < 0 || open.contains(path.substring(0, cut));
  }

  /// Drops everything that no longer resolves. [exists] is asked once per path.
  TreeExpansion prune(bool Function(String path) exists) =>
      TreeExpansion([for (final p in paths) if (exists(p)) p]);

  String encode() => jsonEncode(paths);

  /// Tolerant: anything unparseable reads as "nothing was open", which costs a
  /// user one re-expansion rather than an error on connect.
  static TreeExpansion decode(String? raw) {
    if (raw == null || raw.isEmpty) return const TreeExpansion();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const TreeExpansion();
      return TreeExpansion([
        for (final e in decoded)
          if (e is String && e.isNotEmpty) e,
      ]);
    } catch (_) {
      return const TreeExpansion();
    }
  }

  @override
  bool operator ==(Object other) =>
      other is TreeExpansion &&
      other.paths.length == paths.length &&
      List.generate(paths.length, (i) => other.paths[i] == paths[i])
          .every((e) => e);

  @override
  int get hashCode => Object.hashAll(paths);

  @override
  String toString() => 'TreeExpansion(${paths.join(', ')})';
}

/// How many nodes a restore will re-open before giving up.
///
/// Each one is a catalog round trip. Fifty is generous for a tree someone
/// actually navigates and small enough that a pathological saved state can't
/// hold the sidebar hostage.
const int kExpansionRestoreCap = 50;
