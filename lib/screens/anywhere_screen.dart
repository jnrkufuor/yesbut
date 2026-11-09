import 'package:flutter/material.dart' hide Text;
import '../i18n/text.dart';

import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/loopy.dart';
import 'home_screen.dart' show RoundIconButton;

/// How to check terms without leaving the app you're in.
class AnywhereScreen extends StatelessWidget {
  const AnywhereScreen({super.key});

  static const _ways = <(String, Color, String, String, List<String>)>[
    ('paste', GColors.green, 'Highlight the text', 'Works in browsers and most apps.', [
      'Press and hold on the terms, then drag to select them.',
      'In the menu that pops up, tap Yes, but. If you don’t see it, tap ⋮ for more options.',
    ]),
    ('scan', GColors.red, 'Check this screen', 'For long terms you scroll through.', [
      'Add the button once: swipe down twice, tap the pencil, and drag Check this screen into your quick settings.',
      'On a terms page, swipe down and tap it. Android asks to share your screen. Choose the app you’re in.',
      'Scroll through the terms at an easy pace. We keep a picture each time the page stops moving.',
      'At the end, tap the button again, or Done in the notification. We read the pictures on your phone and delete them after.',
    ]),
    ('share', GColors.blue, 'Share it to us', 'Screenshots, PDFs and links.', [
      'Tap Share in any app and pick Yes,But.',
      'Tip: many phones can take one long screenshot. Take a screenshot, tap Capture more, then share it.',
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
          children: staggered([
            Row(children: [
              RoundIconButton(icon: 'back', onTap: () => Navigator.of(context).maybePop()),
              const Spacer(),
            ]),
            const SizedBox(height: 28),
            const HeadingText('Use it ', serif: 'anywhere', size: 36),
            const SizedBox(height: 8),
            const Text('Check terms without leaving the app you’re in.',
                style: TextStyle(fontSize: 14, height: 1.45, color: GColors.inkSoft)),
            const SizedBox(height: 20),
            for (final w in _ways) ...[
              _Way(icon: w.$1, color: w.$2, title: w.$3, lead: w.$4, steps: w.$5),
              const SizedBox(height: 12),
            ],
          ]),
        ),
      ),
    );
  }
}

class _Way extends StatelessWidget {
  const _Way({required this.icon, required this.color, required this.title, required this.lead, required this.steps});
  final String icon;
  final Color color;
  final String title;
  final String lead;
  final List<String> steps;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: GColors.line, width: 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            IconBlob(icon, color: color, iconColor: color == GColors.green ? GColors.ink : Colors.white, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title,
                    style: const TextStyle(
                        fontFamily: AppTheme.display, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.4)),
                const SizedBox(height: 2),
                Text(lead, style: const TextStyle(fontSize: 12.5, color: GColors.inkSoft)),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                  width: 22,
                  child: Text('${i + 1}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: GColors.red, height: 1.45)),
                ),
                Expanded(child: Text(steps[i], style: const TextStyle(fontSize: 13.5, height: 1.45))),
              ]),
            ),
        ]),
      );
}
