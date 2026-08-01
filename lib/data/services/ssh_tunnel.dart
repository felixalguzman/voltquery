import 'dart:async';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';

import '../../domain/drivers/driver_error.dart';
import '../../domain/models/ssh_config.dart';

/// A live local port-forward over SSH.
///
/// Listens on loopback, and carries anything written there over the SSH
/// connection to the target as seen *from the bastion*. The database driver
/// connects to [localPort] and needs to know nothing about the tunnel.
class SshTunnel {
  SshTunnel._(this._client, this._server, this.localPort, this._subscription);

  final SSHClient _client;
  final ServerSocket _server;
  final StreamSubscription<Socket> _subscription;

  /// The loopback port to point the driver at.
  final int localPort;

  var _closed = false;

  /// Opens a tunnel forwarding a fresh local port to [targetHost]:[targetPort].
  ///
  /// [password] / [passphrase] come from the vault at call time and are never
  /// held on the config (ADR-0006).
  static Future<SshTunnel> open({
    required SshConfig config,
    required String targetHost,
    required int targetPort,
    String? password,
    String? passphrase,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    SSHClient? client;
    ServerSocket? server;
    try {
      final socket = await SSHSocket.connect(config.host, config.port,
          timeout: timeout);

      client = SSHClient(
        socket,
        username: config.username,
        onPasswordRequest: () => password ?? '',
        identities: await _identities(config, passphrase),
      );
      await client.authenticated;

      // Port 0 → the OS picks a free port, which avoids racing another tunnel
      // (or another application) for a hardcoded one.
      server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);

      final subscription = server.listen((local) async {
        try {
          final forward = await client!.forwardLocal(targetHost, targetPort);
          // Pump both ways; when either side ends, tear the pair down.
          unawaited(local.addStream(forward.stream).whenComplete(() async {
            await local.close();
          }).catchError((_) {}));
          unawaited(forward.sink
              .addStream(local)
              .whenComplete(() => forward.sink.close())
              .catchError((_) {}));
        } catch (_) {
          // One failed forward must not kill the listener — the driver may
          // simply retry, and an exception here would take the tunnel with it.
          await local.close().catchError((_) {});
        }
      });

      return SshTunnel._(client, server, server.port, subscription);
    } catch (e) {
      // Partial setup must not leak a socket or an authenticated session.
      await server?.close();
      client?.close();
      throw DriverError(
        DriverErrorKind.connectionFailed,
        'SSH tunnel to ${config.host}:${config.port} failed: $e',
        cause: e,
      );
    }
  }

  static Future<List<SSHKeyPair>> _identities(
      SshConfig config, String? passphrase) async {
    if (config.authMode != SshAuthMode.privateKey) return const [];
    final path = config.privateKeyPath;
    if (path == null || path.isEmpty) {
      throw const FormatException('No private key file was configured.');
    }
    final pem = await File(path).readAsString();
    return SSHKeyPair.fromPem(pem, passphrase);
  }

  /// Idempotent: a session may close a tunnel that a failed connect already
  /// tore down.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _subscription.cancel();
    await _server.close();
    _client.close();
  }
}
