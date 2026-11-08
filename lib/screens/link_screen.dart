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
      title: 'Drop a link',
      subtitle: 'Paste the web address of any terms, privacy policy or subscription page.',
      bottom: BigButton(
        label: 'Read it for me',
        icon: Icons.arrow_forward_rounded,
        color: GColors.white,
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
            prefixIcon: const Icon(Icons.public_rounded, color: GColors.inkFaint),
            suffixIcon: _url.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => _url.clear(),
                  ),
          ),
        ),
        const SizedBox(height: 18),
        const SoftCard(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            LoopyIcon('eye', size: 26, stroke: 2.2),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Heads up: some sites build their page with scripts, so the first try can come back empty. '
                'We retry automatically, and tapping Try again usually does it. Still stuck? Open the page in '
                'your browser, copy the text and use Paste text.',
                style: TextStyle(fontSize: 13.5, height: 1.45),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        Pressable(
          onTap: () => Flows.search(context),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(GRadius.lg),
              border: Border.all(color: GColors.white.withValues(alpha: 0.5), width: 1),
            ),
            child: const Row(children: [
              LoopyIcon('search', size: 26, color: GColors.white, stroke: 2.4),
              SizedBox(width: 12),
              Expanded(
                child: Text('Don’t have the link? Search for a company’s terms instead.',
                    style: TextStyle(fontSize: 13.5, height: 1.45, color: GColors.white)),
              ),
              Icon(Icons.arrow_outward_rounded, size: 20, color: GColors.white),
            ]),
          ),
        ),
      ],
    );
  }
}
