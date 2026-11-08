import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Loading animation: a line-drawn pup gallops off to find a red ball,
/// sniffs it out, scoops it up and runs back with it. Loops.
class FetchLoader extends StatefulWidget {
  const FetchLoader({super.key, this.height = 110});
  final double height;
  @override
  State<FetchLoader> createState() => _FetchLoaderState();
}

class _FetchLoaderState extends State<FetchLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 6200))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: widget.height,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => CustomPaint(painter: _FetchPainter(_c.value)),
        ),
      );
}

class _FetchPainter extends CustomPainter {
  _FetchPainter(this.t);
  final double t;

  static const _ink = Color(0xFF232120);
  static const _red = Color(0xFFDF1538);
  static const _white = Color(0xFFFFFFFF);
  static const _dogW = 106.0, _boxH = 60.0, _ground = 56.0;

  static double _ease(double v) => v < 0.5 ? 2 * v * v : 1 - math.pow(-2 * v + 2, 2) / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.height / _boxH;
    final span = math.max(0.0, size.width / k - _dogW - 14); // in dog units
    final ballX = _dogW + span; // ball rests just past the dog's nose at the far end

    // Story beats.
    double x; // dog left edge (dog units)
    var right = true, running = false, carrying = false;
    var headDown = 0.0, ballAlpha = 1.0, ballDrop = 0.0;
    if (t < 0.08) {
      x = 0;
      final f = t / 0.08;
      ballDrop = (1 - f) * 30 * (1 - f); // ball bounces in
    } else if (t < 0.42) {
      x = span * _ease((t - 0.08) / 0.34);
      running = true;
    } else if (t < 0.52) {
      x = span;
      final f = (t - 0.42) / 0.1;
      headDown = math.sin(f * math.pi); // sniff, scoop
      carrying = f > 0.5;
    } else if (t < 0.9) {
      x = span * (1 - _ease((t - 0.52) / 0.38));
      right = false;
      running = true;
      carrying = true;
    } else {
      x = 0;
      right = false;
      carrying = true;
      ballAlpha = 1 - (t - 0.9) / 0.1;
    }

    final ph = t * 2 * math.pi * 11; // gallop rhythm
    canvas.save();
    canvas.scale(k);

    // Ground line.
    canvas.drawLine(Offset(0, _ground + 1), Offset(size.width / k, _ground + 1), Paint()
      ..color = _ink.withValues(alpha: 0.1)
      ..strokeWidth = 1.2);

    // Ball waiting at the far end.
    if (!carrying) {
      final b = Offset(ballX + 2, _ground - 4.8 - ballDrop.abs());
      canvas.drawCircle(b, 4.8, Paint()..color = _red);
      canvas.drawCircle(b, 4.8, _stroke(1.6));
    }

    canvas.save();
    if (right) {
      canvas.translate(x, 0);
    } else {
      canvas.translate(x + _dogW, 0);
      canvas.scale(-1, 1);
    }
    if (running) _dust(canvas, ph);
    _dog(canvas, running ? ph : 0, running, carrying ? ballAlpha.clamp(0.0, 1.0) : -1, headDown);
    canvas.restore();
    canvas.restore();
  }

  Paint _stroke(double w, [Color c = _ink]) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  /// An outlined limb: thick ink line with a thinner white line on top.
  void _limb(Canvas c, List<Offset> pts, {double outer = 5.6, double inner = 2.8}) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    c.drawPath(path, _stroke(outer));
    c.drawPath(path, _stroke(inner, _white));
  }

  void _leg(Canvas c, Offset hip, double a1, double a2) {
    final knee = hip + Offset(math.sin(a1) * 11, math.cos(a1) * 11);
    final paw = knee + Offset(math.sin(a2) * 11, math.cos(a2) * 11);
    _limb(c, [hip, knee, paw]);
  }

  void _dust(Canvas c, double ph) {
    final p = _stroke(1.3, _ink.withValues(alpha: 0.35));
    for (var i = 0; i < 3; i++) {
      final o = (ph / (2 * math.pi) + i / 3) % 1.0;
      final x0 = 14 - o * 18 - i * 4;
      final path = Path()..moveTo(x0, _ground - 1 - i * 1.5);
      for (var s = 1; s <= 4; s++) {
        path.relativeQuadraticBezierTo(1.2, s.isOdd ? -1.2 : 1.2, 2.4, 0);
      }
      c.drawPath(path, p);
    }
  }

  /// ball: -1 = no ball (tongue out), else ball opacity in the mouth.
  void _dog(Canvas c, double ph, bool running, double ball, double headDown) {
    final g = running ? math.sin(ph) : 0.0;
    final g2 = running ? math.sin(ph - 0.5) : 0.0;
    final bob = running ? -math.max(0.0, math.sin(ph)) * 4 : 0.0;
    c.save();
    c.translate(0, bob + 2);
    c.translate(50, 28);
    c.rotate(running ? -0.07 * math.cos(ph) : 0);
    c.translate(-50, -28);

    final line = _stroke(2.1);
    final fill = Paint()..color = _white;

    // Far legs.
    _leg(c, const Offset(66, 31), -0.15 - 0.95 * g2, 0.35 - 0.6 * g2);
    _leg(c, const Offset(31, 29), 0.2 + 0.95 * g2, -0.2 - 0.5 * g2);
    // Tail.
    final tw = math.sin(ph * 2 + (running ? 0 : t * 60)) * 0.2;
    _limb(c, [const Offset(22, 23), Offset(15, 17 - 5 * tw), Offset(11, 9 - 4 * tw), Offset(12, 4 - 3 * tw)], outer: 5.2, inner: 2.4);
    // Body.
    final body = Path()
      ..moveTo(22, 22)
      ..cubicTo(34, 16, 52, 19, 64, 16)
      ..cubicTo(74, 13, 82, 20, 79, 30)
      ..cubicTo(77, 37, 70, 38, 62, 35)
      ..cubicTo(52, 32, 42, 35, 32, 35)
      ..cubicTo(20, 35, 15, 27, 22, 22)
      ..close();
    c.drawPath(body, fill);
    c.drawPath(body, line);
    // Near legs.
    _leg(c, const Offset(69, 31), -0.3 - 1.05 * g, 0.4 - 0.7 * g);
    _leg(c, const Offset(34, 30), 0.25 + 1.05 * g, -0.25 - 0.55 * g);

    // Head.
    c.save();
    c.translate(76, 20);
    c.rotate(headDown * 0.7 - (running ? 0.05 * math.cos(ph) : 0));
    c.translate(-76, -20);
    final head = Path()
      ..moveTo(70, 18)
      ..cubicTo(69, 8, 79, 4, 86, 8)
      ..cubicTo(91, 11, 96, 13, 101, 15)
      ..cubicTo(104, 16, 104, 21, 100, 22)
      ..cubicTo(94, 23, 87, 25, 80, 26)
      ..cubicTo(73, 27, 70, 24, 70, 18)
      ..close();
    c.drawPath(head, fill);
    c.drawPath(head, line);
    final ear = Path()
      ..moveTo(76, 9)
      ..cubicTo(73, 5, 71, 2, 70, 0)
      ..cubicTo(74, 1, 79, 3, 82, 7);
    c.drawPath(ear, fill);
    c.drawPath(ear, line);
    c.drawCircle(const Offset(84, 12.5), 1.5, Paint()..color = _ink);
    c.drawCircle(const Offset(101.5, 17), 2, Paint()..color = _ink);
    if (ball >= 0) {
      c.drawCircle(const Offset(99, 25), 4.8, Paint()..color = _red.withValues(alpha: ball));
      c.drawCircle(const Offset(99, 25), 4.8, _stroke(1.6, _ink.withValues(alpha: ball)));
    } else {
      final tongue = Path()
        ..moveTo(90, 23)
        ..cubicTo(89, 30, 94, 31, 95, 26)
        ..lineTo(95, 22.5)
        ..close();
      c.drawPath(tongue, Paint()..color = _red);
      c.drawPath(tongue, _stroke(1.6));
    }
    c.restore();
    c.restore();
  }

  @override
  bool shouldRepaint(_FetchPainter o) => o.t != t;
}
