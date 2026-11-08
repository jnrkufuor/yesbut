import 'package:flutter/material.dart' hide Text;
import '../i18n/text.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/loopy.dart';
import 'flows.dart';
import 'paste_screen.dart';

class LinkScreen extends StatefulWidget {
  const LinkScreen({super.key});
  @override
  State<LinkScreen> createState() => _LinkScreenState();
}

class _LinkScreenState extends State<LinkScreen> {
  final _url = TextEditingController();

  @override
  void initState() {
    super.initState();
    _url.addListener(() => setState(() {}));
    _prefillFromClipboard();
  }

  Future<void> _prefillFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final v = (data?.text ?? '').trim();
    if (mounted && _url.text.isEmpty && RegExp(r'^https?://\S+$').hasMatch(v)) {
      _url.text = v;
    }
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  void _go() {
    FocusScope.of(context).unfocus();
    Flows.analyzeUrl(context, _url.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final ok = _url.text.trim().contains('.');
    return InputScaffold(
      accent: GColors.ink,
      icon: Icons.link_rounded,
      title: 'Drop a ',
      titleSerif: 'link',
      subtitle: 'Paste the web address of any terms, privacy policy or subscription page.',
      bottom: BigButton(
        label: 'Read it for me',
        icon: Icons.arrow_forward_rounded,
        color: GColors.ink,
        onTap: ok ? _go : null,
      ),
      children: [
        TextField(
          controller: _url,
          autofocus: _url.text.isEmpty,
          keyboardType: TextInputType.url,
          autocorrect: false,
          textInputAction: TextInputAction.go,
          onSubmitted: (_) {
            if (ok) _go();
          },
          decoration: InputDecoration(
            hintText: 'https://example.com/terms',
            contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: const BorderSide(color: GColors.line)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: const BorderSide(color: GColors.line)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: const BorderSide(color: GColors.ink)),
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: 14, right: 6),
              child: LoopyIcon('link', size: 22, stroke: 2.2),
            ),
            suffixIcon: _url.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => _url.clear(),
                  ),
          ),
        ),
        const SizedBox(height: 22),
        const InfoRow(
          icon: 'eye',
          text: 'Some sites build their page with scripts, so the first try can come back empty. '
              'We retry automatically. Still stuck? Copy the text and use Paste text.',
        ),
        const SizedBox(height: 14),
        Pressable(
          onTap: () => Flows.search(context),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: GColors.line, width: 1),
            ),
            child: const Row(children: [
              LoopyIcon('search', size: 24, stroke: 2.2),
              SizedBox(width: 12),
              Expanded(
                child: Text('No link? Search for a company’s terms instead.',
                    style: TextStyle(fontSize: 13.5, height: 1.45)),
              ),
              Icon(Icons.arrow_outward_rounded, size: 20, color: GColors.ink),
            ]),
          ),
        ),
      ],
    );
  }
}
