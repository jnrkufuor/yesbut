import 'package:flutter/material.dart' hide Text;
import '../i18n/text.dart';

import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/loopy.dart';
import 'home_screen.dart' show RoundIconButton;

/// Yes,But's own terms and privacy, done the Yes,But way: the short version
/// first, then every word of the full text.
class OurTermsScreen extends StatelessWidget {
  const OurTermsScreen({super.key});

  static const updated = 'November 8, 2026';

  static const _short = [
    'Free to use. No account, no ads, no tracking.',
    'Your checks and history stay on your phone.',
    'AI readers send the terms text to Google or OpenRouter. Never your name or account.',
    'Free AI services may learn from what they get. Mark personal papers as sensitive.',
    'Sensitive papers stay on your phone, and we don’t keep their text.',
    'We explain terms. We’re not lawyers, and we can miss things.',
  ];

  static const _sections = <(String, List<String>)>[
    ('What Yes,But does', [
      'Yes,But reads terms and conditions, privacy policies and other agreements, and explains them in plain words. '
          'It gives each one a fairness score and points out what to watch for.',
      'You can scan paper, upload a file, paste text, share from another app, drop a link, or pick a popular service.',
    ]),
    ('What stays on your phone', [
      'Your history, settings and watch list are stored only on this phone. We don’t have servers that keep them.',
      'Reading text from photos and screenshots happens on your phone.',
      'Translating the app and your documents happens on your phone, once the language pack is downloaded.',
      'The on-your-phone reader works without sending anything anywhere.',
    ]),
    ('What leaves your phone, and why', [
      'Web pages you ask us to check, search for or watch are downloaded from those websites, like a browser would.',
      'Searches for a company’s terms are sent to DuckDuckGo to find the right page.',
      'If you choose an AI reader (Gemini or DeepSeek), the text of the terms is sent to Google or to OpenRouter so the AI can read it. '
          'We don’t send your name, contacts, location or account details with it.',
      'On their free plans, Google and OpenRouter’s providers may keep what they receive and use it to improve their services. '
          'That’s why anything personal should be marked sensitive, or read with the on-your-phone reader.',
      'Language packs are downloaded from Google the first time you use a language.',
      'We don’t use analytics, ad networks or trackers.',
    ]),
    ('Sensitive documents', [
      'Leases, payslips, medical forms, bank and loan papers often include personal details. '
          'When you scan, upload or paste, you can turn on “Has personal info”.',
      'Then the document is read on your phone only. No AI reader is used, nothing is sent anywhere, '
          'and the original text isn’t saved with the result. Only the summary is kept.',
      'We also flag text that looks personal (emails, phone, ID, card or account numbers) and suggest marking it.',
      'Even so, cover up numbers and signatures you don’t need checked before you scan or share.',
    ]),
    ('Watching for changes', [
      'If you watch a page, the app re-downloads it about twice a day in the background and compares it with last time. '
          'If it changed, you get a notification. Only the page address and a fingerprint of its text are stored.',
    ]),
    ('Your choices', [
      'Pick the reader in Settings. “On your phone” keeps everything local.',
      'Delete any check, or clear all history, in Settings.',
      'Uninstalling the app removes everything it stored.',
    ]),
    ('Not legal advice', [
      'Yes,But explains documents to help you understand them. It isn’t a lawyer and doesn’t give legal advice. '
          'It can miss things or get them wrong, and AI readers can make mistakes. '
          'For leases, loans, jobs or anything big, read the full document and talk to a professional.',
      'The app is provided as is. We aren’t responsible for decisions you make based on it.',
    ]),
    ('Changes to these terms', [
      'If we change how your information is handled, we’ll update this page and the date at the top, and tell you in the app.',
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
          children: staggered([
            Row(children: [
              RoundIconButton(icon: 'back', onTap: () => Navigator.of(context).maybePop()),
              const Spacer(),
              const Text('Our terms',
                  style: TextStyle(fontFamily: AppTheme.display, fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -1.1, height: 1)),
              const SizedBox(width: 10),
              const IconBlob('doc', size: 40),
            ]),
            const SizedBox(height: 28),
            const HeadingText('Our own ', serif: 'fine print', size: 36),
            const SizedBox(height: 10),
            const Text('Last updated $updated',
                style: TextStyle(fontSize: 13, color: GColors.inkSoft)),
            const SizedBox(height: 20),
            // The short version, the way we'd show anyone else's terms.
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              decoration: BoxDecoration(color: GColors.ink, borderRadius: BorderRadius.circular(32)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text.rich(
                  TextSpan(children: [
                    const TextSpan(text: 'Yes, '),
                    TextSpan(text: 'but…', style: AppTheme.serifOf(const TextStyle(fontSize: 20, color: GColors.white))),
                  ]),
                  translate: false,
                  style: const TextStyle(
                      fontFamily: AppTheme.display, color: GColors.white, fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                for (final l in _short)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 3),
                        child: BrandAsterisk(size: 12, color: Color(0xFFD9D5D1)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(l,
                            style: TextStyle(color: GColors.white.withValues(alpha: 0.92), fontSize: 15, height: 1.45)),
                      ),
                    ]),
                  ),
              ]),
            ),
            const SizedBox(height: 30),
            const Text('THE FULL TEXT',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: GColors.inkSoft)),
            for (final (title, paras) in _sections) ...[
              const SizedBox(height: 22),
              Text(title,
                  style: const TextStyle(fontFamily: AppTheme.display, fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: -0.4)),
              const SizedBox(height: 8),
              for (final p in paras)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(p, style: const TextStyle(fontSize: 14.5, height: 1.5)),
                ),
            ],
          ]),
        ),
      ),
    );
  }
}
