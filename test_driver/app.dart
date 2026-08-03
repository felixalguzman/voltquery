import 'package:flutter_driver/driver_extension.dart';
import 'package:voltquery/debug/debug_bridge.dart';
import 'package:voltquery/main.dart' as app;

/// The app, with the Flutter Driver extension and the VoltQuery debug bridge
/// switched on.
///
/// A separate entrypoint rather than a flag in `main.dart`: the extension opens
/// a control channel into the running isolate, and that has no business being
/// reachable in a shipped build. Living under `test_driver/` also keeps
/// `flutter_driver` a dev dependency — importing it from `lib/` would drag it
/// into the real dependency graph.
///
/// Run it instead of the normal entrypoint when you want to drive the live app:
///
/// ```bash
/// flutter run -d linux -t test_driver/app.dart
/// ```
void main() {
  enableFlutterDriverExtension();
  // The bridge gets the app's own container, so `ext.voltquery.snapshot`
  // reports the state the user is looking at rather than a parallel copy.
  app.main(onContainerReady: registerDebugExtensions);
}
