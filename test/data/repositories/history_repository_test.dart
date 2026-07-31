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
}
