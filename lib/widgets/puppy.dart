import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Search animation: a scruffy little poodle, drawn in our single-line
/// style, trotting back and forth with its nose to the ground, stopping now
/// and then for a proper sniff.
class PuppyLoader extends StatefulWidget {
  const PuppyLoader({super.key, this.height = 120, this.color = const Color(0xFF232120)});
  final double height;
  final Color color;
  @override
  State<PuppyLoader> createState() => _PuppyLoaderState();
}

class _PuppyLoaderState extends State<PuppyLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 9))..repeat();

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
          builder: (_, __) => CustomPaint(painter: _PuppyPainter(_c.value, widget.color)),
        ),
      );
}

class _PuppyPainter extends CustomPainter {
  _PuppyPainter(this.t, this.color);
  final double t; // 0..1 over one round trip
  final Color color;

  // Dog drawn in a 100 x 80 box facing right; feet on y = 73.
  static const _w = 100.0, _h = 80.0;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.height / _h;
    final dogW = _w * k;
    final travel = math.max(0.0, size.width - dogW);

    // Timeline: walk right (0-.38), sniff (.38-.5), walk left (.5-.88), sniff.
    double x;
    bool right;
    bool walking;
    double local; // 0..1 inside the current part
    if (t < 0.38) {
      local = t / 0.38;
      x = _ease(local);
      right = true;
      walking = true;
    } else if (t < 0.5) {
      local = (t - 0.38) / 0.12;
      x = 1;
      right = true;
      walking = false;
    } else if (t < 0.88) {
      local = (t - 0.5) / 0.38;
      x = 1 - _ease(local);
      right = false;
      walking = true;
    } else {
      local = (t - 0.88) / 0.12;
      x = 0;
      right = false;
      walking = false;
    }

    final steps = t * 9 * 2 * math.pi * 1.6; // leg rhythm
    final bob = walking ? math.sin(steps * 2).abs() * 1.2 : 0.0;
    // Nose dips: a little while trotting, all the way down when stopped.
    final sniff = walking ? 0.25 + 0.2 * math.sin(steps * 0.5) : 0.65 + 0.35 * math.sin(local * math.pi * 6).abs();

    canvas.save();
    canvas.translate(travel * x, 0);
    if (!right) {
      canvas.translate(dogW, 0);
      canvas.scale(-1, 1);
    }
    canvas.scale(k);

    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final ink = Paint()..color = color;
    final white = Paint()..color = const Color(0xFFFFFFFF);

    canvas.drawLine(const Offset(-400, 73), const Offset(500, 73), Paint()
      ..color = color.withValues(alpha: 0.12)
      ..strokeWidth = 1.2);

    canvas.translate(0, -bob);

    // Legs with pom-pom feet, pairs swinging opposite.
    void leg(double hipX, double phase) {
      final a = (walking ? math.sin(steps + phase) : 0.0) * 0.35;
      const len = 15.0;
      final hip = Offset(hipX, 52);
      canvas.drawLine(hip, Offset(hipX + math.sin(a) * (len - 3), 54 + math.cos(a) * (len - 3)), p);
      final foot = Offset(hipX + math.sin(a) * len + 1, 54 + math.cos(a) * len + 0.5);
      _cloud(canvas, foot, 3.4, 2.8, 5, p, white, seed: hipX.round(), amp: 1.2);
    }

    leg(30, math.pi);
    leg(36, 0);
    leg(52, 0);
    leg(58, math.pi);

    // Tail with a pom-pom, wagging.
    final wag = math.sin(t * 2 * math.pi * 14) * 0.35;
    const tb = Offset(26, 40);
    final ang = 0.6 + wag;
    canvas.drawLine(tb, tb + Offset(-math.sin(ang) * 8, -math.cos(ang) * 8), p);
    _cloud(canvas, tb + Offset(-math.sin(ang) * 12, -math.cos(ang) * 12), 4.4, 3.8, 7, p, white, seed: 3, amp: 1.4);

    // Curly body.
    _cloud(canvas, const Offset(44, 45), 19, 10.5, 10, p, white, seed: 1);

    // Head tips down from the neck to sniff.
    canvas.save();
    canvas.translate(60, 36);
    canvas.rotate(sniff * 0.75);
    canvas.translate(-60, -36);
    final muzzle = Path()
      ..moveTo(76, 26)
      ..cubicTo(84, 24, 92, 25, 93, 30)
      ..cubicTo(94, 35, 86, 38, 77, 37)
      ..close();
    canvas.drawPath(muzzle, white);
    canvas.drawPath(muzzle, p);
    _cloud(canvas, const Offset(69, 28), 11, 10, 10, p, white, seed: 2, amp: 1.7);
    _cloud(canvas, const Offset(67, 16.5), 6.5, 4.5, 7, p, white, seed: 5, amp: 1.4); // top knot
    _cloud(canvas, const Offset(63, 35), 4, 8.5, 6, p, white, seed: 6, amp: 1.3); // floppy ear
    final nose = const Offset(93, 29.5);
    canvas.drawCircle(nose, 2.4, ink);
    canvas.drawCircle(const Offset(74, 26), 1.4, ink);
    canvas.drawPath(Path()..moveTo(86, 35)..quadraticBezierTo(88, 37, 90, 35), p);

    // Sniff puffs near the nose while stopped.
    if (!walking) {
      for (var i = 0; i < 3; i++) {
        final ph = (local * 3 + i / 3) % 1.0;
        final o = nose + Offset(4 + ph * 10, -2 - ph * 8 + i * 3);
        final puff = Paint()
          ..color = color.withValues(alpha: (1 - ph) * 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(Rect.fromCircle(center: o, radius: 1.8 + ph * 1.5), -1.2, 2.4, false, puff);
      }
    }
    canvas.restore(); // head
    canvas.restore();
  }

  static double _ease(double v) => v < 0.5 ? 2 * v * v : 1 - math.pow(-2 * v + 2, 2) / 2;

  /// Bumpy closed outline (poodle curls), filled white so parts overlap
  /// cleanly.
  static void _cloud(Canvas c, Offset o, double rx, double ry, int bumps, Paint p, Paint fill,
      {int seed = 0, double amp = 1.8}) {
    final rnd = math.Random(seed);
    final path = Path();
    const n = 90;
    final jitter = [for (var i = 0; i < bumps; i++) 0.8 + rnd.nextDouble() * 0.5];
    for (var i = 0; i <= n; i++) {
      final a = i / n * 2 * math.pi;
      final b = i / n * bumps;
      final bi = b.floor() % bumps;
      final bump = math.sin((b - b.floor()) * math.pi) * amp * jitter[bi];
      final pt = o + Offset(math.cos(a) * (rx + bump), math.sin(a) * (ry + bump));
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    path.close();
    c.drawPath(path, fill);
    c.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_PuppyPainter old) => old.t != t || old.color != color;
}
