import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/analysis.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'flows.dart';

class PasteScreen extends StatefulWidget {
  const PasteScreen({super.key});
  @override
  State<PasteScreen> createState() => _PasteScreenState();
}

class _PasteScreenState extends State<PasteScreen> {
  final _text = TextEditingController();
  final _title = TextEditingController();

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    _title.dispose();
    super.dispose();
  }

  Future<void> _pasteClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final v = data?.text ?? '';
    if (!mounted) return;
    if (v.trim().isEmpty) {
      showToast(context, 'Your clipboard is empty.');
      return;
    }
    _text.text = v;
  }

  @override
  Widget build(BuildContext context) {
    final words = _text.text.trim().isEmpty ? 0 : _text.text.trim().split(RegExp(r'\s+')).length;
    return InputScaffold(
      accent: GColors.green,
      icon: Icons.content_paste_rounded,
      title: 'Paste the fine print',
      subtitle: 'Copy terms from an app, email or website and drop them here.',
      bottom: BigButton(
        label: 'Find the gotchas',
        icon: Icons.arrow_forward_rounded,
        color: GColors.green,
        onTap: words < 15
            ? null
            : () => Flows.analyzeText(
                  context,
                  text: _text.text,
                  title: _title.text.trim().isEmpty ? 'Pasted terms' : _title.text.trim(),
                  kind: SourceKind.paste,
                ),
      ),
      children: [
        TextField(
          controller: _title,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Name it (optional) — e.g. Gym membership'),
        ),
        const SizedBox(height: 12),
        Stack(children: [
          TextField(
            controller: _text,
            minLines: 10,
            maxLines: 16,
            keyboardType: TextInputType.multiline,
            decoration: const InputDecoration(
              hintText: 'Paste the terms & conditions here…',
              contentPadding: EdgeInsets.fromLTRB(18, 18, 18, 56),
            ),
          ),
          Positioned(
            left: 12,
            bottom: 12,
            child: Pressable(
              onTap: _pasteClipboard,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: GColors.white,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: GColors.line, width: 1.5),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.content_paste_go_rounded, size: 16, color: GColors.greenText),
                  SizedBox(width: 6),
                  Text('Paste from clipboard', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                ]),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 20,
            child: Text('$words words',
                style: const TextStyle(color: GColors.inkFaint, fontWeight: FontWeight.w700, fontSize: 12)),
          ),
        ]),
      ],
    );
  }
}

/// Shared layout for the input screens: colored icon, big title, content,
/// and a sticky action button.
class InputScaffold extends StatelessWidget {
  const InputScaffold({
    super.key,
    required this.accent,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
    required this.bottom,
  });
  final Color accent;
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;
  final Widget bottom;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(leading: const BackButton()),
      body: SafeArea(
        top: false,
        child: Column(children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(18)),
                  child: Icon(icon, color: GColors.onColor(accent), size: 28),
                ),
                const SizedBox(height: 18),
                Text(title, style: t.headlineMedium),
                const SizedBox(height: 6),
                Text(subtitle, style: t.bodyLarge?.copyWith(color: GColors.inkSoft)),
                const SizedBox(height: 22),
                ...children,
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 16), child: bottom),
        ]),
      ),
    );
  }
}
