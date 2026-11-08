import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/storage.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/dialogs.dart';
import '../widgets/loopy.dart';
import 'home_screen.dart' show RoundIconButton;

/// Compact settings. Changes save as you make them.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _langs = {
    'en': 'English',
    'fr': 'Français',
    'es': 'Español',
    'de': 'Deutsch',
    'pt': 'Português',
    'it': 'Italiano',
  };

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final st = state.settings;
    void set(AppSettings s) => state.updateSettings(s);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
          children: staggered([
            Row(children: [
              RoundIconButton(icon: 'back', onTap: () => Navigator.of(context).maybePop()),
              const SizedBox(width: 12),
              const LoopyIcon('settings', size: 26, stroke: 2.6),
              const SizedBox(width: 8),
              const Text('Settings',
                  style: TextStyle(
                      fontFamily: AppTheme.display, fontSize: 25, fontWeight: FontWeight.w700, letterSpacing: -1, height: 1)),
            ]),
            const SizedBox(height: 28),
            const HeadingText('Make it ', serif: 'yours', size: 36),
            const SizedBox(height: 18),

            const _Label('READING'),
            _Group(children: [
              const _Row(
                title: 'On your phone',
                body: 'Private and instant. Nothing leaves your phone.',
                trailing: Icon(Icons.check_circle_rounded, color: GColors.ink, size: 22),
              ),
              Opacity(
                opacity: 0.4,
                child: _Row(
                  title: 'AI reading',
                  body: 'Deeper, document-specific breakdowns.',
                  trailing: _Soon(),
                ),
              ),
            ]),

            const _Label('RESULTS LANGUAGE'),
            _Group(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                child: Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final e in _langs.entries)
                    _Pill(
                      text: e.value,
                      selected: st.resultLanguage == e.key,
                      onTap: () => set(st.copyWith(resultLanguage: e.key)),
                    ),
                ]),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(14, 6, 14, 12),
                child: Text(
                  'Terms in these languages are translated on your phone. Each language downloads once (about 30 MB), then works offline.',
                  style: TextStyle(fontSize: 12.5, height: 1.4, color: GColors.inkSoft),
                ),
              ),
            ]),

            const _Label('ACCESSIBILITY'),
            _Group(children: [
              _Row(
                title: 'Larger text',
                trailing: _Switch(st.largerText, (v) => set(st.copyWith(largerText: v))),
              ),
              _Row(
                title: 'Bold text',
                body: 'Heavier letters for stronger contrast.',
                trailing: _Switch(st.boldText, (v) => set(st.copyWith(boldText: v))),
              ),
              _Row(
                title: 'Reduce motion',
                trailing: _Switch(st.reduceMotion, (v) => set(st.copyWith(reduceMotion: v))),
              ),
              const Opacity(
                opacity: 0.4,
                child: _Row(title: 'Read results aloud', trailing: _Soon()),
              ),
            ]),

            const _Label('YOUR DATA'),
            _Group(children: [
              _Row(
                title: 'Clear history',
                body: '${state.history.length} saved check${state.history.length == 1 ? '' : 's'}',
                onTap: () => showClearHistorySheet(context),
                trailing: const Icon(Icons.chevron_right_rounded, color: GColors.inkSoft),
              ),
            ]),

            const SizedBox(height: 18),
            const Text(
              'YesBut explains contracts in everyday language. It isn’t a lawyer and can miss things. '
              'For leases, loans, jobs or anything big, get proper legal advice.',
              style: TextStyle(color: GColors.inkSoft, fontSize: 12.5, height: 1.45),
            ),
            const SizedBox(height: 18),
            const Row(children: [
              Wordmark(size: 18),
              Spacer(),
              Text('v0.5.0', style: TextStyle(color: GColors.inkFaint, fontSize: 12)),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
        child: Text(text,
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: GColors.inkSoft)),
      );
}

/// Rounded group with hairline dividers between rows.
class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: GColors.line, width: 1),
        ),
        child: Column(children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, thickness: 1, color: GColors.line, indent: 14, endIndent: 14),
            children[i],
          ],
        ]),
      );
}

class _Row extends StatelessWidget {
  const _Row({required this.title, this.body, this.trailing, this.onTap});
  final String title;
  final String? body;
  final Widget? trailing;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => MergeSemantics(
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  if (body != null) ...[
                    const SizedBox(height: 2),
                    Text(body!, style: const TextStyle(fontSize: 12.5, color: GColors.inkSoft)),
                  ],
                ]),
              ),
              if (trailing != null) trailing!,
            ]),
          ),
        ),
      );
}

class _Switch extends StatelessWidget {
  const _Switch(this.value, this.onChanged);
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: GColors.white,
        activeTrackColor: GColors.ink,
      );
}

class _Soon extends StatelessWidget {
  const _Soon();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: GColors.surface, borderRadius: BorderRadius.circular(99)),
        child: const Text('Coming soon', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
      );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.selected, required this.onTap});
  final String text;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? GColors.ink : GColors.white,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: GColors.ink, width: 1),
          ),
          child: Text(text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? GColors.white : GColors.ink,
              )),
        ),
      );
}
