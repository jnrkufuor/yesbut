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

class RootShell extends StatefulWidget {
  const RootShell({super.key});
  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  void _go(int i) => setState(() => _index = i);

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

class _PillNavState extends State<PillNav> with SingleTickerProviderStateMixin {
  static const _icons = ['check', 'search', 'eye', 'history'];
  static const _labels = ['Check', 'Find', 'Live', 'History'];
  static const _w = 330.0;
  static const _h = 70.0;
  static const _btn = 52.0;
  static const _pad = 9.0; // same inset on every side so the circle sits dead centre
  static const _travel = Cubic(0.3, 1.25, 0.5, 1);

  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 620), value: 1);
  late double _from = _x(widget.index);

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
    super.dispose();
  }

  double _x(int i) {
    const gap = (_w - _pad * 2 - _btn * 4) / 3;
    return _pad + i * (_btn + gap);
  }

  // Travel takes the first 62% of the animation; the icon jiggles after.
  double get _move => (_c.value / 0.62).clamp(0.0, 1.0);
  double _bubbleX() => _from + (_x(widget.index) - _from) * _travel.transform((_move * 1.35).clamp(0.0, 1.0));

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
          // Liquid move: the front of the drop races ahead (with a little
          // overshoot) while the back is still letting go, joined by a neck
          // that thins as it stretches, like water being pulled apart.
          final m = _move;
          final head = _from + (to - _from) * _travel.transform((m * 1.35).clamp(0.0, 1.0));
          final tail = _from + (to - _from) * Curves.easeInOutCubic.transform(((m - 0.2) / 0.8).clamp(0.0, 1.0));
          final j = ((_c.value - 0.55) / 0.45).clamp(0.0, 1.0);
          final jiggle = reduce ? 0.0 : 0.26 * math.sin(j * math.pi * 3) * (1 - j);
          final bump = reduce ? 1.0 : 1 + 0.12 * math.sin(j * math.pi);
          return Stack(children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _DropPainter(
                  head: (reduce ? to : head) + _btn / 2,
                  tail: (reduce ? to : tail) + _btn / 2,
                  cy: _h / 2,
                  r: _btn / 2,
                  wobble: reduce ? 0 : math.sin(j * math.pi * 2) * (1 - j),
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

/// The white drop under the active tab. Two circles (front and back of the
/// drop) bridged by a neck whose edges curve inward; the neck thins as the
/// drop stretches, then everything pulls back into one round drop.
class _DropPainter extends CustomPainter {
  _DropPainter({required this.head, required this.tail, required this.cy, required this.r, required this.wobble});
  final double head, tail, cy, r, wobble;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = GColors.white;
    final d = (head - tail).abs();
    final k = (d / (r * 2.6)).clamp(0.0, 1.0);
    final rh = r * (1 - 0.14 * k);
    final rt = r * (1 - 0.34 * k);
    // A little squash-and-stretch as it settles.
    final sx = 1 + 0.07 * wobble, sy = 1 - 0.07 * wobble;
    canvas.save();
    canvas.translate(head, cy);
    canvas.scale(sx, sy);
    canvas.translate(-head, -cy);
    canvas.drawCircle(Offset(head, cy), rh, paint);
    if (d > 0.5) {
      canvas.drawCircle(Offset(tail, cy), rt, paint);
      final neck = r * (0.5 - 0.45 * k);
      final mid = (head + tail) / 2;
      final path = Path()
        ..moveTo(tail, cy - rt * 0.92)
        ..quadraticBezierTo(mid, cy - neck, head, cy - rh * 0.92)
        ..lineTo(head, cy + rh * 0.92)
        ..quadraticBezierTo(mid, cy + neck, tail, cy + rt * 0.92)
        ..close();
      canvas.drawPath(path, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DropPainter o) =>
      o.head != head || o.tail != tail || o.wobble != wobble || o.r != r || o.cy != cy;
}
