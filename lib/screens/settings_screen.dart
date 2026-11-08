import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/storage.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/dialogs.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final AppState _state = context.read<AppState>();
  late EngineChoice _engine = _state.settings.engine;
  late final _key = TextEditingController(text: _state.settings.apiKey);
  late final _model = TextEditingController(text: _state.settings.model);
  late final _endpoint = TextEditingController(text: _state.settings.endpoint);
  bool _showKey = false;
  late String _lang = _state.settings.resultLanguage;
  late bool _larger = _state.settings.largerText;
  late bool _bold = _state.settings.boldText;
  late bool _motion = _state.settings.reduceMotion;

  @override
  void dispose() {
    _key.dispose();
    _model.dispose();
    _endpoint.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await _state.updateSettings(_state.settings.copyWith(
      engine: _engine,
      apiKey: _key.text.trim(),
      model: _model.text.trim().isEmpty ? const AppSettings().model : _model.text.trim(),
      endpoint: _endpoint.text.trim().isEmpty ? const AppSettings().endpoint : _endpoint.text.trim(),
      resultLanguage: _lang,
      largerText: _larger,
      boldText: _bold,
      reduceMotion: _motion,
    ));
    if (!mounted) return;
    showToast(context, 'Saved');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(leading: const BackButton(), title: const Text('Settings')),
      body: SafeArea(
        top: false,
        child: Column(children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              children: [
                Text('How should we read?', style: t.titleLarge),
                const SizedBox(height: 12),
                _EngineOption(
                  title: 'Offline',
                  body: 'Instant and private. Nothing leaves your phone. Spots 35+ common gotchas.',
                  icon: Icons.lock_rounded,
                  color: GColors.green,
                  selected: _engine == EngineChoice.offline,
                  onTap: () => setState(() => _engine = EngineChoice.offline),
                ),
                const SizedBox(height: 10),
                _EngineOption(
                  title: 'AI (Claude)',
                  body: 'Deeper, document-specific plain-English breakdowns. Sends the text to Anthropic using your API key.',
                  icon: Icons.auto_awesome_rounded,
                  color: GColors.blue,
                  selected: _engine == EngineChoice.claude,
                  onTap: () => setState(() => _engine = EngineChoice.claude),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  child: _engine != EngineChoice.claude
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            TextField(
                              controller: _key,
                              obscureText: !_showKey,
                              autocorrect: false,
                              decoration: InputDecoration(
                                hintText: 'Anthropic API key (sk-ant-…)',
                                prefixIcon: const Icon(Icons.key_rounded, color: GColors.inkFaint),
                                suffixIcon: IconButton(
                                  icon: Icon(_showKey ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                                  onPressed: () => setState(() => _showKey = !_showKey),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _model,
                              autocorrect: false,
                              decoration: const InputDecoration(
                                hintText: 'Model',
                                prefixIcon: Icon(Icons.memory_rounded, color: GColors.inkFaint),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _endpoint,
                              autocorrect: false,
                              keyboardType: TextInputType.url,
                              decoration: const InputDecoration(
                                hintText: 'Endpoint',
                                prefixIcon: Icon(Icons.dns_rounded, color: GColors.inkFaint),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Your key stays on this phone. If the AI is unreachable we fall back to the offline check automatically. '
                              'For a public release, point the endpoint at your own server so no key ships in the app.',
                              style: TextStyle(color: GColors.inkSoft, fontSize: 12.5, height: 1.4),
                            ),
                          ]),
                        ),
                ),
                const SizedBox(height: 28),
                Text('Results language', style: t.titleLarge),
                const SizedBox(height: 6),
                const Text(
                  'We can read terms in English, French, Spanish, German, Portuguese and Italian, and write the '
                  'results in your language. Reading and translating other languages uses the AI engine; '
                  'the offline reader is English only.',
                  style: TextStyle(color: GColors.inkSoft, fontSize: 13, height: 1.45),
                ),
                const SizedBox(height: 12),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final e in const {
                    'en': 'English',
                    'fr': 'Français',
                    'es': 'Español',
                    'de': 'Deutsch',
                    'pt': 'Português',
                    'it': 'Italiano',
                  }.entries)
                    Pressable(
                      onTap: () => setState(() => _lang = e.key),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _lang == e.key ? GColors.ink : GColors.white,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: GColors.ink, width: 1),
                        ),
                        child: Text(e.value,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: _lang == e.key ? FontWeight.w600 : FontWeight.w400,
                                color: _lang == e.key ? GColors.white : GColors.ink)),
                      ),
                    ),
                ]),
                const SizedBox(height: 28),
                Text('Accessibility', style: t.titleLarge),
                const SizedBox(height: 6),
                const Text('Tap the speaker on any result to have it read aloud.',
                    style: TextStyle(color: GColors.inkSoft, fontSize: 13, height: 1.45)),
                const SizedBox(height: 8),
                _Toggle(
                  title: 'Larger text',
                  body: 'Makes all text about 20% bigger.',
                  value: _larger,
                  onChanged: (v) => setState(() => _larger = v),
                ),
                _Toggle(
                  title: 'Bold text',
                  body: 'Heavier letters for stronger contrast.',
                  value: _bold,
                  onChanged: (v) => setState(() => _bold = v),
                ),
                _Toggle(
                  title: 'Reduce motion',
                  body: 'Turns off the slide-in and pop animations.',
                  value: _motion,
                  onChanged: (v) => setState(() => _motion = v),
                ),
                const SizedBox(height: 28),
                Text('Your data', style: t.titleLarge),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.delete_sweep_rounded, color: GColors.red),
                  title: const Text('Clear history', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${_state.history.length} saved checks'),
                  onTap: () async {
                    await showClearHistorySheet(context);
                    if (mounted) setState(() {});
                  },
                ),
                const SizedBox(height: 20),
                const SoftCard(
                  child: Text(
                    'YesBut explains contracts in everyday language. It isn\'t a lawyer and can miss things. '
                    'For leases, loans, jobs or anything big, get proper legal advice.',
                    style: TextStyle(color: GColors.inkSoft, fontSize: 13, height: 1.45, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(height: 18),
                const Center(child: Wordmark(size: 20)),
                const SizedBox(height: 6),
                const Center(
                    child: Text('v0.4.0', style: TextStyle(color: GColors.inkFaint, fontSize: 12, fontWeight: FontWeight.w600))),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: BigButton(label: 'Save', onTap: _save),
          ),
        ]),
      ),
    );
  }
}

class _EngineOption extends StatelessWidget {
  const _EngineOption({
    required this.title,
    required this.body,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final String title;
  final String body;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        scale: 0.98,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.08) : GColors.white,
            borderRadius: BorderRadius.circular(GRadius.lg),
            border: Border.all(color: selected ? color : GColors.line, width: 2),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: GColors.onColor(color), size: 21),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(body, style: const TextStyle(color: GColors.inkSoft, fontSize: 13.5, height: 1.4)),
              ]),
            ),
            const SizedBox(width: 8),
            Icon(selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: selected ? color : GColors.line),
          ]),
        ),
      );
}


class _Toggle extends StatelessWidget {
  const _Toggle({required this.title, required this.body, required this.value, required this.onChanged});
  final String title;
  final String body;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => MergeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(body, style: const TextStyle(color: GColors.inkSoft, fontSize: 13)),
              ]),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: GColors.white,
              activeTrackColor: GColors.ink,
            ),
          ]),
        ),
      );
}
