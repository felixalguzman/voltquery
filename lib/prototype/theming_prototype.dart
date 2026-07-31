// PROTOTYPE — THROWAWAY. Resolves wayfinder ticket #7
// "Theming tokens & futuristic design language (mix)".
//
// Question: what is the concrete futuristic design language (palette, spacing,
// radii, glass/acrylic) for VoltQuery? This screen renders THREE radically
// different design languages over one composite panel (rail + connection form
// + result grid + status bar + SQL snippet) so the human can react and pick —
// or steal bits across variants.
//
// Run:  flutter run -t lib/prototype/theming_prototype.dart -d linux
// Cycle variants: floating bottom bar, or ← / → arrow keys.
//
// NOTE ON MECHANISM: tokens here are plain Dart consts for speed. The LOCKED
// stack applies them via mix (Style/tokens) layered on a fluent_ui
// FluentThemeData. The prototype answers the VALUE question (which palette/
// radii/density), not the mechanism question (mix — already decided).

import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const PrototypeApp());

// ---------------------------------------------------------------------------
// TOKEN MODEL
// ---------------------------------------------------------------------------

class DesignTokens {
  final String key; // 'A' / 'B' / 'C'
  final String name;
  final String tagline;

  // surfaces
  final Color bg; // scaffold / deepest
  final Color surface; // panel
  final Color surfaceAlt; // rail / header strip
  final Color border;

  // text
  final Color textHi;
  final Color textMid;
  final Color textLo;

  // accent
  final Color accent;
  final Color accent2; // secondary neon / gradient partner
  final Color onAccent;
  final double glow; // 0 = flat, >0 = glow blur radius on accented things

  // shape & rhythm
  final double radius; // main panel/control radius
  final double radiusSm;
  final double unit; // spacing base (density); smaller = denser
  final double controlH; // input/button height

  // glass
  final bool glass;
  final double blur;
  final double panelOpacity; // 0..1 opacity of surface over bg

  // type
  final String? sansFamily; // null = platform default
  final bool monoUi; // whole UI in monospace (terminal feel)
  final double letterSpacing;

  // syntax (SQL snippet)
  final Color synKeyword;
  final Color synString;
  final Color synNumber;
  final Color synIdent;

  const DesignTokens({
    required this.key,
    required this.name,
    required this.tagline,
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.textHi,
    required this.textMid,
    required this.textLo,
    required this.accent,
    required this.accent2,
    required this.onAccent,
    required this.glow,
    required this.radius,
    required this.radiusSm,
    required this.unit,
    required this.controlH,
    required this.glass,
    required this.blur,
    required this.panelOpacity,
    required this.sansFamily,
    required this.monoUi,
    required this.letterSpacing,
    required this.synKeyword,
    required this.synString,
    required this.synNumber,
    required this.synIdent,
  });

  String get mono => 'monospace';
}

// ---------------------------------------------------------------------------
// VARIANT A — "Deep Space Neon"
// Near-black navy, electric-cyan accent, real glow, glass panels, medium radii.
// The archetypal sci-fi console. Accent used loudly.
// ---------------------------------------------------------------------------
const tokensA = DesignTokens(
  key: 'A',
  name: 'Deep Space Neon',
  tagline: 'navy void · cyan glow · glass panels',
  bg: Color(0xFF060912),
  surface: Color(0xFF0E1626),
  surfaceAlt: Color(0xFF0A1120),
  border: Color(0xFF1E2C44),
  textHi: Color(0xFFEAF2FF),
  textMid: Color(0xFF9DB2CE),
  textLo: Color(0xFF5C7192),
  accent: Color(0xFF2FE6FF),
  accent2: Color(0xFF6C5CFF),
  onAccent: Color(0xFF041018),
  glow: 16,
  radius: 12,
  radiusSm: 8,
  unit: 8,
  controlH: 38,
  glass: true,
  blur: 18,
  panelOpacity: 0.72,
  sansFamily: null,
  monoUi: false,
  letterSpacing: 0.2,
  synKeyword: Color(0xFF2FE6FF),
  synString: Color(0xFF6FE39A),
  synNumber: Color(0xFFFFB86C),
  synIdent: Color(0xFFEAF2FF),
);

// ---------------------------------------------------------------------------
// VARIANT B — "Synthwave Terminal"
// Pure black, magenta+amber, sharp corners, monospace everywhere, dense,
// scanline/grid texture. High contrast hacker console. Radii near-zero.
// ---------------------------------------------------------------------------
const tokensB = DesignTokens(
  key: 'B',
  name: 'Synthwave Terminal',
  tagline: 'true black · magenta+amber · mono · sharp',
  bg: Color(0xFF000000),
  surface: Color(0xFF0B0710),
  surfaceAlt: Color(0xFF120A18),
  border: Color(0xFF32213E),
  textHi: Color(0xFFF6E9FF),
  textMid: Color(0xFFB58FD0),
  textLo: Color(0xFF6E5385),
  accent: Color(0xFFFF3DAE),
  accent2: Color(0xFFFFC24B),
  onAccent: Color(0xFF17020E),
  glow: 10,
  radius: 2,
  radiusSm: 1,
  unit: 6,
  controlH: 32,
  glass: false,
  blur: 0,
  panelOpacity: 1.0,
  sansFamily: 'monospace',
  monoUi: true,
  letterSpacing: 0.4,
  synKeyword: Color(0xFFFF3DAE),
  synString: Color(0xFFFFC24B),
  synNumber: Color(0xFF6FE3D2),
  synIdent: Color(0xFFF6E9FF),
);

// ---------------------------------------------------------------------------
// VARIANT C — "Frosted Graphite"
// Soft graphite greys, ONE restrained teal accent, big radii, heavy frosted
// glass, airy spacing. Calm pro-tool futurism (Linear / Raycast lineage).
// ---------------------------------------------------------------------------
const tokensC = DesignTokens(
  key: 'C',
  name: 'Frosted Graphite',
  tagline: 'graphite · single teal · airy · frosted',
  bg: Color(0xFF17181C),
  surface: Color(0xFF212329),
  surfaceAlt: Color(0xFF1B1D22),
  border: Color(0xFF34363E),
  textHi: Color(0xFFF3F4F6),
  textMid: Color(0xFFA9ADB6),
  textLo: Color(0xFF6B6F79),
  accent: Color(0xFF34E0C4),
  accent2: Color(0xFF34E0C4),
  onAccent: Color(0xFF04130F),
  glow: 0,
  radius: 16,
  radiusSm: 10,
  unit: 11,
  controlH: 42,
  glass: true,
  blur: 30,
  panelOpacity: 0.66,
  sansFamily: null,
  monoUi: false,
  letterSpacing: 0.0,
  synKeyword: Color(0xFF34E0C4),
  synString: Color(0xFFC3E88D),
  synNumber: Color(0xFFF78C6C),
  synIdent: Color(0xFFF3F4F6),
);

// ---------------------------------------------------------------------------
// VARIANT D — "Clean Dev-Tool"  (round 2 — the converged direction)
// Neutral near-black surfaces, ONE cyan accent (no glow), flat (no glass),
// sharp 4px corners (from B), A's SQL syntax palette. VS Code / Geist lineage.
// ---------------------------------------------------------------------------
const tokensD = DesignTokens(
  key: 'D',
  name: 'Clean Dev-Tool',
  tagline: 'neutral near-black · one cyan accent · flat · sharp',
  bg: Color(0xFF0D0E11),
  surface: Color(0xFF16181D),
  surfaceAlt: Color(0xFF111318),
  border: Color(0xFF262A31),
  textHi: Color(0xFFE6E8EC),
  textMid: Color(0xFF9AA1AD),
  textLo: Color(0xFF5C636E),
  accent: Color(0xFF2FE6FF), // A's cyan
  accent2: Color(0xFF2FE6FF), // no gradient partner — flat single accent
  onAccent: Color(0xFF04121A),
  glow: 0, // flat — no bloom
  radius: 4, // sharp (from B)
  radiusSm: 3,
  unit: 9,
  controlH: 36,
  glass: false, // flat surfaces
  blur: 0,
  panelOpacity: 1.0,
  sansFamily: null,
  monoUi: false,
  letterSpacing: 0.0,
  synKeyword: Color(0xFF2FE6FF), // A's SQL palette (kept verbatim)
  synString: Color(0xFF6FE39A),
  synNumber: Color(0xFFFFB86C),
  synIdent: Color(0xFFE6E8EC),
);

// D first = default & the current proposal; A/B/C stay reachable for compare.
const variants = <DesignTokens>[tokensD, tokensA, tokensB, tokensC];

// ---------------------------------------------------------------------------
// APP + SWITCHER
// ---------------------------------------------------------------------------

class PrototypeApp extends StatefulWidget {
  const PrototypeApp({super.key});
  @override
  State<PrototypeApp> createState() => _PrototypeAppState();
}

class _PrototypeAppState extends State<PrototypeApp> {
  // VQ_VARIANT env picks the initial variant (used by the screenshot capture).
  int i = (int.tryParse(Platform.environment['VQ_VARIANT'] ?? '') ?? 0)
      .clamp(0, variants.length - 1);
  final _focus = FocusNode();

  void _cycle(int d) => setState(() => i = (i + d) % variants.length);

  @override
  Widget build(BuildContext context) {
    final t = variants[i];
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'VoltQuery — theming prototype',
      home: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: (node, e) {
          if (e is KeyDownEvent) {
            if (e.logicalKey == LogicalKeyboardKey.arrowRight) {
              _cycle(1);
              return KeyEventResult.handled;
            }
            if (e.logicalKey == LogicalKeyboardKey.arrowLeft) {
              _cycle(-1);
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: Scaffold(
          backgroundColor: t.bg,
          body: Stack(
            children: [
              Positioned.fill(child: _Backdrop(t: t)),
              Positioned.fill(child: MockShell(t: t)),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: _Switcher(t: t, onPrev: () => _cycle(-1), onNext: () => _cycle(1)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// subtle background texture so glass has something to blur
class _Backdrop extends StatelessWidget {
  final DesignTokens t;
  const _Backdrop({required this.t});
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.7, -0.9),
          radius: 1.4,
          colors: [
            Color.alphaBlend(t.accent.withValues(alpha: 0.10), t.bg),
            t.bg,
          ],
        ),
      ),
      child: t.key == 'B'
          ? CustomPaint(painter: _GridPainter(t.border.withValues(alpha: 0.5)))
          : const SizedBox.expand(),
    );
  }
}

class _GridPainter extends CustomPainter {
  final Color c;
  _GridPainter(this.c);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = c
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 28) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) => old.c != c;
}

class _Switcher extends StatelessWidget {
  final DesignTokens t;
  final VoidCallback onPrev, onNext;
  const _Switcher({required this.t, required this.onPrev, required this.onNext});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F3F5),
          borderRadius: BorderRadius.circular(999),
          boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 24, offset: Offset(0, 8))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left), color: Colors.black87),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text('${t.key} — ${t.name}',
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
            IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right), color: Colors.black87),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// MOCK SHELL — the composite styled panel
// ---------------------------------------------------------------------------

class MockShell extends StatelessWidget {
  final DesignTokens t;
  const MockShell({super.key, required this.t});

  TextStyle _sans(double size, Color c, [FontWeight w = FontWeight.w400]) => TextStyle(
        fontFamily: t.sansFamily,
        fontSize: size,
        color: c,
        fontWeight: w,
        letterSpacing: t.letterSpacing,
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _titleBar(),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _rail(),
              Expanded(child: _main()),
            ],
          ),
        ),
        _statusBar(),
      ],
    );
  }

  Widget _titleBar() => Container(
        height: 40,
        color: t.surfaceAlt,
        padding: EdgeInsets.symmetric(horizontal: t.unit * 1.5),
        child: Row(children: [
          _dot(t.accent), const SizedBox(width: 6), _dot(t.textLo), const SizedBox(width: 6), _dot(t.textLo),
          SizedBox(width: t.unit * 2),
          Text('VoltQuery', style: _sans(13, t.textHi, FontWeight.w700)),
          SizedBox(width: t.unit),
          Text('· prototype', style: _sans(12, t.textLo)),
          const Spacer(),
          Text('File   Edit   View   Query', style: _sans(12, t.textMid)),
        ]),
      );

  Widget _dot(Color c) => Container(width: 11, height: 11, decoration: BoxDecoration(color: c, shape: BoxShape.circle));

  Widget _rail() => Container(
        width: 232,
        color: t.surfaceAlt,
        padding: EdgeInsets.all(t.unit * 1.5),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('CONNECTIONS', style: _sans(10, t.textLo, FontWeight.w700)),
          SizedBox(height: t.unit),
          _connRow('prod-postgres', 'PostgreSQL', active: true),
          _connRow('analytics', 'MySQL'),
          _connRow('cache.sqlite', 'SQLite'),
          SizedBox(height: t.unit * 2),
          Text('SCHEMA', style: _sans(10, t.textLo, FontWeight.w700)),
          SizedBox(height: t.unit),
          _treeRow('public', 0, open: true),
          _treeRow('users', 1, table: true),
          _treeRow('orders', 1, table: true),
          _treeRow('events', 1, table: true),
        ]),
      );

  Widget _connRow(String name, String kind, {bool active = false}) {
    return Container(
      margin: EdgeInsets.only(bottom: t.unit * 0.75),
      padding: EdgeInsets.symmetric(horizontal: t.unit, vertical: t.unit * 0.75),
      decoration: BoxDecoration(
        color: active ? t.accent.withValues(alpha: t.glass ? 0.16 : 0.22) : Colors.transparent,
        borderRadius: BorderRadius.circular(t.radiusSm),
        border: active ? Border.all(color: t.accent.withValues(alpha: 0.6)) : null,
        boxShadow: active && t.glow > 0
            ? [BoxShadow(color: t.accent.withValues(alpha: 0.35), blurRadius: t.glow)]
            : null,
      ),
      child: Row(children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: active ? t.accent : t.textLo, shape: BoxShape.circle)),
        SizedBox(width: t.unit),
        Expanded(child: Text(name, style: _sans(13, active ? t.textHi : t.textMid, active ? FontWeight.w600 : FontWeight.w400))),
        Text(kind, style: _sans(10, t.textLo)),
      ]),
    );
  }

  Widget _treeRow(String label, int depth, {bool open = false, bool table = false}) => Padding(
        padding: EdgeInsets.only(left: depth * 16.0, top: t.unit * 0.5, bottom: t.unit * 0.5),
        child: Row(children: [
          Icon(table ? Icons.table_rows_outlined : (open ? Icons.folder_open : Icons.folder),
              size: 15, color: table ? t.textMid : t.accent),
          SizedBox(width: t.unit * 0.75),
          Text(label, style: _sans(12.5, t.textMid)),
        ]),
      );

  Widget _main() => Padding(
        padding: EdgeInsets.all(t.unit * 2),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _tabStrip(),
          SizedBox(height: t.unit * 1.5),
          _glass(child: _connForm()),
          SizedBox(height: t.unit * 1.5),
          _glass(child: _editor()),
          SizedBox(height: t.unit * 1.5),
          Expanded(child: _glass(child: _resultGrid())),
        ]),
      );

  Widget _tabStrip() => Row(children: [
        _tab('users · SELECT', active: true),
        _tab('orders'),
        _tab('+ new', dim: true),
      ]);

  Widget _tab(String label, {bool active = false, bool dim = false}) => Container(
        margin: EdgeInsets.only(right: t.unit),
        padding: EdgeInsets.symmetric(horizontal: t.unit * 1.5, vertical: t.unit * 0.75),
        decoration: BoxDecoration(
          color: active ? t.surface : Colors.transparent,
          borderRadius: BorderRadius.vertical(top: Radius.circular(t.radiusSm), bottom: Radius.zero),
          border: Border(bottom: BorderSide(color: active ? t.accent : Colors.transparent, width: 2)),
        ),
        child: Text(label, style: _sans(12.5, dim ? t.textLo : (active ? t.textHi : t.textMid), active ? FontWeight.w600 : FontWeight.w400)),
      );

  // frosted / glass wrapper honoring tokens
  Widget _glass({required Widget child}) {
    final panel = Container(
      decoration: BoxDecoration(
        color: t.surface.withValues(alpha: t.panelOpacity),
        borderRadius: BorderRadius.circular(t.radius),
        border: Border.all(color: t.border),
        boxShadow: t.glow > 0
            ? [BoxShadow(color: t.accent.withValues(alpha: 0.06), blurRadius: t.glow * 1.5)]
            : const [BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 6))],
      ),
      padding: EdgeInsets.all(t.unit * 1.75),
      child: child,
    );
    if (!t.glass) return panel;
    return ClipRRect(
      borderRadius: BorderRadius.circular(t.radius),
      child: BackdropFilter(filter: ImageFilter.blur(sigmaX: t.blur, sigmaY: t.blur), child: panel),
    );
  }

  Widget _connForm() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('New Connection', style: _sans(16, t.textHi, FontWeight.w700)),
          const Spacer(),
          _btn('Test', primary: false),
          SizedBox(width: t.unit),
          _btn('Connect', primary: true),
        ]),
        SizedBox(height: t.unit * 0.5),
        Text('PostgreSQL · SSL preferred', style: _sans(12, t.textLo)),
        SizedBox(height: t.unit * 1.5),
        Row(children: [
          Expanded(flex: 3, child: _field('Host', 'db.internal.voltquery.io')),
          SizedBox(width: t.unit),
          Expanded(flex: 1, child: _field('Port', '5432')),
        ]),
        SizedBox(height: t.unit),
        Row(children: [
          Expanded(child: _field('Database', 'analytics')),
          SizedBox(width: t.unit),
          Expanded(child: _field('Driver', 'PostgreSQL v3', dropdown: true)),
        ]),
      ]);

  Widget _field(String label, String value, {bool dropdown = false}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: _sans(10, t.textLo, FontWeight.w600)),
          SizedBox(height: t.unit * 0.5),
          Container(
            height: t.controlH,
            padding: EdgeInsets.symmetric(horizontal: t.unit),
            decoration: BoxDecoration(
              color: t.bg.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(t.radiusSm),
              border: Border.all(color: t.border),
            ),
            child: Row(children: [
              Expanded(child: Text(value, style: _sans(13, t.textHi))),
              if (dropdown) Icon(Icons.expand_more, size: 16, color: t.textMid),
            ]),
          ),
        ],
      );

  Widget _btn(String label, {required bool primary}) {
    return Container(
      height: t.controlH,
      padding: EdgeInsets.symmetric(horizontal: t.unit * 1.75),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: primary ? t.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(t.radiusSm),
        border: primary ? null : Border.all(color: t.border),
        gradient: primary && (t.key == 'A' || t.key == 'B')
            ? LinearGradient(colors: [t.accent, t.accent2])
            : null,
        boxShadow: primary && t.glow > 0
            ? [BoxShadow(color: t.accent.withValues(alpha: 0.5), blurRadius: t.glow)]
            : null,
      ),
      child: Text(label,
          style: _sans(13, primary ? t.onAccent : t.textMid, FontWeight.w600)),
    );
  }

  Widget _editor() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.terminal, size: 15, color: t.accent),
          SizedBox(width: t.unit * 0.75),
          Text('QUERY', style: _sans(10, t.textLo, FontWeight.w700)),
        ]),
        SizedBox(height: t.unit),
        DefaultTextStyle(
          style: TextStyle(fontFamily: t.mono, fontSize: 13.5, height: 1.5),
          child: Wrap(children: [
            Text('SELECT ', style: TextStyle(fontFamily: t.mono, color: t.synKeyword, fontWeight: FontWeight.w700, fontSize: 13.5)),
            Text('id, email, created_at ', style: TextStyle(fontFamily: t.mono, color: t.synIdent, fontSize: 13.5)),
            Text('FROM ', style: TextStyle(fontFamily: t.mono, color: t.synKeyword, fontWeight: FontWeight.w700, fontSize: 13.5)),
            Text('users ', style: TextStyle(fontFamily: t.mono, color: t.synIdent, fontSize: 13.5)),
            Text('WHERE ', style: TextStyle(fontFamily: t.mono, color: t.synKeyword, fontWeight: FontWeight.w700, fontSize: 13.5)),
            Text("status = ", style: TextStyle(fontFamily: t.mono, color: t.synIdent, fontSize: 13.5)),
            Text("'active' ", style: TextStyle(fontFamily: t.mono, color: t.synString, fontSize: 13.5)),
            Text('LIMIT ', style: TextStyle(fontFamily: t.mono, color: t.synKeyword, fontWeight: FontWeight.w700, fontSize: 13.5)),
            Text('100', style: TextStyle(fontFamily: t.mono, color: t.synNumber, fontSize: 13.5)),
            Text(';', style: TextStyle(fontFamily: t.mono, color: t.textMid, fontSize: 13.5)),
          ]),
        ),
      ]);

  Widget _resultGrid() {
    final cols = ['id', 'email', 'status', 'created_at'];
    final rows = [
      ['1', 'ada@volt.io', 'active', '2026-01-14'],
      ['2', 'lin@volt.io', 'active', '2026-02-02'],
      ['3', 'ken@volt.io', 'trial', '2026-03-19'],
      ['4', 'mira@volt.io', 'active', '2026-04-07'],
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // header
      Container(
        padding: EdgeInsets.symmetric(vertical: t.unit, horizontal: t.unit),
        decoration: BoxDecoration(
          color: t.surfaceAlt.withValues(alpha: 0.7),
          borderRadius: BorderRadius.vertical(top: Radius.circular(t.radiusSm)),
          border: Border(bottom: BorderSide(color: t.border)),
        ),
        child: Row(children: [
          for (final c in cols)
            Expanded(child: Text(c, style: _sans(11.5, t.textMid, FontWeight.w700))),
        ]),
      ),
      Expanded(
        child: ListView.builder(
          itemCount: rows.length,
          itemBuilder: (_, r) => Container(
            padding: EdgeInsets.symmetric(vertical: t.unit * 0.9, horizontal: t.unit),
            decoration: BoxDecoration(
              color: r.isOdd ? t.bg.withValues(alpha: 0.25) : Colors.transparent,
              border: Border(bottom: BorderSide(color: t.border.withValues(alpha: 0.5))),
            ),
            child: Row(children: [
              for (var c = 0; c < cols.length; c++)
                Expanded(
                  child: c == 2
                      ? Align(alignment: Alignment.centerLeft, child: _statusChip(rows[r][c]))
                      : Text(rows[r][c], style: TextStyle(fontFamily: t.mono, fontSize: 12.5, color: t.textHi)),
                ),
            ]),
          ),
        ),
      ),
    ]);
  }

  Widget _statusChip(String s) {
    final ok = s == 'active';
    final c = ok ? t.accent : t.synNumber;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: t.unit, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withValues(alpha: 0.5)),
      ),
      child: Text(s, style: _sans(11, c, FontWeight.w600)),
    );
  }

  Widget _statusBar() => Container(
        height: 26,
        color: t.surfaceAlt,
        padding: EdgeInsets.symmetric(horizontal: t.unit * 1.5),
        child: Row(children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: t.accent, shape: BoxShape.circle, boxShadow: t.glow > 0 ? [BoxShadow(color: t.accent, blurRadius: 6)] : null)),
          SizedBox(width: t.unit),
          Text('Connected · prod-postgres', style: _sans(11, t.textMid)),
          const Spacer(),
          Text('4 rows · 12ms', style: _sans(11, t.textLo)),
        ]),
      );
}
