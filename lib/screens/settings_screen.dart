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
import 'anywhere_screen.dart';
import 'our_terms_screen.dart';

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
              const IconBlob('settings', size: 40),
            ]),
            const SizedBox(height: 28),
            const HeadingText('Make it ', serif: 'yours', size: 36),
            const SizedBox(height: 18),

            const _Label('READER'),
            _Group(children: [
              _Row(
                title: 'Who reads your terms',
                trailing: _Dropdown(
                  value: st.engine.name,
                  items: const {'deepseek': 'DeepSeek', 'gemini': 'Gemini', 'claude': 'Claude', 'offline': 'On your phone'},
                  onChanged: (v) => set(st.copyWith(engine: EngineChoice.values.byName(v))),
                ),
              ),
              _Note(
                  switch (st.engine) {
                    EngineChoice.offline => 'Quick and private. Your terms never leave your phone.',
                    EngineChoice.claude => st.apiKey.trim().isEmpty
                        ? 'Anthropic’s Claude, with your own API key. Add it below.'
                        : 'Anthropic’s Claude, using your own API key. Anthropic bills you for what you use.',
                    EngineChoice.deepseek => AppState.readers[EngineChoice.deepseek]!.available
                        ? 'A free AI that reads every document closely. Takes a few seconds.'
                        : 'Not switched on yet, so your phone reads for now.',
                    _ => AppState.readers[EngineChoice.gemini]!.available
                        ? 'Google’s free AI. Reads every document closely and fast.'
                        : 'Not switched on yet, so your phone reads for now.',
                  },
              ),
              if (st.engine == EngineChoice.claude) _ClaudeSetup(settings: st, onChanged: set),
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
              const _Note('Translated on your phone. Each language downloads once (about 30 MB), then works offline.'),
            ]),

            const _Label('FROM OTHER APPS'),
            _Group(children: [
              _Row(
                title: 'Use it anywhere',
                body: 'Highlight text, check a screen as you scroll, or share.',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AnywhereScreen())),
                trailing: const Icon(Icons.chevron_right_rounded, color: GColors.inkSoft),
              ),
            ]),

            const _Label('ACCESSIBILITY'),
            _Group(children: [
              _TextSize(value: st.textScale, onChanged: (v) => set(st.copyWith(textScale: v))),
              _Row(
                title: 'Bold text',
                body: 'Heavier letters for stronger contrast.',
                trailing: _Switch(st.boldText, (v) => set(st.copyWith(boldText: v))),
              ),
              _Row(
                title: 'Reduce motion',
                trailing: _Switch(st.reduceMotion, (v) => set(st.copyWith(reduceMotion: v))),
              ),
              _Row(
                title: 'Sound effects',
                body: 'A little chime when results land.',
                trailing: _Switch(st.sounds, (v) => set(st.copyWith(sounds: v))),
              ),
              _Row(
                title: 'Vibration',
                body: 'A soft tap when something finishes.',
                trailing: _Switch(st.haptics, (v) => set(st.copyWith(haptics: v))),
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
              _Row(
                title: 'Our terms & privacy',
                body: 'How your data is used, in plain words.',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OurTermsScreen())),
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
              Text('v0.7.0', style: TextStyle(color: GColors.inkFaint, fontSize: 12)),
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
        padding: const EdgeInsets.fromLTRB(4, 26, 4, 8),
        child: Text(text,
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: GColors.inkSoft)),
      );
}

/// Rounded group with hairline dividers between rows.
/// Small grey explainer under a row, below the divider, aligned with the
/// row titles.
class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Text(text, textAlign: TextAlign.left, style: const TextStyle(fontSize: 12.5, height: 1.45, color: GColors.inkSoft)),
        ),
      );
}

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


/// Text size: a slider from smaller to larger, with a live "Aa" preview.
class _TextSize extends StatelessWidget {
  const _TextSize({required this.value, required this.onChanged});
  final double value;
  final ValueChanged<double> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Text size', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          Row(children: [
            const Text('A', translate: false, style: TextStyle(fontSize: 13, color: GColors.inkSoft)),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: GColors.ink,
                  inactiveTrackColor: GColors.line,
                  thumbColor: GColors.ink,
                  overlayColor: GColors.ink.withValues(alpha: 0.08),
                  trackHeight: 2,
                  activeTickMarkColor: GColors.white,
                  inactiveTickMarkColor: GColors.inkFaint,
                ),
                child: Slider(
                  value: value.clamp(0.85, 1.4),
                  min: 0.85,
                  max: 1.4,
                  divisions: 11,
                  label: '${(value * 100).round()}%',
                  onChanged: onChanged,
                ),
              ),
            ),
            const Text('A', translate: false, style: TextStyle(fontSize: 22, color: GColors.inkSoft)),
          ]),
        ]),
      );
}

/// Claude needs your own API key (from console.anthropic.com) and a model.
class _ClaudeSetup extends StatefulWidget {
  const _ClaudeSetup({required this.settings, required this.onChanged});
  final AppSettings settings;
  final ValueChanged<AppSettings> onChanged;
  @override
  State<_ClaudeSetup> createState() => _ClaudeSetupState();
}

class _ClaudeSetupState extends State<_ClaudeSetup> {
  late final _key = TextEditingController(text: widget.settings.apiKey);
  bool _show = false;

  static const _models = {
    'claude-haiku-5-5': 'Haiku (fastest)',
    'claude-sonnet-5-5': 'Sonnet (balanced)',
    'claude-opus-5-5': 'Opus (most careful)',
  };

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.settings;
    final model = _models.containsKey(st.model) ? st.model : 'claude-sonnet-5-5';
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
          controller: _key,
          obscureText: !_show,
          autocorrect: false,
          enableSuggestions: false,
          onChanged: (v) => widget.onChanged(st.copyWith(apiKey: v.trim())),
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: context.tr('Your Anthropic API key (sk-ant-…)'),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: const BorderSide(color: GColors.line)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: const BorderSide(color: GColors.line)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: const BorderSide(color: GColors.ink)),
            suffixIcon: IconButton(
              tooltip: _show ? 'Hide key' : 'Show key',
              icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: GColors.inkSoft),
              onPressed: () => setState(() => _show = !_show),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          const Expanded(child: Text('Model', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
          _Dropdown(value: model, items: _models, onChanged: (v) => widget.onChanged(st.copyWith(model: v))),
        ]),
        const SizedBox(height: 8),
        const Text(
          'Get a key at console.anthropic.com. It’s stored only on this phone and sent only to Anthropic.',
          style: TextStyle(fontSize: 12.5, height: 1.4, color: GColors.inkSoft),
        ),
      ]),
    );
  }
}
