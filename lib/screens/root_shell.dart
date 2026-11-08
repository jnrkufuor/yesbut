import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/dialogs.dart';
import '../widgets/loopy.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'library_screen.dart';
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
            child: KeyedSubtree(
              key: ValueKey(_index),
              child: switch (_index) {
                1 => const SearchScreen(embedded: true),
                2 => const LibraryScreen(),
                3 => const HistoryScreen(),
                _ => HomeScreen(
                    onSeeLibrary: () => _go(2),
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
          child: Center(child: PillNav(index: _index, onTap: _go)),
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

class _PillNavState extends State<PillNav> {
  static const _icons = ['check', 'search', 'library', 'history'];
  static const _labels = ['Check', 'Search', 'Library', 'History'];
  static const _w = 330.0;
  static const _h = 70.0;
  static const _btn = 52.0;
  static const _pad = 9.0; // same inset on every side so the circle sits dead centre
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

  double _x(int i) {
    const gap = (_w - _pad * 2 - _btn * 4) / 3;
    return _pad + i * (_btn + gap);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _w,
      height: _h,
      decoration: BoxDecoration(
        color: GColors.ink,
        borderRadius: BorderRadius.circular(99),
        boxShadow: [BoxShadow(color: GColors.ink.withValues(alpha: 0.18), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Stack(children: [
        AnimatedPositioned(
          duration: const Duration(milliseconds: 420),
          curve: const Cubic(0.3, 1.3, 0.5, 1),
          left: _x(widget.index),
          top: (_h - _btn) / 2,
          width: _btn,
          height: _btn,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 200),
            scale: _moving ? 1.1 : 1,
            child: const DecoratedBox(
              decoration: BoxDecoration(color: GColors.white, shape: BoxShape.circle),
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
                    builder: (context, v, _) => LoopyIcon(
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
      ]),
    );
  }
}
