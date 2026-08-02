import 'package:flutter_test/flutter_test.dart';
import 'package:voltquery/data/repositories/history_repository.dart';
import 'package:voltquery/data/services/local_store.dart';
import 'package:voltquery/domain/models/history_entry.dart';

/// Seam: HistoryRepository over an in-memory drift LocalStore.
void main() {
  test('recorded entries come back newest-first from watchRecent', () async {
    final db = LocalStore.memory();
    addTearDown(db.close);
    final repo = HistoryRepository(db);

    await repo.record(HistoryEntry(
      connectionName: 'demo',
      engine: 'sqlite',
      sql: 'SELECT 1',
      startedAt: DateTime(2026, 1, 1),
      durationMs: 3,
      status: HistoryStatus.ok,
      rowCount: 1,
    ));
    await repo.record(HistoryEntry(
      connectionName: 'demo',
      engine: 'sqlite',
      sql: 'SELCT bad',
      startedAt: DateTime(2026, 1, 2),
      durationMs: 1,
      status: HistoryStatus.error,
      errorKind: 'syntaxError',
      errorMessage: 'near "SELCT"',
    ));

    final recent = await repo.watchRecent(10).first;

    expect(recent, hasLength(2));
    expect(recent.first.sql, 'SELCT bad'); // newest first
    expect(recent.first.status, HistoryStatus.error);
    expect(recent.first.errorKind, 'syntaxError');
    expect(recent.last.sql, 'SELECT 1');
    expect(recent.last.rowCount, 1);
  });

  /// Source separates what the user typed from what the app composed on their
  /// behalf. It has to survive the round-trip, and rows written before the
  /// column existed have to read as `editor` rather than as null.
  group('source', () {
    test('round-trips each source', () async {
      final db = LocalStore.memory();
      addTearDown(db.close);
      final repo = HistoryRepository(db);

      for (final source in HistorySource.values) {
        await repo.record(HistoryEntry(
          connectionName: 'demo',
          engine: 'sqlite',
          sql: 'SELECT ${source.name}',
          startedAt: DateTime(2026, 1, 1).add(
            Duration(minutes: source.index),
          ),
          durationMs: 1,
          status: HistoryStatus.ok,
          source: source,
        ));
      }

      final all = await repo.watchRecent(10).first;
      expect(
        {for (final e in all) e.sql: e.source},
        {for (final s in HistorySource.values) 'SELECT ${s.name}': s},
      );
    });

    test('defaults to editor when unspecified', () async {
      final db = LocalStore.memory();
      addTearDown(db.close);
      final repo = HistoryRepository(db);

      await repo.record(HistoryEntry(
        connectionName: 'demo',
        engine: 'sqlite',
        sql: 'SELECT 1',
        startedAt: DateTime(2026, 1, 1),
        durationMs: 1,
        status: HistoryStatus.ok,
      ));

      expect((await repo.watchRecent(1).first).single.source,
          HistorySource.editor);
    });

    test('an unknown stored source reads as editor, not a crash', () {
      // A row written by a newer build that added a source this one doesn't
      // know must still list and still be re-runnable.
      expect(HistorySource.byName('somethingNew'), HistorySource.editor);
      expect(HistorySource.byName(null), HistorySource.editor);
    });

    test('only editor entries count as hand-written', () {
      expect(HistorySource.editor.isGenerated, isFalse);
      expect(HistorySource.gridEdit.isGenerated, isTrue);
      expect(HistorySource.tool.isGenerated, isTrue);
    });
  });

  /// Retention is "older than N days AND outside the newest M" — both, never
  /// either. Getting this wrong erases history someone was relying on.
  group('prune', () {
    Future<HistoryRepository> seed(LocalStore db, List<DateTime> at) async {
      final repo = HistoryRepository(db);
      for (final (i, startedAt) in at.indexed) {
        await repo.record(HistoryEntry(
          connectionName: 'demo',
          engine: 'sqlite',
          sql: 'SELECT $i',
          startedAt: startedAt,
          durationMs: 1,
          status: HistoryStatus.ok,
        ));
      }
      return repo;
    }

    test('keeps the newest N even when all of them are old', () async {
      final db = LocalStore.memory();
      addTearDown(db.close);
      final old = DateTime.now().subtract(const Duration(days: 400));
      final repo = await seed(db, [
        old,
        old.add(const Duration(days: 1)),
        old.add(const Duration(days: 2)),
      ]);

      final removed = await repo.prune(keepDays: 30, keepRows: 3);

      expect(removed, 0, reason: 'the count floor protects all three');
      expect(await repo.watchRecent(10).first, hasLength(3));
    });

    test('keeps recent entries even beyond the count floor', () async {
      final db = LocalStore.memory();
      addTearDown(db.close);
      final now = DateTime.now();
      final repo = await seed(db, [
        now.subtract(const Duration(days: 3)),
        now.subtract(const Duration(days: 2)),
        now.subtract(const Duration(days: 1)),
      ]);

      final removed = await repo.prune(keepDays: 90, keepRows: 1);

      expect(removed, 0, reason: 'all three are inside the date window');
      expect(await repo.watchRecent(10).first, hasLength(3));
    });

    test('drops only entries failing both rules', () async {
      final db = LocalStore.memory();
      addTearDown(db.close);
      final now = DateTime.now();
      final repo = await seed(db, [
        now.subtract(const Duration(days: 400)), // old and surplus → goes
        now.subtract(const Duration(days: 300)), // old and surplus → goes
        now.subtract(const Duration(days: 200)), // old but within keepRows
        now.subtract(const Duration(days: 1)), // recent
      ]);

      final removed = await repo.prune(keepDays: 90, keepRows: 2);

      expect(removed, 2);
      final left = await repo.watchRecent(10).first;
      expect(left.map((e) => e.sql), ['SELECT 3', 'SELECT 2']);
    });

    test('is a no-op on a store smaller than the count floor', () async {
      final db = LocalStore.memory();
      addTearDown(db.close);
      final repo = await seed(db, [DateTime(2000)]);

      expect(await repo.prune(keepDays: 1, keepRows: 50), 0);
      expect(await repo.watchRecent(10).first, hasLength(1));
    });
  });
}
