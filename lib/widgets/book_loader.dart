import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Loading animation: someone with their nose buried in a red book (just the
/// top of their head and a furrowed brow peeking over), pages flipping, and
/// fine-print symbols drifting up from their head as they think.
class BookLoader extends StatefulWidget {
  const BookLoader({super.key, this.height = 130});
  final double height;
  @override
  State<BookLoader> createState() => _BookLoaderState();
}

class _BookLoaderState extends State<BookLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();

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
          builder: (_, __) => CustomPaint(painter: _BookPainter(_c.value * 20)),
        ),
      );
}

class _BookPainter extends CustomPainter {
  _BookPainter(this.t); // seconds
  final double t;

  static const _ink = Color(0xFF232120);
  static const _red = Color(0xFFDF1538);
  static const _symbols = ['§', '?', '%', '!', '*', 'fine print', r'$', '…', '¶', '?!', 'T&C', '*'];

  @override
  void paint(Canvas canvas, Size size) {
    const boxW = 120.0, boxH = 104.0;
    final k = size.height / boxH;
    canvas.save();
    canvas.translate((size.width - boxW * k) / 2, 0);
    canvas.scale(k);

    final line = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final white = Paint()..color = Colors.white;
    final ink = Paint()..color = _ink;

    // Thoughts: symbols float up off the head and fade (no bubble).
    for (var i = 0; i < 5; i++) {
      final cyc = t * 0.35 + i / 5;
      final p = cyc % 1.0;
      final s = _symbols[(i + cyc.floor() * 3) % _symbols.length];
      final x = 60 + math.sin(i * 2.3 + p * 3) * 28 + (i - 2) * 6;
      final y = 36 - p * 34;
      final a = math.sin(p * math.pi);
      final style = s == 'fine print'
          ? TextStyle(fontFamily: AppTheme.serif, fontStyle: FontStyle.italic, fontSize: 9, color: _ink.withValues(alpha: a))
          : TextStyle(
              fontFamily: AppTheme.display,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: (s == '*' ? _red : _ink).withValues(alpha: a));
      final tp = TextPainter(text: TextSpan(text: s, style: style), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height));
    }

    canvas.translate(0, math.sin(t * 2 * math.pi * 0.8) * 1.2);

    // Top of the head, a few tufts, eyes and a furrowed brow over the book.
    final head = Rect.fromCircle(center: const Offset(60, 60), radius: 21);
    canvas.drawArc(head, math.pi, math.pi, true, white);
    canvas.drawArc(head, math.pi, math.pi, false, line);
    canvas.drawPath(
        Path()
          ..moveTo(50, 40)
          ..quadraticBezierTo(53, 33, 57, 39)
          ..quadraticBezierTo(61, 31, 64, 39)
          ..quadraticBezierTo(68, 34, 70, 41),
        line);
    final blink = (t % 3.7) < 0.12;
    if (blink) {
      canvas.drawLine(const Offset(50, 55), const Offset(54, 55), line);
      canvas.drawLine(const Offset(66, 55), const Offset(70, 55), line);
    } else {
      canvas.drawCircle(const Offset(52, 55), 1.6, ink);
      canvas.drawCircle(const Offset(68, 55), 1.6, ink);
    }
    canvas.drawLine(const Offset(48, 50), const Offset(55, 51.5), line);
    canvas.drawLine(const Offset(72, 50), const Offset(65, 51.5), line);

    // Red covers behind the pages.
    final cover = Path()
      ..moveTo(16, 58)
      ..quadraticBezierTo(38, 56, 60, 64)
      ..quadraticBezierTo(82, 56, 104, 58)
      ..lineTo(106, 96)
      ..quadraticBezierTo(82, 93, 60, 100)
      ..quadraticBezierTo(38, 93, 14, 96)
      ..close();
    canvas.drawPath(cover, Paint()..color = _red);
    canvas.drawPath(cover, line);

    Path page(double edge) => Path()
      ..moveTo(edge, 58)
      ..quadraticBezierTo((edge + 60) / 2, 54, 60, 62)
      ..lineTo(60, 95)
      ..quadraticBezierTo((edge + 60) / 2, 88, edge + (edge < 60 ? -1 : 1), 91)
      ..close();
    for (final e in [19.0, 101.0]) {
      canvas.drawPath(page(e), white);
      canvas.drawPath(page(e), line);
    }

    // A page turning over every so often.
    final f = (t * 0.4) % 1.0;
    if (f < 0.5) {
      final q = Curves.easeInOut.transform(f / 0.5);
      final ex = 101 - q * 82;
      final lift = math.sin(q * math.pi) * 14;
      final turning = Path()
        ..moveTo(60, 62)
        ..quadraticBezierTo((60 + ex) / 2, 56 - lift, ex, 58 - lift * 0.6)
        ..lineTo(ex, 91 - lift * 0.6)
        ..quadraticBezierTo((60 + ex) / 2, 88 - lift, 60, 95)
        ..close();
      canvas.drawPath(turning, white);
      canvas.drawPath(turning, line);
    }

    // Fingertips gripping the book.
    for (final o in const [Offset(16, 70), Offset(16, 78), Offset(104, 70), Offset(104, 78)]) {
      final r = Rect.fromCenter(center: o, width: 6.8, height: 6);
      canvas.drawOval(r, white);
      canvas.drawOval(r, line);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BookPainter o) => o.t != t;
}
