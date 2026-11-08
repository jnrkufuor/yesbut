import 'dart:math' as math;

import 'package:flutter/material.dart';


/// Loading scene: floating web pages and clouds on a soft blob, a sunflower
/// search bar typing the query, and a big cherry magnifier gliding over the
/// pages, lighting up whatever it passes. Line style, house colours.
class SearchScene extends StatefulWidget {
  const SearchScene({super.key, this.height = 150, this.text = 'terms & conditions'});
  final double height;
  final String text;
  @override
  State<SearchScene> createState() => _SearchSceneState();
}

class _SearchSceneState extends State<SearchScene> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 60))..repeat();

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
          builder: (_, __) => CustomPaint(painter: _ScenePainter(_c.value * 60, widget.text)),
        ),
      );
}

class _ScenePainter extends CustomPainter {
  _ScenePainter(this.t, this.text);
  final double t; // seconds
  final String text;

  static const _ink = Color(0xFF232120);
  static const _red = Color(0xFFDF1538);
  static const _blue = Color(0xFF4200FF);
  static const _sun = Color(0xFFFFD100);
  static const _w = 200.0, _h = 124.0;

  Paint _line([double w = 1.6, Color c = _ink]) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    final k = math.min(size.height / _h, size.width / _w);
    canvas.save();
    canvas.translate((size.width - _w * k) / 2, (size.height - _h * k) / 2);
    canvas.scale(k);
    final white = Paint()..color = Colors.white;

    // Soft blob behind everything.
    // A soft, slightly crooked rounded square, like a hand-cut canvas.
    final canvasShape = Path()
      ..moveTo(30, 16)
      ..cubicTo(70, 8, 130, 12, 172, 14)
      ..cubicTo(186, 15, 190, 26, 189, 40)
      ..cubicTo(188, 66, 192, 88, 186, 104)
      ..cubicTo(182, 114, 170, 116, 150, 115)
      ..cubicTo(110, 113, 60, 118, 26, 112)
      ..cubicTo(13, 110, 10, 100, 11, 86)
      ..cubicTo(12, 60, 8, 38, 13, 26)
      ..cubicTo(16, 18, 22, 17, 30, 16)
      ..close();
    canvas.drawPath(canvasShape, Paint()..color = _blue.withValues(alpha: 0.06));

    // Each piece drifts on its own slow loop (a few units each way).
    Offset f2(int i) => Offset(math.sin(t * 0.55 + i * 2.1) * 3.5, math.cos(t * 0.7 + i * 1.3) * 3.5);

    void card(double x, double y, double w, double h, String kind) {
      final r = RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), const Radius.circular(5));
      canvas.drawRRect(r, white);
      canvas.drawRRect(r, _line());
      canvas.drawLine(Offset(x, y + 7), Offset(x + w, y + 7), _line());
      for (var i = 0; i < 3; i++) {
        canvas.drawCircle(Offset(x + 5 + i * 4, y + 3.5), 0.9, Paint()..color = _ink);
      }
      switch (kind) {
        case 'img':
          canvas.drawPath(
              Path()
                ..moveTo(x + 6, y + h - 6)
                ..lineTo(x + 16, y + 14)
                ..lineTo(x + 24, y + h - 12)
                ..lineTo(x + 30, y + 20)
                ..lineTo(x + w - 6, y + h - 6),
              _line());
          canvas.drawCircle(Offset(x + w - 12, y + 15), 3, _line());
        case 'play':
          final tri = Path()
            ..moveTo(x + w / 2 - 5, y + 12)
            ..lineTo(x + w / 2 + 7, y + h / 2 + 3.5)
            ..lineTo(x + w / 2 - 5, y + h - 6)
            ..close();
          canvas.drawPath(tri, Paint()..color = _red);
          canvas.drawPath(tri, _line());
        default:
          for (var i = 0; i < 3; i++) {
            canvas.drawLine(Offset(x + 6, y + 14 + i * 6), Offset(x + w - 6 - (i == 2 ? 14 : 0), y + 14 + i * 6), _line(1.6));
          }
      }
    }

    void cloud(double x, double y, double s) {
      final p = Path()
        ..moveTo(x, y)
        ..arcTo(Rect.fromCircle(center: Offset(x + 5 * s, y - 2 * s), radius: 5 * s), math.pi, 0.7 * math.pi, false)
        ..arcTo(Rect.fromCircle(center: Offset(x + 12 * s, y - 4 * s), radius: 6 * s), 1.15 * math.pi, 0.8 * math.pi, false)
        ..arcTo(Rect.fromCircle(center: Offset(x + 19 * s, y - 1 * s), radius: 4 * s), 1.4 * math.pi, 0.7 * math.pi, false)
        ..close();
      canvas.drawPath(p, white);
      canvas.drawPath(p, _line());
    }

    Offset o;
    o = f2(0);
    card(16 + o.dx, 18 + o.dy, 54, 34, 'lines');
    o = f2(1);
    card(128 + o.dx, 10 + o.dy, 52, 42, 'img');
    o = f2(2);
    card(24 + o.dx, 78 + o.dy, 50, 32, 'play');
    o = f2(3);
    card(126 + o.dx, 76 + o.dy, 54, 32, 'lines');
    o = f2(5);
    cloud(76 + o.dx, 22 + o.dy * 0.6, 0.9);

    // Search bar floats too.
    final bo = f2(4) * 0.6;
    canvas.save();
    canvas.translate(bo.dx, bo.dy);
    // Search bar typing the query, then pausing, then again.
    final bar = RRect.fromRectAndRadius(const Rect.fromLTWH(40, 50, 124, 17), const Radius.circular(8.5));
    canvas.drawRRect(bar, Paint()..color = _sun);
    canvas.drawRRect(bar, _line());
    canvas.drawCircle(const Offset(51, 57.5), 3.4, _line());
    canvas.drawLine(const Offset(53.6, 60.1), const Offset(56, 62.5), _line());
    // "Typing": little word-shaped dashes appear one by one, then clear.
    const words = [10.0, 7.0, 13.0, 9.0, 11.0];
    final shown = ((t * 2.2) % (words.length + 3)).floor().clamp(0, words.length);
    var cx = 62.0;
    for (var i = 0; i < shown; i++) {
      canvas.drawLine(Offset(cx, 58.5), Offset(cx + words[i], 58.5), _line(2.6));
      cx += words[i] + 4;
    }
    if ((t * 2.5).floor().isEven) {
      canvas.drawLine(Offset(cx + 1, 53), Offset(cx + 1, 64), _line(1.4));
    }

    canvas.restore();

    // The magnifier glides over the pages.
    final mx = 100 + math.sin(t * 0.9) * 62, my = 60 + math.sin(t * 1.8) * 30;
    canvas.save();
    canvas.translate(mx, my);
    canvas.rotate(-0.6 + math.sin(t * 0.9) * 0.25);
    canvas.drawCircle(Offset.zero, 13, Paint()..color = _sun.withValues(alpha: 0.28));
    canvas.drawLine(const Offset(0, 15), const Offset(0, 30), _line(4.2));
    canvas.drawCircle(Offset.zero, 13.5, _line(5.2));
    canvas.drawCircle(Offset.zero, 13.5, _line(2.6, _red));
    canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: 9), 3.6, 0.8, false, _line(1.6, Colors.white));
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ScenePainter o) => o.t != t || o.text != text;
}
