import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path_parsing/path_parsing.dart';

/// YesBut's hand-drawn, single-line icon set (40×40 viewBox).
class Loopy {
  static const paths = <String, List<String>>{
    'refresh': ['M30.6 15.4 C28.4 10.6 23.8 8 19.4 8.4 C12.6 9 8.2 14.8 8.6 21 C9 27.2 14.4 32 20.6 31.6 C25.4 31.2 29 28.2 30.6 24', 'M31.6 8.6 C31.4 11 31.2 13.4 31 15.8 C28.6 15.6 26.2 15.4 23.8 15.2'],
    'doc': ['M10.4 6.6 C16 6.2 21.4 6.4 24.6 6.6 C27.4 9.4 29.6 11.6 30.2 13.2 C30 20.2 30.4 27.4 29.8 33.6 C23.4 34 16.8 33.8 10.4 33.6 C10 24.6 10.2 15.6 10.4 6.6', 'M24.6 6.6 C24.4 9 24.6 11.4 24.6 13.4 C26.4 13.4 28.4 13.2 30.2 13.2', 'M15.2 18.8 C18.8 18.6 22 18.8 25.2 18.6', 'M15.2 23.6 C18.8 23.4 22 23.6 25.4 23.4', 'M15.2 28.4 C17.6 28.2 19.8 28.4 21.8 28.2'],
    'bell': ['M11.6 27.4 C13 24.4 12.8 20.4 13.4 16.8 C14.2 12.4 17 10.4 20.2 10.4 C23.4 10.4 26 12.6 26.6 16.8 C27.2 20.4 27 24.4 28.4 27.4 C22.8 28.4 17.2 28.4 11.6 27.4', 'M17.4 31 C18.4 33 21.8 33 22.8 31', 'M20.2 10.4 C20 9 20.2 8 20.4 7', 'M30.8 11.8 C32.2 13.4 32.8 15.4 32.8 17.4', 'M9.4 11.8 C8 13.4 7.4 15.4 7.4 17.4'],
    'sleep': ['M22 6.2 C13.4 5.6 6 12 5.8 20.6 C5.6 29 12.2 35 20.4 34.6 C28 34.2 33.8 28.4 34 21', 'M11.6 21.4 C13.4 23.8 16.6 23.8 18.2 21.4', 'M21.8 21.4 C23.6 23.8 26.8 23.8 28.4 21.4', 'M17.4 28.4 C19.2 29.4 21 29.4 22.8 28.4', 'M26 9.4 L31 9.2 L26 14.4 L31.2 14.2', 'M32.4 3.4 L35.6 3.4 L32.4 6.8 L35.8 6.8'],
    'trash': ['M8 11.4 C16 11 24 11.6 32 11.2', 'M16 11.2 C16 8.4 17 7.4 20 7.4 C23 7.4 24 8.4 24 11.2', 'M10.8 11.6 C11.4 18.8 11.6 26 12.4 33 C17.4 33.4 22.6 33.2 27.6 33 C28.4 26 28.6 18.8 29.2 11.6', 'M17 17 C17.2 21 17 25 17.2 28', 'M23 17 C22.8 21 23 25 22.8 28'],
    'speaker': ['M8 16 C10 16 12 16 14 15.8 C17 13 20 10.6 23 8.4 C23.4 16 23 24 23.2 31.6 C20.2 29.4 17.2 27 14.2 24.2 C12 24 10 24.2 8 24 C7.8 21.4 7.8 18.6 8 16', 'M27.4 15 C29.4 17.6 29.4 22.4 27.4 25', 'M30.6 11.4 C34.4 16 34.4 24 30.6 28.6'],
    'stop': ['M12 12 C17 11.6 23 12.2 28 12 C28.2 17 27.8 23 28 28 C23 28.2 17 27.8 12 28 C11.8 23 12.2 17 12 12'],
    'scan': ['M6.6 14 C6.4 10.6 6.8 8 7.4 6.8 C9 6.4 11.6 6.6 14.4 6.6', 'M25.6 6.6 C28.4 6.4 31 6.8 32.6 7.2 C33.2 9 33.4 11.4 33.4 14', 'M33.4 26 C33.6 29 33.2 31.4 32.8 32.8 C31 33.4 28.6 33.4 25.6 33.4', 'M14.4 33.4 C11.4 33.6 9 33.2 7.2 32.6 C6.6 31 6.6 28.6 6.6 26', 'M20 26.4 C16.2 26.6 13.6 23.6 13.8 20.2 C14 16.6 17 13.8 20.4 14 C24 14.2 26.4 17.2 26.2 20.6 C26 23.4 23.6 25.2 21.4 24.4 C19.6 23.8 19.4 21.4 21 20.6'],
    'upload': ['M12 27.4 C7.4 27.6 5.6 23.2 8.2 20.6 C9.2 19.6 10.6 19.4 11.6 19.8 C11.6 14.2 17.6 11.4 21.6 14 C23.2 15 24.2 16.6 24.4 18.2 C27.4 16.8 31.6 18.6 31.8 22.6 C32 25.8 29.6 27.6 27 27.4', 'M20.2 34.6 C20.4 30 19.8 25.2 20.4 20.6 C19.2 21.8 17.4 23.4 15.8 25 M20.4 20.6 C21.8 22 23.4 23.6 24.8 25.2'],
    'paste': ['M14.6 9.2 C12.4 9 10.6 9.4 9.4 9.8 C9 18 9.8 26.4 9.4 34.4 C16.6 34.8 24 34 31 34.2 C30.6 25.8 31.2 17.4 30.6 9.2 C29.2 9 27.6 9.4 25.6 9.2 C26 6.4 24.4 5.4 20 5.6 C15.8 5.8 14.2 6.6 14.6 9.2 C18.4 9.8 22 9.4 25.6 9.2', 'M13.6 22.6 C15 18.2 18.4 18.8 17.8 21.4 C17.4 23.4 14.8 23 15.4 21 C16.2 18.2 21.2 18.2 21.6 21.4 C21.8 23.4 19.2 23.4 19.8 21 C20.6 18.2 25.6 18.4 25.8 21.4 C26 23.4 23.4 23.4 24.2 21.2 C24.8 19.8 26.4 20.2 27 21'],
    'link': ['M17.4 33.8 C15.8 26.4 16.4 18 18.6 11.4 C20.4 6.2 26.4 5.2 28.2 9.6 C30 14.4 27.2 22.4 24.8 27 C23.4 29.8 20.6 29.6 20.8 26.4 C21 22.4 23.4 17.2 25 13.6'],
    'flag': ['M11 35 C10.6 26 11 16 11.2 6.4 C15.6 4.8 19.4 8.6 23.4 7.4 C26.6 6.4 28.2 5 31 6.2 C30.6 10.6 30.8 15 31.2 19.4 C27.6 21.4 24.2 18.6 20.6 19.6 C17.4 20.4 14.6 22.4 11.2 21.2', 'M15.6 14.2 C16.4 11.4 19.6 11.8 19.2 13.8 C18.8 15.6 16.4 15 17.2 13.2'],
    'eye': ['M4.6 20.4 C10 12.4 16 10.2 20.4 10.4 C27 10.6 32 15.2 35.4 20.2 C31.4 26.4 26 29.8 20 29.6 C13.6 29.4 8.6 25.8 4.6 20.4', 'M20.2 24.6 C16.8 24.6 15.6 21.4 17 19 C18.4 16.8 21.8 16.8 23 19.2 C24 21.2 22.6 22.8 21 22.2 C19.8 21.6 20.2 20.2 21 19.8'],
    'check': ['M27.8 9.2 C24.2 6.4 17 5.8 12 9.4 C6.4 13.4 5.6 22.6 9.8 28.2 C14 33.8 23.4 35 29 30.2 C33.6 26.2 34.4 19.2 31.8 14.4', 'M13.4 20.6 C15.4 22 17 23.8 18.4 25.6 C21.8 20 25.6 14.6 30.6 9.4 C32 8 33.4 8.6 32.4 10'],
    'library': ['M8 33.6 C8.4 25.4 7.8 17 8.4 8.8 C10.4 8.4 12.6 8.8 14.4 8.6 C14.6 17 14 25.4 14.4 33.6', 'M14.4 13 C16.6 12.6 18.6 13 20.8 12.8 C20.6 19.6 21 26.6 20.6 33.4', 'M23.4 33.2 C24.6 25.6 26 18 27.4 10.6 C29.4 10.8 31 11.4 32.8 11.8 C31.6 19.4 30.2 26.8 28.8 33.4', 'M6.4 33.8 C15.6 33.4 24.6 33.6 34 33.2'],
    'history': ['M8.6 12.6 C12 7.6 17.6 6 22.6 7.2 C29.8 8.8 34 15.6 33 22.6 C32 29.6 25.6 34 18.8 33.2 C12 32.4 7.2 26.8 7.2 20.6', 'M5.4 9.8 C6.6 11 7.6 12 8.6 12.8 C9.8 11.8 10.8 10.8 12 9.8', 'M20.2 12.8 C20 15.6 20.4 18.4 20.2 21 C22.4 22.2 24.2 23.4 26 24.6'],
    'settings': ['M6.4 13 C12 12.6 17 13.2 21.6 12.8 C21.8 9.4 26.6 8.8 27.6 11.8 C28.4 14.4 25.4 16.2 23.4 14.6 C22.4 13.8 23.2 12.6 24.4 12.8 C28 13.2 30.6 12.8 33.6 12.8', 'M6.4 27.4 C8.4 27.2 9.8 27.4 11.4 27.2 C11.8 24 16.6 23.6 17.2 26.6 C17.8 29.4 14.6 30.8 12.8 29 C12 28.2 12.8 27 14 27.2 C20.6 27.6 27 26.8 33.6 27'],
    'share': ['M13.4 17 C11.6 17 10.2 17.2 8.8 17.2 C8.8 22.8 9.2 28.4 8.8 34 C16.4 34.2 24 33.6 31.4 33.8 C31.2 28.2 31.4 22.6 31 17 C29.6 17 28.2 17 26.8 17.2', 'M20.2 26.2 C20.4 21.6 19.8 16.6 20.6 12 C21.2 8.8 22.6 6.6 20.4 5.4 C18.8 7.2 16.6 9.4 14.6 11.4', 'M20.6 5.6 C22.4 7.4 24 9.2 25.8 11'],
    'ai': ['M17 6 C17.8 12.6 13.8 17 8 18 C14 19.4 17.2 23.6 17.4 30 C18.4 23.4 22.6 19.6 28 18.2 C22.4 17 18.2 13 17 6', 'M29 27 C29.6 29.6 31 31 33.6 31.6 C31 32.2 29.6 33.6 29 36.2 C28.4 33.6 27 32.2 24.4 31.6'],
    'search': ['M18 29 C11.4 29.2 7.4 24.2 7.8 18.4 C8.2 12.4 13.2 8 19 8.4 C25 8.8 29 13.8 28.6 19.6 C28.4 23 26.6 25.8 24 27.4', 'M25.4 26.4 C27.8 28.8 30.2 31.4 33 34'],
    'back': ['M33 20.6 C26 20.2 18 20.8 9.4 20.4', 'M17 12.4 C14.4 15 12 17.6 9.4 20.4 C12 23.2 14.4 25.8 17.2 28.6'],
  };

  /// Big corner accents drawn behind colored cards (100×100 viewBox).
  static const accents = <String, List<String>>{
    'scan': ['M88 40 C90 62 88 80 84 86 C78 90 60 90 40 88', 'M66 66 C60 66 58 60 62 57 C66 54 71 58 68 63'],
    'upload': ['M30 92 C30 70 32 50 30 30', 'M18 44 C22 40 26 36 30 30 C34 36 38 40 42 44', 'M60 96 C60 80 62 66 60 52', 'M80 94 C80 86 81 80 80 72'],
    'paste': ['M36 52 C26 52 24 40 31 35 C38 30 47 37 43 51 C41 60 34 66 27 70', 'M70 52 C60 52 58 40 65 35 C72 30 81 37 77 51 C75 60 68 66 61 70'],
    'link': ['M20 74 C14 62 22 50 36 50 C52 50 60 60 56 70 C52 78 40 78 34 74', 'M50 64 C46 52 56 44 70 46 C86 48 92 60 86 70 C80 78 66 78 60 72'],
    'score': ['M50 8 C51 38 49 68 50 94', 'M14 28 C40 42 62 58 88 72', 'M14 72 C40 58 62 42 88 28'],
    'flag': ['M16 40 C38 30 60 50 92 38', 'M26 58 C44 50 62 64 86 54', 'M38 76 C52 70 64 80 80 74'],
    'eye': ['M8 64 C28 36 72 36 92 64', 'M50 34 C50 28 51 22 50 14', 'M30 40 C28 34 25 29 21 24', 'M70 40 C72 34 75 29 79 24'],
    'check': ['M12 54 C22 62 30 72 38 84 C54 58 70 36 96 12'],
  };

  static String _hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  static String svg(List<String> ds, Color color, double stroke, int box) {
    final p = ds.map((d) => '<path d="$d"/>').join();
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $box $box" fill="none" '
        'stroke="${_hex(color)}" stroke-width="$stroke" stroke-linecap="round" stroke-linejoin="round">$p</svg>';
  }
}

class LoopyIcon extends StatelessWidget {
  const LoopyIcon(this.name, {super.key, this.size = 30, this.color = const Color(0xFF232120), this.stroke = 2.4, this.only});
  final String name;
  final double size;
  final Color color;
  final double stroke;
  /// Draw only these strokes of the icon (to animate parts separately).
  final List<int>? only;

  @override
  Widget build(BuildContext context) {
    final all = Loopy.paths[name] ?? Loopy.paths['check']!;
    final ds = only == null ? all : [for (final i in only!) if (i < all.length) all[i]];
    return SvgPicture.string(Loopy.svg(ds, color, stroke, 40), width: size, height: size);
  }
}

/// Oversized line accent tucked into a card's corner.
class LoopyAccent extends StatelessWidget {
  const LoopyAccent(this.name, {super.key, required this.color, this.size = 128, this.stroke = 1.6});
  final String name;
  final Color color;
  final double size;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    final ds = Loopy.accents[name];
    if (ds == null) return const SizedBox.shrink();
    // stroke is given in screen px; convert to the 100-unit viewBox.
    final s = stroke * 100 / size;
    return IgnorePointer(child: SvgPicture.string(Loopy.svg(ds, color, s, 100), width: size, height: size));
  }
}

/// The cherry hand-drawn asterisk from the logo: six uneven, slightly bowed
/// legs (not a perfect star, on purpose). Pass [legs] (six 0..1+ values) to
/// grow and shrink each leg, e.g. for the language-change animation.
class BrandAsterisk extends StatelessWidget {
  const BrandAsterisk({super.key, this.size = 12, this.color = const Color(0xFFDF1538), this.legs});
  final double size;
  final Color color;
  final List<double>? legs;
  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(size),
        painter: _AsteriskPainter(color, legs),
      );
}

class _AsteriskPainter extends CustomPainter {
  _AsteriskPainter(this.color, this.legs);
  final Color color;
  final List<double>? legs;

  // (degrees clockwise from up, length, bow) in a 16-unit box.
  static const _legs = [
    (-4.0, 6.9, 0.55),
    (57.0, 6.1, -0.7),
    (121.0, 6.8, 0.45),
    (178.0, 6.3, -0.5),
    (236.0, 7.2, 0.65),
    (299.0, 5.9, -0.45),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 16;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.3 * k;
    const cx = 8.0, cy = 8.1;
    for (var i = 0; i < _legs.length; i++) {
      final (deg, len, bow) = _legs[i];
      final sc = legs == null ? 1.0 : legs![i % legs!.length];
      if (sc <= 0.02) continue;
      final r = deg * math.pi / 180;
      final dx = math.sin(r), dy = -math.cos(r);
      final px = math.cos(r), py = math.sin(r);
      final sx = cx + dx * 0.5, sy = cy + dy * 0.5;
      final ex = cx + dx * len * sc, ey = cy + dy * len * sc;
      final mx = (sx + ex) / 2 + px * bow * sc, my = (sy + ey) / 2 + py * bow * sc;
      canvas.drawPath(
        Path()
          ..moveTo(sx * k, sy * k)
          ..quadraticBezierTo(mx * k, my * k, ex * k, ey * k),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_AsteriskPainter old) => old.color != color || old.legs != legs;
}

/// A loopy icon sitting in a hand-drawn, slightly lumpy bubble (not a
/// perfect circle). The lumps differ per icon so headers don't look stamped.
class IconBlob extends StatelessWidget {
  const IconBlob(this.icon,
      {super.key, this.color = const Color(0xFF232120), this.iconColor = Colors.white, this.size = 42, this.pen = false});
  final String icon;
  /// Draw the icon's little pen move once when the page opens.
  final bool pen;
  final Color color;
  final Color iconColor;
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _BlobPainter(color, icon.codeUnits.fold(7, (h, c) => (h * 31 + c) & 0x7fffffff)),
          child: Center(
            child: pen
                ? PenIcon(icon, size: size * 0.64, color: iconColor, stroke: 2.2, onMount: true)
                : LoopyIcon(icon, size: size * 0.64, color: iconColor, stroke: 2.2),
          ),
        ),
      );
}

class _BlobPainter extends CustomPainter {
  _BlobPainter(this.color, this.seed);
  final Color color;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(seed);
    const n = 7;
    final c = size.center(Offset.zero);
    final base = size.width / 2;
    final turn = rnd.nextDouble() * math.pi;
    final pts = [
      for (var i = 0; i < n; i++)
        c +
            Offset.fromDirection(
              turn + i * 2 * math.pi / n + (rnd.nextDouble() - 0.5) * 0.35,
              base * (0.88 + rnd.nextDouble() * 0.12),
            ),
    ];
    // Smooth closed curve through the points (Catmull-Rom as cubics).
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (var i = 0; i < n; i++) {
      final p0 = pts[(i - 1 + n) % n], p1 = pts[i], p2 = pts[(i + 1) % n], p3 = pts[(i + 2) % n];
      final c1 = p1 + (p2 - p0) / 6, c2 = p2 - (p3 - p1) / 6;
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    canvas.drawPath(path..close(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_BlobPainter old) => old.color != color || old.seed != seed;
}

/// Hand-drawn eye that opens: 0 = closed (a lashed curve), 1 = wide open
/// with a pupil. Used for "watch for changes".
class BlinkEye extends StatelessWidget {
  const BlinkEye({super.key, required this.open, this.size = 26, this.color = const Color(0xFF232120), this.stroke = 2.4});
  final double open;
  final double size;
  final Color color;
  final double stroke;
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _EyePainter(open.clamp(0.0, 1.2), color, stroke));
}

class _EyePainter extends CustomPainter {
  _EyePainter(this.open, this.color, this.stroke);
  final double open;
  final Color color;
  final double stroke;
  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 40;
    canvas.scale(k);
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * 40 / size.width * 0.9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final o = open;
    // Upper lid lifts as it opens; lower lid dips a little.
    final upper = Path()
      ..moveTo(5, 21)
      ..quadraticBezierTo(20, 21 - 16 * o + 6 * (1 - o), 35, 21);
    final lower = Path()
      ..moveTo(5, 21)
      ..quadraticBezierTo(20, 21 + 13 * o + 6 * (1 - o), 35, 21);
    canvas.drawPath(upper, p);
    if (o > 0.05) canvas.drawPath(lower, p);
    // Lashes while closed.
    final lash = (1 - o * 2).clamp(0.0, 1.0);
    if (lash > 0) {
      final lp = Paint()
        ..color = color.withValues(alpha: lash)
        ..style = PaintingStyle.stroke
        ..strokeWidth = p.strokeWidth
        ..strokeCap = StrokeCap.round;
      for (final (x, dx) in const [(12.0, -2.0), (20.0, 0.0), (28.0, 2.0)]) {
        final y = 21 + 4.5 * (1 - (x - 20).abs() / 30);
        canvas.drawLine(Offset(x, y), Offset(x + dx, y + 4), lp);
      }
    }
    // Pupil grows in.
    if (o > 0.2) {
      canvas.drawCircle(const Offset(20, 21), 4.6 * ((o - 0.2) / 0.8).clamp(0.0, 1.0), p);
      canvas.drawCircle(const Offset(20.6, 21), 1.4 * ((o - 0.4) / 0.6).clamp(0.0, 1.0), Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_EyePainter o) => o.open != open || o.color != color;
}

/// The bin with a lid that lifts while pressed and bobs when tapped.
class LidTrash extends StatelessWidget {
  const LidTrash({super.key, required this.lift, this.size = 24, this.color = Colors.white, this.stroke = 2.4});
  final double lift; // 0 closed .. 1 lifted
  final double size;
  final Color color;
  final double stroke;
  @override
  Widget build(BuildContext context) {
    final ds = Loopy.paths['trash']!;
    return SizedBox.square(
      dimension: size,
      child: Stack(clipBehavior: Clip.none, children: [
        SvgPicture.string(Loopy.svg(ds.sublist(2), color, stroke, 40), width: size, height: size),
        Transform.translate(
          offset: Offset(0, -size * 0.12 * lift),
          child: Transform.rotate(
            angle: -0.32 * lift,
            alignment: const Alignment(-0.6, -0.4),
            child: SvgPicture.string(Loopy.svg(ds.sublist(0, 2), color, stroke, 40), width: size, height: size),
          ),
        ),
      ]),
    );
  }
}

class _PathMaker extends PathProxy {
  final path = Path();
  @override
  void moveTo(double x, double y) => path.moveTo(x, y);
  @override
  void lineTo(double x, double y) => path.lineTo(x, y);
  @override
  void cubicTo(double x1, double y1, double x2, double y2, double x3, double y3) =>
      path.cubicTo(x1, y1, x2, y2, x3, y3);
  @override
  void close() => path.close();
}

final Map<String, Path> _parsed = {};
Path _svgPath(String d) => _parsed.putIfAbsent(d, () {
      final m = _PathMaker();
      writeSvgPathDataToPath(d, m);
      return m.path;
    });

/// A loopy icon drawn stroke by stroke, so parts can be re-drawn (pen
/// effect) or nudged. [progress]: how much of each stroke is drawn (0..1,
/// missing = whole). [shift]: per-stroke offset in the 40-unit box.
class DrawnLoopy extends StatelessWidget {
  const DrawnLoopy(this.name,
      {super.key, this.size = 30, this.color = const Color(0xFF232120), this.stroke = 2.4, this.progress = const {}, this.shift = const {}});
  final String name;
  final double size;
  final Color color;
  final double stroke;
  final Map<int, double> progress;
  final Map<int, Offset> shift;
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _DrawnPainter(Loopy.paths[name] ?? const [], color, stroke, progress, shift));
}

class _DrawnPainter extends CustomPainter {
  _DrawnPainter(this.ds, this.color, this.stroke, this.progress, this.shift);
  final List<String> ds;
  final Color color;
  final double stroke;
  final Map<int, double> progress;
  final Map<int, Offset> shift;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 40);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (var i = 0; i < ds.length; i++) {
      var p = _svgPath(ds[i]);
      final s = shift[i];
      if (s != null) p = p.shift(s);
      final f = (progress[i] ?? 1).clamp(0.0, 1.0);
      if (f <= 0) continue;
      if (f >= 1) {
        canvas.drawPath(p, paint);
        continue;
      }
      for (final m in p.computeMetrics()) {
        canvas.drawPath(m.extractPath(0, m.length * f), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DrawnPainter o) => true;
}


/// A loopy icon that re-draws part of itself like a pen whenever [play]
/// changes (and once when it first appears, if [onMount]): scan's circle,
/// upload's arrow dips and rises, paste's scribble writes left to right, the
/// link loop, the settings knobs slide across.
class PenIcon extends StatefulWidget {
  const PenIcon(this.icon,
      {super.key, this.size = 30, this.color = const Color(0xFF232120), this.stroke = 2.4, this.play = 0, this.onMount = false});
  final String icon;
  final double size;
  final Color color;
  final double stroke;
  final int play;
  final bool onMount;
  @override
  State<PenIcon> createState() => _PenIconState();
}

class _PenIconState extends State<PenIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 560));

  @override
  void initState() {
    super.initState();
    if (widget.onMount) Future.delayed(const Duration(milliseconds: 220), () {
      if (mounted) _go();
    });
  }

  void _go() {
    if (!MediaQuery.disableAnimationsOf(context)) _c.forward(from: 0);
  }

  @override
  void didUpdateWidget(PenIcon old) {
    super.didUpdateWidget(old);
    if (old.play != widget.play) _go();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final moving = _c.isAnimating;
          final t = _c.value;
          final v = Curves.easeInOut.transform(t);
          final progress = <int, double>{};
          final shift = <int, Offset>{};
          if (moving) {
            switch (widget.icon) {
              case 'scan':
                progress[4] = v;
              case 'upload':
                final y = t < 0.3
                    ? 5 * math.sin(t / 0.3 * math.pi / 2)
                    : t < 0.7
                        ? 5 - 12 * Curves.easeOut.transform((t - 0.3) / 0.4)
                        : -7 * (1 - Curves.easeOut.transform((t - 0.7) / 0.3));
                shift[1] = Offset(0, y);
              case 'paste':
                progress[1] = v;
              case 'link':
                progress[0] = v;
            }
          }
          return DrawnLoopy(widget.icon,
              size: widget.size, color: widget.color, stroke: widget.stroke, progress: progress, shift: shift);
        },
      );
}
