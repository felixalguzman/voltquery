import 'package:riverpod/riverpod.dart' show Ref;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/repositories/connection_repository.dart';
import '../../../domain/models/connection.dart';
import '../history/history_providers.dart';

part 'connection_providers.g.dart';

@Riverpod(keepAlive: true)
ConnectionRepository connectionRepository(Ref ref) =>
    ConnectionRepository(ref.watch(localStoreProvider));

/// Reactive list of saved connections (drift `.watch()`).
@riverpod
Stream<List<Connection>> savedConnections(Ref ref) =>
    ref.watch(connectionRepositoryProvider).watchAll();
