import 'package:flutter/material.dart' hide Text;
import '../i18n/text.dart';
import 'package:provider/provider.dart';

import '../services/storage.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/dialogs.dart';
import '../widgets/loopy.dart';
import 'home_screen.dart' show RoundIconButton;
import 'language_switch_screen.dart';

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
              const Spacer(),
              const Text('Settings',
                  style: TextStyle(
                      fontFamily: AppTheme.display, fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -1.1, height: 1)),
              const SizedBox(width: 8),
              const LoopyIcon('settings', size: 28, stroke: 2.6),
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

            const _Label('LANGUAGE'),
            _Group(children: [
              _Row(
                title: 'App language',
                body: 'Changes the whole app, results and searches.',
                trailing: _Dropdown(
                  value: st.resultLanguage,
                  items: _langs,
                  onChanged: (v) {
                    if (v == st.resultLanguage) return;
                    Navigator.of(context).push(PageRouteBuilder(
                      opaque: true,
                      transitionDuration: const Duration(milliseconds: 300),
                      pageBuilder: (_, __, ___) => LanguageSwitchScreen(code: v, name: _langs[v] ?? v),
                      transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
                    ));
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Text(
                  'Translated on your phone. Each language downloads once (about 30 MB), then works offline.',
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

/// Brand toggle: always a white track. On = charcoal border + charcoal knob
/// on the right; off = grey border + grey knob on the left.
class _Switch extends StatelessWidget {
  const _Switch(this.value, this.onChanged);
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Semantics(
        toggled: value,
        child: GestureDetector(
          onTap: () => onChanged(!value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 50,
            height: 30,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: GColors.white,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: value ? GColors.ink : GColors.line, width: 1.2),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 20,
                height: 20,
                decoration: BoxDecoration(color: value ? GColors.ink : GColors.line, shape: BoxShape.circle),
              ),
            ),
          ),
        ),
      );
}

/// Compact outlined dropdown in the brand style.
class _Dropdown extends StatelessWidget {
  const _Dropdown({required this.value, required this.items, required this.onChanged});
  final String value;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
        initialValue: value,
        onSelected: onChanged,
        color: GColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: GColors.line),
        ),
        itemBuilder: (_) => [
          for (final e in items.entries)
            PopupMenuItem(
              value: e.key,
              child: Row(children: [
                Expanded(child: Text(e.value, style: const TextStyle(fontSize: 14))),
                if (e.key == value) const Icon(Icons.check_rounded, size: 18),
              ]),
            ),
        ],
        child: Container(
          height: 36,
          padding: const EdgeInsets.fromLTRB(13, 0, 8, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: GColors.ink, width: 1),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(items[value] ?? value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const Icon(Icons.expand_more_rounded, size: 18),
          ]),
        ),
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
