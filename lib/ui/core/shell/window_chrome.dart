import 'dart:io';

import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

/// Whether this platform has an OS window whose chrome we can touch at all.
/// False on mobile and in a plain `flutter test` binary.
bool get _hasDesktopWindow =>
    Platform.isLinux || Platform.isMacOS || Platform.isWindows;

/// Shows or hides the OS window's title bar.
///
/// On Linux the runner installs a `GtkHeaderBar` (`linux/runner/my_application.cc`)
/// and window_manager hides that widget, so this is reversible at runtime — no
/// restart, unlike deciding the decoration at window-creation time.
///
/// Hiding it also removes the only drag handle and close button the OS provides,
/// which is why the app's menu bar becomes a [DragToMoveArea] and File gains a
/// Quit item. On a tiling compositor (Hyprland and friends) none of that is
/// needed — the WM owns the frame — which is the case this setting exists for.
///
/// Best-effort: a platform without the plugin (tests, headless) is a no-op
/// rather than a crash, since a settings toggle must never take the app down.
Future<void> applyTitleBarVisibility(bool visible) async {
  if (!_hasDesktopWindow) return;
  try {
    await windowManager.setTitleBarStyle(
      visible ? TitleBarStyle.normal : TitleBarStyle.hidden,
      windowButtonVisibility: visible,
    );
  } on MissingPluginException {
    return;
  } on PlatformException {
    return;
  }
}

/// Prepares window_manager before `runApp`. Safe to call anywhere.
Future<void> initWindowChrome() async {
  if (!_hasDesktopWindow) return;
  try {
    await windowManager.ensureInitialized();
  } on MissingPluginException {
    return;
  } on PlatformException {
    return;
  }
}
