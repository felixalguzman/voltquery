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

  test('the light palette is not the dark one inverted', () {
    const d = VoltTokens.dark;
    const l = VoltTokens.light;

    // Surfaces flip, which is the easy half.
    expect(l.canvas.computeLuminance(), greaterThan(d.canvas.computeLuminance()));
    expect(l.textHigh.computeLuminance(), lessThan(d.textHigh.computeLuminance()));

    // The half that gets forgotten: an accent tuned to glow on near-black is
    // nearly invisible on white, and a hover that lightens has to darken.
    expect(l.accent, isNot(d.accent));
    expect(l.accent.computeLuminance(), lessThan(d.accent.computeLuminance()));
    expect(l.hover.computeLuminance(), lessThan(d.hover.computeLuminance()));

    // Every state colour is restated rather than reused.
    for (final (name, dv, lv) in [
      ('danger', d.danger, l.danger),
      ('warning', d.warning, l.warning),
      ('success', d.success, l.success),
      ('violet', d.violet, l.violet),
    ]) {
      expect(lv, isNot(dv), reason: '$name was carried over unchanged');
    }
  });

  test('body text has usable contrast on its own surface', () {
    // The reason a light theme is more than swapping two colours. WCAG AA for
    // body text is 4.5:1; this checks the pairs that carry actual content.
    double ratio(Color fg, Color bg) {
      final a = fg.computeLuminance(), b = bg.computeLuminance();
      final (hi, lo) = a > b ? (a, b) : (b, a);
      return (hi + 0.05) / (lo + 0.05);
    }

    for (final (name, tokens) in [
      ('dark', VoltTokens.dark),
      ('light', VoltTokens.light),
    ]) {
      expect(ratio(tokens.textHigh, tokens.panel), greaterThan(4.5),
          reason: '$name: primary text on a panel');
      expect(ratio(tokens.textHigh, tokens.canvas), greaterThan(4.5),
          reason: '$name: primary text on the canvas');
      // Secondary text is smaller in practice but still read, not scanned.
      expect(ratio(tokens.textMid, tokens.panel), greaterThan(3.0),
          reason: '$name: secondary text on a panel');
    }
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
