import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/analysis.dart';
import '../theme/app_theme.dart';
import 'loopy.dart';

/// Squishy press feedback used for every tappable card.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.scale = 0.96});
  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// The wordmark: "yes," (Bricolage) + "but" (Newsreader italic) + cherry asterisk.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.size = 25, this.color = GColors.ink});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('yes,',
            style: TextStyle(
              fontFamily: AppTheme.display,
              fontSize: size,
              fontWeight: FontWeight.w700,
              letterSpacing: -size * 0.04,
              color: color,
              height: 1,
            )),
        SizedBox(width: size * 0.04),
        Text('but',
            style: TextStyle(
              fontFamily: AppTheme.serif,
              fontStyle: FontStyle.italic,
              fontSize: size * 1.1,
              letterSpacing: -size * 0.02,
              color: color,
              height: 0.95,
            )),
        Padding(
          padding: EdgeInsets.only(left: size * 0.04, top: 0),
          child: BrandAsterisk(size: size * 0.48),
        ),
      ],
    );
  }
}

/// Loud primary button.
class BigButton extends StatelessWidget {
  const BigButton({
    super.key,
    required this.label,
    required this.onTap,
    this.color = GColors.ink,
    this.icon,
    this.busy = false,
  });
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final IconData? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !busy;
    final fg = enabled ? GColors.onColor(color) : GColors.inkFaint;
    return Pressable(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 58,
        decoration: BoxDecoration(
          color: enabled ? color : GColors.surface,
          borderRadius: BorderRadius.circular(99),
        ),
        alignment: Alignment.center,
        child: busy
            ? SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.6, color: fg))
            : Row(mainAxisSize: MainAxisSize.min, children: [
                Text(label,
                    style: TextStyle(
                      fontFamily: AppTheme.display,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: fg,
                    )),
                if (icon != null) ...[
                  const SizedBox(width: 8),
                  Icon(icon, size: 20, color: fg),
                ],
              ]),
      ),
    );
  }
}

class SeverityPill extends StatelessWidget {
  const SeverityPill(this.severity, {super.key, this.count});
  final Severity severity;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final c = GColors.textForSeverity(severity);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 11, 5),
      decoration: BoxDecoration(
        color: GColors.softForSeverity(severity),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(severityIcon(severity), size: 14, color: c),
        const SizedBox(width: 5),
        Text(
          count == null ? severity.label : '$count ${severity.label}${count == 1 ? '' : 's'}',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: c),
        ),
      ]),
    );
  }
}

/// Animated score ring (0–100).
class ScoreRing extends StatelessWidget {
  const ScoreRing({super.key, required this.score, this.size = 120, this.stroke = 13});
  final int score;
  final double size;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    final color = GColors.forScore(score);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: score / 100),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(v, color, stroke),
          child: Center(
            child: Text('${(v * 100).round()}',
                style: TextStyle(
                  fontSize: size * 0.34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -size * 0.02,
                  color: GColors.ink,
                  height: 1,
                )),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, this.color, this.stroke);
  final double value;
  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    final bg = Paint()
      ..color = GColors.white.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final fg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;
    canvas.drawArc(r, 0, math.pi * 2, false, bg);
    canvas.drawArc(r, -math.pi / 2, math.pi * 2 * value, false, fg);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value || old.color != color;
}

/// Three hopping dots in brand colors — our loader.
class HopDots extends StatefulWidget {
  const HopDots({super.key, this.size = 18});
  final double size;
  @override
  State<HopDots> createState() => _HopDotsState();
}

class _HopDotsState extends State<HopDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const colors = [GColors.red, GColors.green, GColors.blue];
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final t = (_c.value - i * 0.16) % 1.0;
          final hop = t < 0.4 ? math.sin(t / 0.4 * math.pi) : 0.0;
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: widget.size * 0.28),
            child: Transform.translate(
              offset: Offset(0, -hop * widget.size * 1.1),
              child: Transform.scale(
                scaleY: 1 - hop * 0.1 + (t > 0.4 && t < 0.48 ? -0.15 : 0),
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(color: colors[i], shape: BoxShape.circle),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
      child: Row(children: [
        Expanded(child: Text(text, style: Theme.of(context).textTheme.titleLarge)),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

/// Soft rounded container.
class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.color = GColors.surface,
    this.padding = const EdgeInsets.all(18),
    this.radius = GRadius.lg,
  });
  final Widget child;
  final Color color;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(radius)),
        child: child,
      );
}

/// Circle badge with a letter — used for library logos (no trademarks bundled).
class LetterBadge extends StatelessWidget {
  const LetterBadge({super.key, required this.letter, required this.color, this.size = 46});
  final String letter;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text(letter,
            style: TextStyle(
              color: GColors.onColor(color),
              fontWeight: FontWeight.w800,
              fontSize: size * 0.46,
              height: 1,
            )),
      );
}

String timeAgo(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inHours < 1) return '${d.inMinutes}m ago';
  if (d.inDays < 1) return '${d.inHours}h ago';
  if (d.inDays < 7) return '${d.inDays}d ago';
  return '${t.day}/${t.month}/${t.year}';
}

void showToast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}


/// "Sniffing" loader: a loopy magnifier sweeps over lines of fine print and
/// lights up the bits it finds. Used while searching and analyzing.
class SniffLoader extends StatefulWidget {
  const SniffLoader({super.key, this.height = 220, this.background = GColors.surface});
  final double height;
  final Color background;
  @override
  State<SniffLoader> createState() => _SniffLoaderState();
}

class _SniffLoaderState extends State<SniffLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat();

  static const _widths = [0.92, 0.74, 0.86, 0.6, 0.95, 0.7, 0.82, 0.55, 0.9];
  static const _hits = {1: GColors.green, 4: GColors.red, 7: GColors.blue};

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(color: widget.background, borderRadius: BorderRadius.circular(32)),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth;
        final h = box.maxHeight;
        return AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            // Figure-eight-ish path across the page.
            final x = (math.sin(t * math.pi * 2) * 0.38 + 0.5) * w;
            final y = (math.sin(t * math.pi * 4) * 0.28 + 0.48) * h;
            final rows = <Widget>[];
            final lineGap = (h - 48) / _widths.length;
            for (var i = 0; i < _widths.length; i++) {
              final ly = 24 + i * lineGap;
              final near = (ly - y).abs() < 34;
              final hit = _hits[i];
              rows.add(Positioned(
                left: 24,
                top: ly,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  width: (w - 48) * _widths[i],
                  height: 8,
                  decoration: BoxDecoration(
                    color: hit != null && near ? hit : GColors.line,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ));
            }
            final tilt = math.sin(t * math.pi * 2) * 0.18;
            return Stack(children: [
              ...rows,
              Positioned(
                left: x - 46,
                top: y - 46,
                child: Transform.rotate(
                  angle: tilt,
                  child: SizedBox(
                    width: 104,
                    height: 104,
                    child: Stack(children: [
                      Positioned(
                        left: 18,
                        top: 18,
                        child: Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: GColors.white.withValues(alpha: 0.55),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const LoopyIcon('search', size: 104, stroke: 1.6),
                    ]),
                  ),
                ),
              ),
            ]);
          },
        );
      }),
    );
  }
}

/// Section heading in Bricolage, optionally with a trailing action.
class HeadingText extends StatelessWidget {
  const HeadingText(this.lead, {super.key, this.serif, this.size = 34});
  final String lead;
  final String? serif;
  final double size;
  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.headlineLarge!.copyWith(fontSize: size);
    return Text.rich(TextSpan(children: [
      TextSpan(text: lead),
      if (serif != null) TextSpan(text: serif, style: AppTheme.serifOf(base)),
    ]), style: base);
  }
}

/// The home screen's load-in, reusable: fades + rises in after a short
/// stagger based on [index]. Wrap each block of a page in one.
class FadeInUp extends StatefulWidget {
  const FadeInUp({super.key, required this.index, required this.child, this.rise = 14, this.pop = false});
  final int index;
  final Widget child;
  final double rise;
  final bool pop;
  @override
  State<FadeInUp> createState() => _FadeInUpState();
}

class _FadeInUpState extends State<FadeInUp> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 620));
  late final Animation<double> _move = CurvedAnimation(parent: _c, curve: Curves.easeOutBack);
  late final Animation<double> _fade = CurvedAnimation(parent: _c, curve: const Interval(0, 0.6));

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 60 + 70 * widget.index.clamp(0, 10)), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _c.value = 1; // reduce motion
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, child) => Opacity(
          opacity: _fade.value,
          child: Transform.translate(
            offset: Offset(0, (1 - _move.value) * (widget.pop ? 26 : widget.rise)),
            child: Transform.scale(scale: widget.pop ? 0.9 + 0.1 * _move.value : 1, child: child),
          ),
        ),
        child: widget.child,
      );
}

/// Wraps each item of [children] in a [FadeInUp] with increasing delay.
List<Widget> staggered(List<Widget> children, {int start = 0}) => [
      for (var i = 0; i < children.length; i++)
        children[i] is SizedBox ? children[i] : FadeInUp(index: start + i, child: children[i]),
    ];
