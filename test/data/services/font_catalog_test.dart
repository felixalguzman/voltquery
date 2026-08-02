import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voltquery/data/services/font_catalog.dart';

/// The font picker is only as good as this list, but a machine without
/// fontconfig must still get a usable field rather than an empty dropdown.
void main() {
  test('always offers the generic family first', () async {
    final families = await const FontCatalog().monospaceFamilies();

    expect(families, isNotEmpty);
    expect(families.first, FontCatalog.generic);
  });

  test('entries are unique and sorted after the generic', () async {
    final families = await const FontCatalog().monospaceFamilies();
    final rest = families.skip(1).toList();

    expect(rest.toSet(), hasLength(rest.length), reason: 'no duplicates');
    final sorted = [...rest]
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    expect(rest, sorted);
  });

  test('falls back to a usable list where fontconfig is absent', () async {
    // Only Linux is enumerated; everywhere else must still return choices.
    final families = await const FontCatalog().monospaceFamilies();
    expect(families.length, greaterThan(1));
  }, skip: Platform.isLinux ? 'covered by the live fontconfig path' : null);

  test('fc-list aliases collapse to the first (full) family name', () {
    // `fc-list` prints `Full Name,Abbrev,Abbrev Weight` per line, one line per
    // face — so a family with eight weights must still appear once.
    final parsed = FontCatalog.debugParse(
      'JetBrainsMono Nerd Font,JetBrainsMono NF,JetBrainsMono NF Medium\n'
      'JetBrainsMono Nerd Font,JetBrainsMono NF,JetBrainsMono NF Bold\n'
      'Adwaita Mono\n'
      '\n',
    );

    expect(parsed, ['JetBrainsMono Nerd Font', 'Adwaita Mono']);
  });
}
