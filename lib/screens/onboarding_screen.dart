import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Wordmark(size: 30),
            const Spacer(),
            Text('Read the fine print.\nWithout reading\nthe fine print.', style: t.displayMedium?.copyWith(fontSize: 38)),
            const SizedBox(height: 26),
            const _Bullet(color: GColors.red, icon: Icons.flag_rounded, text: 'Red flags that could cost you'),
            const _Bullet(color: GColors.blue, icon: Icons.lightbulb_rounded, text: 'Heads-ups worth knowing'),
            const _Bullet(color: GColors.green, icon: Icons.thumb_up_alt_rounded, text: 'The good stuff, too'),
            const Spacer(),
            BigButton(
              label: 'Let\'s go',
              icon: Icons.arrow_forward_rounded,
              onTap: () => context.read<AppState>().finishOnboarding(),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text('Not legal advice. Just really fast reading.',
                  style: t.bodySmall?.copyWith(color: GColors.inkFaint)),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.color, required this.icon, required this.text});
  final Color color;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(13)),
            child: Icon(icon, color: GColors.onColor(color), size: 19),
          ),
          const SizedBox(width: 14),
          Text(text, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700)),
        ]),
      );
}
