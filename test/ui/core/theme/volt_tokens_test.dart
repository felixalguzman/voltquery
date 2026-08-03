import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltquery/ui/core/theme/volt_tokens.dart';

/// The palette, and the rule that keeps it one palette.
void main() {
  test('no widget declares a colour of its own', () {
    // The failure this whole layer exists to stop. There used to be 109 private
    // `const _accent = Color(0xFF2FE6FF)` declarations across 19 files, and
    // three pairs had already drifted — "the error colour" meant one red in the
    // history panel and a different one in the grid. A raw literal outside this
    // file is how that starts again.
    final offenders = <String>[];
    final literal = RegExp(r'Color\(0x[0-9A-Fa-f]{8}\)');

    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      // ui/core/theme is where colour vocabularies live — the palette itself,
      // the SQL type colours, the engine brand colours. Everywhere else, a raw
      // literal is the drift starting again.
      if (file.path.contains('ui/core/theme/')) continue;
      for (final (i, line) in file.readAsLinesSync().indexed) {
        if (literal.hasMatch(line)) {
          offenders.add('${file.path}:${i + 1}  ${line.trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Add the colour to VoltPalette and reference it:\n'
          '${offenders.join('\n')}',
    );
  });

  test('every token is distinct', () {
    // Two tokens with the same value means one of them is not carrying its own
    // meaning, and a theme that changes one will silently change the other.
    const t = VoltTokens.dark;
    final values = [
      t.canvas, t.panel, t.hairline, t.accent, t.accentWash, t.accentTint,
      t.textHigh, t.textMid, t.textLow, t.danger, t.warning, t.success,
      t.violet, t.hover, t.hoverSoft,
    ];
    expect(values.toSet(), hasLength(values.length));
  });

  testWidgets('VoltTheme hands the palette down, and dark is the fallback',
      (tester) async {
    late VoltTokens seen;
    await tester.pumpWidget(
      VoltTheme(
        tokens: VoltTokens.dark,
        child: Builder(builder: (context) {
          seen = VoltTheme.of(context);
          return const SizedBox();
        }),
      ),
    );
    expect(seen, VoltTokens.dark);

    // A panel pumped on its own in a widget test has no VoltTheme above it and
    // must still render rather than assert.
    late VoltTokens bare;
    await tester.pumpWidget(Builder(builder: (context) {
      bare = VoltTheme.of(context);
      return const SizedBox();
    }));
    expect(bare, VoltTokens.dark);
  });

  test('tokens compare by value, so a rebuild is not a theme change', () {
    // `updateShouldNotify` rests on this: an identical palette constructed
    // afresh must not rebuild every widget in the app.
    expect(VoltTokens.dark.copyWith(), VoltTokens.dark);
    expect(
      VoltTokens.dark.copyWith(accent: const Color(0xFF00FF00)),
      isNot(VoltTokens.dark),
    );
  });
}
