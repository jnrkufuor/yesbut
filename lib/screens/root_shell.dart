import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/loopy.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'library_screen.dart';

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
    return Scaffold(
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
            child: KeyedSubtree(
              key: ValueKey(_index),
              child: switch (_index) {
                1 => const LibraryScreen(),
                2 => const HistoryScreen(),
                _ => HomeScreen(onSeeLibrary: () => _go(1), onSeeHistory: () => _go(2)),
              },
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 22 + bottom,
          child: Center(child: PillNav(index: _index, onTap: _go)),
        ),
      ]),
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

class _PillNavState extends State<PillNav> {
  static const _icons = ['check', 'library', 'history'];
  static const _labels = ['Check', 'Library', 'History'];
  static const _w = 306.0;
  static const _btn = 52.0;
  bool _moving = false;

  @override
  void didUpdateWidget(PillNav old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      setState(() => _moving = true);
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) setState(() => _moving = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const gap = (_w - 20 - _btn * 3) / 2;
    return Container(
      width: _w,
      height: 70,
      decoration: BoxDecoration(
        color: GColors.ink,
        borderRadius: BorderRadius.circular(99),
        boxShadow: [BoxShadow(color: GColors.ink.withValues(alpha: 0.18), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Stack(children: [
        AnimatedPositioned(
          duration: const Duration(milliseconds: 420),
          curve: const Cubic(0.3, 1.3, 0.5, 1),
          left: 10 + widget.index * (_btn + gap),
          top: 9,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 200),
            scale: _moving ? 1.12 : 1,
            child: Container(
              width: _btn,
              height: _btn,
              decoration: const BoxDecoration(color: GColors.white, shape: BoxShape.circle),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            for (var i = 0; i < 3; i++)
              Semantics(
                button: true,
                selected: i == widget.index,
                label: _labels[i],
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => widget.onTap(i),
                  child: SizedBox(
                    width: _btn,
                    height: _btn,
                    child: Center(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(end: i == widget.index ? 1 : 0),
                        duration: const Duration(milliseconds: 260),
                        builder: (context, v, _) => LoopyIcon(
                          _icons[i],
                          size: 30,
                          color: Color.lerp(GColors.white, GColors.ink, v)!,
                          stroke: 2.4 + 0.9 * v,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ]),
    );
  }
}
