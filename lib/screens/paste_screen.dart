import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/analysis.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/dialogs.dart';
import '../widgets/loopy.dart';
import 'home_screen.dart' show RoundIconButton;
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
        label: 'Find the catches',
        icon: Icons.arrow_forward_rounded,
        color: GColors.ink,
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
                  border: Border.all(color: GColors.line, width: 1),
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

/// Shared layout for the input screens: a full-screen sheet in the card's
/// own color (so the home card can grow straight into it), loopy icon, big
/// title, content, and a sticky action button.
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

  String get _loopy {
    if (accent == GColors.red) return 'scan';
    if (accent == GColors.blue) return 'upload';
    if (accent == GColors.green) return 'paste';
    return 'link';
  }

  @override
  Widget build(BuildContext context) {
    final fg = GColors.onColor(accent);
    return LeaveGuard(
      child: Scaffold(
      backgroundColor: accent,
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
              children: [
                Row(children: [
                  RoundIconButton(icon: 'back', onTap: () => Navigator.of(context).maybePop()),
                  const Spacer(),
                  LoopyIcon(_loopy, size: 54, color: fg, stroke: 1.6),
                ]),
                const SizedBox(height: 28),
                Text(title,
                    style: TextStyle(
                      fontFamily: AppTheme.display,
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.3,
                      height: 1.04,
                      color: fg,
                    )),
                const SizedBox(height: 10),
                Text(subtitle, style: TextStyle(fontSize: 15, height: 1.45, color: fg.withValues(alpha: 0.85))),
                const SizedBox(height: 24),
                ...staggered(children, start: 2),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), child: bottom),
        ]),
      ),
    ),
    );
  }
}
