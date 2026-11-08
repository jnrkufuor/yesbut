import 'package:flutter/material.dart' hide Text;
import '../i18n/text.dart';
import 'package:flutter/services.dart';

import '../models/analysis.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/dialogs.dart';
import '../widgets/loopy.dart';
import 'home_screen.dart' show RoundIconButton;
import 'flows.dart';

class PasteScreen extends StatefulWidget {
  const PasteScreen({super.key, this.initialText, this.initialTitle});
  final String? initialText;
  final String? initialTitle;
  @override
  State<PasteScreen> createState() => _PasteScreenState();
}

class _PasteScreenState extends State<PasteScreen> {
  final _text = TextEditingController();
  final _title = TextEditingController();
  bool _sensitive = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialText != null) _text.text = widget.initialText!;
    if (widget.initialTitle != null) _title.text = widget.initialTitle!;
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
      title: 'Drop in the ',
      titleSerif: 'fine print',
      subtitle: 'Copy the terms from an app, email or website and put them below.',
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
                  sensitive: _sensitive,
                ),
      ),
      children: [
        TextField(
          controller: _title,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: context.tr('Name it (optional), e.g. Gym membership'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: const BorderSide(color: GColors.line)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: const BorderSide(color: GColors.line)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: const BorderSide(color: GColors.ink)),
          ),
        ),
        const SizedBox(height: 12),
        Stack(children: [
          TextField(
            controller: _text,
            minLines: 10,
            maxLines: 16,
            keyboardType: TextInputType.multiline,
            decoration: InputDecoration(
              hintText: context.tr('Paste the terms & conditions here…'),
              contentPadding: const EdgeInsets.fromLTRB(18, 18, 18, 60),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: const BorderSide(color: GColors.line)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: const BorderSide(color: GColors.line)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: const BorderSide(color: GColors.ink)),
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
                  color: GColors.green,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  LoopyIcon('paste', size: 18, stroke: 2.4),
                  SizedBox(width: 6),
                  Text('Paste from clipboard', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ]),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 20,
            child: Text('$words words',
                style: const TextStyle(color: GColors.inkSoft, fontWeight: FontWeight.w400, fontSize: 12)),
          ),
        ]),
        const SizedBox(height: 12),
        SensitiveToggle(
          value: _sensitive,
          suggest: looksPersonal(_text.text),
          onChanged: (v) => setState(() => _sensitive = v),
        ),
      ],
    );
  }
}

/// Shared layout for the four input screens (Scan, Upload, Paste, Link):
/// white page in the house style. Header = back on the left, the page's name
/// and colored icon on the right; then the big heading, content, and a sticky
/// charcoal action button. The home card grows into this page.
class InputScaffold extends StatelessWidget {
  const InputScaffold({
    super.key,
    required this.accent,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
    required this.bottom,
    this.titleSerif,
    this.name,
  });
  final Color accent;
  final IconData icon;
  final String title; // lead part of the heading
  final String? titleSerif; // italic "but" part of the heading
  final String? name; // short page name in the header
  final String subtitle;
  final List<Widget> children;
  final Widget bottom;

  String get _loopy {
    if (accent == GColors.red) return 'scan';
    if (accent == GColors.blue) return 'upload';
    if (accent == GColors.green) return 'paste';
    return 'link';
  }

  String get _name => name ??
      (accent == GColors.red
          ? 'Scan it'
          : accent == GColors.blue
              ? 'Upload'
              : accent == GColors.green
                  ? 'Paste text'
                  : 'Drop a link');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GColors.white,
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
              children: [
                ...staggered([
                  Row(children: [
                    RoundIconButton(icon: 'back', onTap: () => Navigator.of(context).maybePop()),
                    const Spacer(),
                    Text(_name,
                        style: const TextStyle(
                            fontFamily: AppTheme.display, fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -1.1, height: 1)),
                    const SizedBox(width: 8),
                    IconBlob(_loopy, color: accent, iconColor: GColors.onColor(accent), size: 40),
                  ]),
                  const SizedBox(height: 28),
                  HeadingText(title, serif: titleSerif, size: 36),
                  const SizedBox(height: 10),
                  Text(subtitle, style: const TextStyle(fontSize: 15, height: 1.45, color: GColors.inkSoft)),
                  const SizedBox(height: 22),
                ]),
                ...staggered(children, start: 4),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), child: bottom),
        ]),
      ),
    );
  }
}

/// Big tappable block in the page's own color (e.g. "Snap a page").
class HeroAction extends StatelessWidget {
  const HeroAction({
    super.key,
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.busy = false,
  });
  final Color color;
  final String icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final fg = GColors.onColor(color);
    return Pressable(
      onTap: busy ? null : onTap,
      child: Container(
        height: 172,
        padding: const EdgeInsets.fromLTRB(22, 20, 20, 22),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(40)),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          Positioned(
            right: -26,
            bottom: -30,
            child: LoopyAccent(icon, color: GColors.deep(color), size: 128, stroke: 2),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Transform.translate(
                offset: const Offset(-8, -8),
                child: busy
                    ? Padding(
                        padding: const EdgeInsets.all(18),
                        child: SizedBox(width: 30, height: 30, child: CircularProgressIndicator(strokeWidth: 2, color: fg)),
                      )
                    : LoopyIcon(icon, size: 66, color: fg, stroke: 1.5),
              ),
              const Spacer(),
              Icon(Icons.add_rounded, color: fg, size: 26),
            ]),
            const Spacer(),
            Text(title,
                style: TextStyle(
                    fontFamily: AppTheme.display, fontSize: 21, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: fg)),
            const SizedBox(height: 3),
            Text(subtitle, style: TextStyle(fontSize: 13, color: fg.withValues(alpha: 0.85))),
          ]),
        ]),
      ),
    );
  }
}

/// Charcoal-outlined pill for a secondary action.
class OutlinePill extends StatelessWidget {
  const OutlinePill({super.key, required this.label, required this.icon, required this.onTap});
  final String label;
  final String icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 18, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: GColors.ink, width: 1),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            LoopyIcon(icon, size: 20, stroke: 2.2),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400)),
          ]),
        ),
      );
}

/// Quiet tip: small line icon and grey text, no box.
class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.icon, required this.text});
  final String icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        LoopyIcon(icon, size: 22, color: GColors.inkSoft, stroke: 2),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5, height: 1.45, color: GColors.inkSoft))),
      ]);
}


/// Spots personal details (emails, phone/ID/card/account numbers) so we can
/// suggest marking a document sensitive.
bool looksPersonal(String text) => RegExp(
      r'[\w.+-]+@[\w-]+\.[\w.]+'
      r'|\b\d{3}-\d{2}-\d{4}\b'
      r'|\b(?:\d[ -]?){13,19}\b'
      r'|\+?\d[\d ()-]{9,}\d'
      r'|\b[A-Z]{2}\d{2}[A-Z0-9]{11,30}\b'
      r'|\b(?:date of birth|DOB|SSN|SIN|passport no|account (?:no|number))\b',
      caseSensitive: false,
    ).hasMatch(text);

/// "This has personal info" switch for Scan, Upload and Paste. When on, the
/// document is read on the phone only (no AI) and its text isn't saved.
class SensitiveToggle extends StatelessWidget {
  const SensitiveToggle({super.key, required this.value, required this.onChanged, this.suggest = false});
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool suggest; // we spotted personal details

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: value || suggest ? GColors.ink : GColors.line, width: 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const LoopyIcon('eye', size: 22, stroke: 2.2),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Has personal info', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
          ),
          Semantics(
            toggled: value,
            label: 'Mark as sensitive',
            child: GestureDetector(
              onTap: () => onChanged(!value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 46,
                height: 28,
                padding: const EdgeInsets.all(3),
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: GColors.white,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: value ? GColors.ink : GColors.line, width: 1),
                ),
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(color: value ? GColors.ink : GColors.line, shape: BoxShape.circle),
                ),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        Text(
          value
              ? 'We’ll read it on your phone only. No AI, nothing sent anywhere, and the text isn’t saved. '
                  'Still, cover up ID, account or card numbers you don’t need checked.'
              : suggest
                  ? 'This looks like it has personal details. Mark it so it stays on your phone.'
                  : 'Turn on for leases, payslips, medical or bank papers. It stays on your phone.',
          style: const TextStyle(fontSize: 12.5, height: 1.45, color: GColors.inkSoft),
        ),
      ]),
    );
  }
}
