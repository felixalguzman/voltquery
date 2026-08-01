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
