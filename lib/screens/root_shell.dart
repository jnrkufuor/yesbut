import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/dialogs.dart';
import '../widgets/loopy.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'live_screen.dart';
import 'search_screen.dart';
import 'flows.dart';
import 'upload_screen.dart';
import '../services/incoming.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});
  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  void _go(int i) => setState(() => _index = i);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => IncomingService.listen(_handle));
  }

  /// Widget taps and things shared from other apps.
  Future<void> _handle(Incoming inc) async {
    if (!mounted) return;
    final nav = Navigator.of(context);
    nav.popUntil((r) => r.isFirst);
    switch (inc.action) {
      case 'scan':
        await Flows.scan(context);
        return;
      case 'upload':
        nav.push(MaterialPageRoute(builder: (_) => const UploadScreen()));
        return;
      case 'paste':
        await Flows.paste(context);
        return;
      case 'link':
        await Flows.link(context);
        return;
      case 'history':
        _go(3);
        return;
      case 'home':
        _go(0);
        return;
    }
    await shareIn(context, inc);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    return LeaveGuard(
      exitApp: true,
      child: Scaffold(
      body: Stack(children: [
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            transitionBuilder: (child, a) => FadeTransition(
              opacity: a,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, 0.015), end: Offset.zero).animate(a),
                child: child,
              ),
            ),
            child: EntranceScope(
              key: ValueKey(_index),
              child: switch (_index) {
                1 => const SearchScreen(embedded: true),
                2 => const LiveScreen(),
                3 => const HistoryScreen(),
                _ => HomeScreen(
                    onSeeLibrary: () => _go(1),
                    onSeeHistory: () => _go(3),
                    onSearch: () => _go(1),
                  ),
              },
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 22 + bottom,
          // Slide the nav away while the keyboard is up, bring it back after.
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            offset: keyboard ? const Offset(0, 2) : Offset.zero,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: keyboard ? 0 : 1,
              child: IgnorePointer(
                ignoring: keyboard,
                child: Center(child: PillNav(index: _index, onTap: _go)),
              ),
            ),
          ),
        ),
      ]),
    ),
    );
  }
}

/// Floating charcoal pill with a white circle that slides to the active tab.
class PillNav extends StatefulWidget {
  const PillNav({super.key, required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  @override
  State<PillNav> createState() => _PillNavState();
}

class _PillNavState extends State<PillNav> with TickerProviderStateMixin {
  static const _icons = ['check', 'search', 'eye', 'history'];
  static const _labels = ['Check', 'Search', 'Live', 'History'];
  static const _w = 330.0;
  static const _h = 70.0;
  static const _btn = 52.0;
  static const _pad = 9.0; // same inset on every side so the circle sits dead centre
  static const _travel = Cubic(0.3, 1.25, 0.5, 1);

  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 620), value: 1);
  late double _from = _x(widget.index);
  // Keeps the blob gently alive (its edge ripples slowly, like liquid).
  late final AnimationController _idle = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();

  @override
  void didUpdateWidget(PillNav old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      _from = _bubbleX(); // start from wherever the bubble is right now
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    _idle.dispose();
    super.dispose();
  }

  double _x(int i) {
    const gap = (_w - _pad * 2 - _btn * 4) / 3;
    return _pad + i * (_btn + gap);
  }

  // Travel takes the first 62% of the animation; the icon jiggles after.
  double get _move => (_c.value / 0.62).clamp(0.0, 1.0);
  double _bubbleX() => _from + (_x(widget.index) - _from) * _travel.transform(_move);

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Container(
      width: _w,
      height: _h,
      decoration: BoxDecoration(
        color: GColors.ink,
        borderRadius: BorderRadius.circular(99),
        boxShadow: [BoxShadow(color: GColors.ink.withValues(alpha: 0.18), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final to = _x(widget.index);
          // Liquid blob: slides over like the first version, stretches into
          // a long wobbly drop while it travels (leading edge fuller), then
          // settles back with a jelly wobble. Its edge always ripples a
          // little, like liquid. Never fades.
          final m = _move;
          final x = reduce ? to : _bubbleX();
          final dist = (to - _from).abs();
          final stretch = reduce ? 0.0 : math.sin(math.pi * m) * math.min(1.0, dist / 120);
          final j = ((_c.value - 0.55) / 0.45).clamp(0.0, 1.0);
          final wob = reduce ? 0.0 : math.sin(j * math.pi * 3) * (1 - j) * 0.1;
          final jiggle = reduce ? 0.0 : 0.26 * math.sin(j * math.pi * 3) * (1 - j);
          final bump = reduce ? 1.0 : 1 + 0.12 * math.sin(j * math.pi);
          return Stack(children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _idle,
                builder: (_, __) => CustomPaint(
                  painter: _BlobPainter(
                    cx: x + _btn / 2,
                    cy: _h / 2,
                    r: _btn / 2,
                    stretch: stretch,
                    dir: to >= _from ? 1 : -1,
                    wobble: wob,
                    phase: reduce ? 0 : _idle.value * 2 * math.pi,
                  ),
                ),
              ),
            ),
            for (var i = 0; i < 4; i++)
              Positioned(
                left: _x(i),
                top: (_h - _btn) / 2,
                width: _btn,
                height: _btn,
                child: Semantics(
                  button: true,
                  selected: i == widget.index,
                  label: _labels[i],
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => widget.onTap(i),
                    child: Center(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(end: i == widget.index ? 1 : 0),
                        duration: const Duration(milliseconds: 260),
                        builder: (context, v, _) => Transform.rotate(
                          angle: i == widget.index ? jiggle : 0,
                          child: Transform.scale(
                            scale: i == widget.index ? bump : 1,
                            child: LoopyIcon(
                              _icons[i],
                              size: 28,
                              color: Color.lerp(GColors.white, GColors.ink, v)!,
                              stroke: 2.4 + 0.9 * v,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ]);
        },
      ),
    );
  }
}


/// The white liquid blob under the active tab.
class _BlobPainter extends CustomPainter {
  _BlobPainter({
    required this.cx,
    required this.cy,
    required this.r,
    required this.stretch,
    required this.dir,
    required this.wobble,
    required this.phase,
  });
  final double cx, cy, r, stretch, wobble, phase;
  final int dir;

  @override
  void paint(Canvas canvas, Size size) {
    const n = 72;
    final d = dir.toDouble();
    // Stretched along the path while moving, flattened a bit top-to-bottom.
    final sx = 1 + 0.55 * stretch + wobble;
    final sy = 1 - 0.18 * stretch - wobble * 0.8;
    final path = Path();
    for (var i = 0; i <= n; i++) {
      final a = i / n * 2 * math.pi;
      final cosA = math.cos(a), sinA = math.sin(a);
      // Gentle ripples that drift around the edge; stronger while moving.
      final ripple = (0.035 + 0.05 * stretch) *
          (math.sin(3 * a + phase) * 0.6 + math.sin(5 * a - phase * 1.5) * 0.4);
      // Leading side fuller, trailing side tapers.
      final lead = 1 + 0.12 * stretch * cosA * d;
      final rr = r * (1 + ripple) * lead;
      final px = cx + cosA * rr * sx - d * r * 0.25 * stretch; // centre lags a touch behind the front
      final py = cy + sinA * rr * sy;
      i == 0 ? path.moveTo(px, py) : path.lineTo(px, py);
    }
    canvas.drawPath(path..close(), Paint()..color = GColors.white);
  }

  @override
  bool shouldRepaint(_BlobPainter o) =>
      o.cx != cx || o.stretch != stretch || o.wobble != wobble || o.phase != phase || o.dir != dir || o.r != r;
}
