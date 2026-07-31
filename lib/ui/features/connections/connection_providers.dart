import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod/riverpod.dart' show Ref;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/repositories/connection_repository.dart';
import '../../../data/services/secret_store.dart';
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

/// The credentials vault (ADR-0006). Encrypted file in the app-support dir; the
/// derived key lives in memory only, so it starts **locked** each launch.
@Riverpod(keepAlive: true)
Future<SecretStore> secretStore(Ref ref) async {
  final dir = await getApplicationSupportDirectory();
  return VaultSecretStore(
      File(p.join(dir.path, 'VoltQuery', 'credentials.vault')));
}

/// Reactive vault lock state (unlocked?), updated by unlock/lock actions so the
/// UI can show the padlock. Session-scoped.
@riverpod
class VaultLock extends _$VaultLock {
  @override
  bool build() => false;

  void set(bool unlocked) => state = unlocked;
}
