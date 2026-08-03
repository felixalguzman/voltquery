import 'package:flutter/widgets.dart';

/// The app's colour vocabulary, in one place.
///
/// Every widget used to declare its own `const _accent = Color(0xFF2FE6FF)` at
/// the top of the file — 109 of them across 19 files. That is not just
/// repetition: three pairs had already drifted apart (two reds, two greens, two
/// ambers), so "the error colour" meant one thing in the history panel and
/// another in the grid. Naming them once makes that impossible.
///
/// Tokens are **semantic**, not literal — [danger], not `red`. That is what
/// lets a second palette exist at all: a light theme has no use for a token
/// called `darkGrey`, but it very much has a `panel`.
///
/// Read it with `VoltTheme.of(context)`.
@immutable
class VoltTokens {
  const VoltTokens({
    required this.canvas,
    required this.panel,
    required this.hairline,
    required this.accent,
    required this.accentWash,
    required this.accentTint,
    required this.textHigh,
    required this.textMid,
    required this.textLow,
    required this.danger,
    required this.warning,
    required this.success,
    required this.violet,
    required this.hover,
    required this.hoverSoft,
  });

  /// The deepest surface — the window background, and the well that panels sit
  /// in. Nothing is behind this.
  final Color canvas;

  /// A raised surface: the grid, a dialog body, a toolbar.
  final Color panel;

  /// Borders and dividers. Deliberately one colour: a border that varies by
  /// context is how a UI starts looking accidental.
  final Color hairline;

  /// The one colour that means "this is the thing" — selection, focus, the
  /// primary action, an active filter.
  final Color accent;

  /// [accent] at low opacity, for a selected row's background.
  final Color accentWash;

  /// [accent] at very low opacity, for a hover or a subtle fill.
  final Color accentTint;

  /// Primary text: values, names, anything being read rather than scanned.
  final Color textHigh;

  /// Secondary text: labels, counts, metadata beside the thing itself.
  final Color textMid;

  /// Tertiary text: hints, placeholders, NULL, disabled.
  final Color textLow;

  /// Failure, destruction, a row about to be deleted.
  final Color danger;

  /// Caution and pending change — a staged edit, a partial export, an
  /// unverified host.
  final Color warning;

  /// Success, and a row about to be added.
  final Color success;

  /// Relationships: foreign keys, JSON, the things that point elsewhere.
  final Color violet;

  /// Neutral hover fill over any surface.
  final Color hover;

  /// A lighter [hover], for rows where the full strength is too loud.
  final Color hoverSoft;

  /// The shipped palette: "Clean Dev-Tool" — near-black surfaces, cyan accent.
  static const dark = VoltTokens(
    canvas: VoltPalette.canvas,
    panel: VoltPalette.panel,
    hairline: VoltPalette.hairline,
    accent: VoltPalette.accent,
    accentWash: VoltPalette.accentWash,
    accentTint: VoltPalette.accentTint,
    textHigh: VoltPalette.textHigh,
    textMid: VoltPalette.textMid,
    textLow: VoltPalette.textLow,
    danger: VoltPalette.danger,
    warning: VoltPalette.warning,
    success: VoltPalette.success,
    violet: VoltPalette.violet,
    hover: VoltPalette.hover,
    hoverSoft: VoltPalette.hoverSoft,
  );

  /// By value, so [VoltTheme.updateShouldNotify] doesn't rebuild the whole app
  /// every time a rebuild happens to construct an equivalent palette.
  @override
  bool operator ==(Object other) =>
      other is VoltTokens &&
      other.canvas == canvas &&
      other.panel == panel &&
      other.hairline == hairline &&
      other.accent == accent &&
      other.accentWash == accentWash &&
      other.accentTint == accentTint &&
      other.textHigh == textHigh &&
      other.textMid == textMid &&
      other.textLow == textLow &&
      other.danger == danger &&
      other.warning == warning &&
      other.success == success &&
      other.violet == violet &&
      other.hover == hover &&
      other.hoverSoft == hoverSoft;

  @override
  int get hashCode => Object.hashAll([
        canvas, panel, hairline, accent, accentWash, accentTint,
        textHigh, textMid, textLow, danger, warning, success, violet,
        hover, hoverSoft,
      ]);

  VoltTokens copyWith({
    Color? canvas,
    Color? panel,
    Color? hairline,
    Color? accent,
    Color? accentWash,
    Color? accentTint,
    Color? textHigh,
    Color? textMid,
    Color? textLow,
    Color? danger,
    Color? warning,
    Color? success,
    Color? violet,
    Color? hover,
    Color? hoverSoft,
  }) =>
      VoltTokens(
        canvas: canvas ?? this.canvas,
        panel: panel ?? this.panel,
        hairline: hairline ?? this.hairline,
        accent: accent ?? this.accent,
        accentWash: accentWash ?? this.accentWash,
        accentTint: accentTint ?? this.accentTint,
        textHigh: textHigh ?? this.textHigh,
        textMid: textMid ?? this.textMid,
        textLow: textLow ?? this.textLow,
        danger: danger ?? this.danger,
        warning: warning ?? this.warning,
        success: success ?? this.success,
        violet: violet ?? this.violet,
        hover: hover ?? this.hover,
        hoverSoft: hoverSoft ?? this.hoverSoft,
      );
}

/// The dark palette as compile-time constants.
///
/// [VoltTokens.dark] is the same colours, but a field read on a const object is
/// not itself a constant expression in Dart — so a widget that wants
/// `const Icon(..., color: ...)` cannot reach them through it. This holder can
/// be reached, which is what lets every widget drop its private copy of the hex
/// *without* losing a single `const`.
///
/// It is deliberately the narrower door: a value read from here cannot change
/// at runtime. Widgets that need to follow a theme switch read [VoltTheme.of]
/// instead and give up `const` in exchange.
abstract final class VoltPalette {
  static const canvas = Color(0xFF0D0E11);
  static const panel = Color(0xFF16181D);
  static const hairline = Color(0xFF262A31);
  static const accent = Color(0xFF2FE6FF);
  static const accentWash = Color(0x222FE6FF);
  static const accentTint = Color(0x142FE6FF);
  static const textHigh = Color(0xFFE6E8EC);
  static const textMid = Color(0xFF9BA1AD);
  static const textLow = Color(0xFF5A6069);
  static const danger = Color(0xFFFF6B6B);
  static const warning = Color(0xFFE8B84B);
  static const success = Color(0xFF6FE39A);
  static const violet = Color(0xFFB98CFF);
  static const hover = Color(0x14FFFFFF);
  static const hoverSoft = Color(0x0FFFFFFF);

  /// A selected row's fill — distinct from [accentWash], which tints; this one
  /// replaces the surface.
  static const selected = Color(0xFF1E2A30);

  /// A surface one step off [panel]: a sticky header, a nested strip.
  static const panelAlt = Color(0xFF1B1E24);

  /// A neutral chip or pill behind small text.
  static const chip = Color(0xFF3A3F47);

  /// Drop shadow under a floating surface (menus, flyouts).
  static const shadow = Color(0x66000000);
}

/// Makes [VoltTokens] available to the widget tree.
///
/// An [InheritedWidget] rather than a global constant precisely so the palette
/// can change at runtime: everything that reads it rebuilds when it does, which
/// is the whole prerequisite for a theme setting.
class VoltTheme extends InheritedWidget {
  const VoltTheme({super.key, required this.tokens, required super.child});

  final VoltTokens tokens;

  /// The palette in scope. Falls back to [VoltTokens.dark] when no [VoltTheme]
  /// is above — a widget test that pumps one panel in isolation should render,
  /// not assert.
  static VoltTokens of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<VoltTheme>()?.tokens ??
      VoltTokens.dark;

  @override
  bool updateShouldNotify(VoltTheme oldWidget) => tokens != oldWidget.tokens;
}
