import 'dart:io';

import 'package:flutter/foundation.dart';

/// The monospace font families installed on this machine, for the editor's
/// font-family picker.
///
/// Flutter exposes no API for enumerating system fonts — it hands a family name
/// to the platform's font manager and takes what it gets — so this asks the
/// platform directly. Only Linux has a reliable, fast answer (`fontconfig`,
/// which is the same thing resolving the app's fonts underneath); elsewhere
/// this falls back to [_commonMonospace] and typing a family name by hand still
/// works, since the field was never restricted to the list.
class FontCatalog {
  const FontCatalog();

  /// The generic family Flutter/fontconfig resolves to the system default.
  /// Always offered first so "put it back" is one click.
  static const generic = 'monospace';

  /// Ships-with-something families people actually have. Not a guess at what is
  /// installed — just a starting point where we can't enumerate.
  static const _commonMonospace = [
    'Cascadia Code',
    'Consolas',
    'Courier New',
    'DejaVu Sans Mono',
    'Fira Code',
    'IBM Plex Mono',
    'JetBrains Mono',
    'Liberation Mono',
    'Menlo',
    'Monaco',
    'Noto Sans Mono',
    'Roboto Mono',
    'SF Mono',
    'Source Code Pro',
    'Ubuntu Mono',
  ];

  Future<List<String>> monospaceFamilies() async {
    final found = Platform.isLinux ? await _fontconfig() : const <String>[];
    final families = <String>{
      generic,
      ...(found.isEmpty ? _commonMonospace : found),
    };
    final sorted = families.where((f) => f != generic).toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return [generic, ...sorted];
  }

  /// `spacing=100` is fontconfig's MONO — the same filter a terminal emulator
  /// uses to build its font list, so what shows up here is what a code editor
  /// should be offering.
  Future<List<String>> _fontconfig() async {
    try {
      final result = await Process.run('fc-list', [':spacing=100', 'family']);
      if (result.exitCode != 0) return const [];
      return _parse('${result.stdout}');
    } on ProcessException {
      // No fontconfig (a stripped container, a non-glibc distro). Not an error
      // worth surfacing — the field still accepts a typed name.
      return const [];
    }
  }

  /// fc-list prints one font per line as comma-separated aliases
  /// (`JetBrainsMono Nerd Font,JetBrainsMono NF,…`). The first is the full
  /// family name; the rest are abbreviations that would just clutter the list.
  ///
  /// Weight and style variants ("… Heavy Obl") arrive as separate lines of the
  /// same family, so this dedupes — a picker offering "Iosevka NFM Thin" and
  /// "Iosevka NFM Heavy Obl" as separate choices is noise, since the editor
  /// asks for a family and lets the font manager pick the face.
  @visibleForTesting
  static List<String> debugParse(String stdout) => _parse(stdout);

  static List<String> _parse(String stdout) {
    final families = <String>{};
    for (final line in stdout.split('\n')) {
      final first = line.split(',').first.trim();
      if (first.isEmpty) continue;
      families.add(first);
    }
    return families.toList();
  }
}
