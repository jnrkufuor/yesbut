import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// YesBut's hand-drawn, single-line icon set (40×40 viewBox).
class Loopy {
  static const paths = <String, List<String>>{
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
  const LoopyIcon(this.name, {super.key, this.size = 30, this.color = const Color(0xFF232120), this.stroke = 2.4});
  final String name;
  final double size;
  final Color color;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    final ds = Loopy.paths[name] ?? Loopy.paths['check']!;
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

/// The cherry hand-drawn asterisk from the logo.
class BrandAsterisk extends StatelessWidget {
  const BrandAsterisk({super.key, this.size = 12, this.color = const Color(0xFFF51D3A)});
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => SvgPicture.string(
        Loopy.svg(const ['M8 1.6 L8.2 14.4', 'M2.3 4.7 L13.7 11.4', 'M2.5 11.7 L13.5 4.3'], color, 3, 16),
        width: size,
        height: size,
      );
}
