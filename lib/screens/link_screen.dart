import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../widgets/common.dart';
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
          color: GColors.blueSoft,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.tips_and_updates_rounded, color: GColors.blue),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Tip: look for "Terms", "Legal" or "Subscriber agreement" at the bottom of a site. '
                'If a page won\'t load here, open it in your browser, copy the text and use Paste text.',
                style: TextStyle(fontSize: 13.5, height: 1.45, fontWeight: FontWeight.w500),
              ),
            ),
          ]),
        ),
      ],
    );
  }
}
