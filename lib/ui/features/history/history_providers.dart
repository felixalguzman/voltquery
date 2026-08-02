import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/repositories/history_repository.dart';
import '../../../data/services/local_store.dart';
import '../../../domain/models/history_entry.dart';

part 'history_providers.g.dart';

/// The app's drift store — one instance for the app's lifetime.
@Riverpod(keepAlive: true)
LocalStore localStore(Ref ref) {
  final store = LocalStore();
  ref.onDispose(store.close);
  return store;
}

@Riverpod(keepAlive: true)
HistoryRepository historyRepository(Ref ref) =>
    HistoryRepository(ref.watch(localStoreProvider));

/// Reactive recent query history for the sidebar (drift `.watch()`).
@riverpod
Stream<List<HistoryEntry>> recentHistory(Ref ref) =>
    ref.watch(historyRepositoryProvider).watchRecent(50);

/// Whether the panel hides statements the app composed (grid edits, Table
/// Info's exact `count(*)`) rather than ones the user typed.
///
/// Session-scoped, and **off** by default: showing everything that actually ran
/// against the database is the honest default, and a filter you have to turn on
/// can't quietly hide a destructive UPDATE from you.
@riverpod
class HideGeneratedHistory extends _$HideGeneratedHistory {
  @override
  bool build() => false;

  void toggle() => state = !state;
}
