import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import '../i18n/text.dart';
import 'package:provider/provider.dart';

import '../services/analysis/offline_translator.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Shown while the app changes language. First time for a language it
/// downloads the pack (with a friendly animation); after that it's a quick
/// beat so you can see the switch happen.
class LanguageSwitchScreen extends StatefulWidget {
  const LanguageSwitchScreen({super.key, required this.code, required this.name});
  final String code;
  final String name;
  @override
  State<LanguageSwitchScreen> createState() => _LanguageSwitchScreenState();
}

class _LanguageSwitchScreenState extends State<LanguageSwitchScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _spin =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();
  bool _downloading = false;
  String? _error;

  static const _hello = {
    'en': 'Hello', 'fr': 'Bonjour', 'es': 'Hola', 'de': 'Hallo', 'pt': 'Olá', 'it': 'Ciao',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final state = context.read<AppState>();
    final nav = Navigator.of(context);
    final minWait = Future<void>.delayed(const Duration(milliseconds: 1100));
    try {
      if (!await OfflineTranslator.isReady(widget.code)) {
        if (mounted) setState(() => _downloading = true);
        await OfflineTranslator.prepare(widget.code);
      }
      await state.updateSettings(state.settings.copyWith(resultLanguage: widget.code));
      // Give the translator a moment to fill in the visible words.
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await minWait;
      if (mounted) nav.pop();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Couldn’t download ${widget.name}. Connect to the internet and try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hello = _hello[widget.code] ?? 'Hello';
    return PopScope(
      canPop: _error != null,
      child: Scaffold(
        backgroundColor: GColors.ink,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Spacer(),
              // Greetings in each language orbit while we work.
              SizedBox(
                height: 140,
                child: AnimatedBuilder(
                  animation: _spin,
                  builder: (context, _) {
                    final words = _hello.values.toList();
                    final i = (_spin.value * words.length).floor() % words.length;
                    return Stack(children: [
                      for (var k = 0; k < 3; k++)
                        Positioned(
                          left: 0,
                          top: 10.0 + k * 40,
                          child: Opacity(
                            opacity: k == 1 ? 1 : 0.25,
                            child: Text(words[(i + k) % words.length],
                                translate: false,
                                style: TextStyle(
                                  fontFamily: k == 1 ? AppTheme.serif : AppTheme.display,
                                  fontStyle: k == 1 ? FontStyle.italic : FontStyle.normal,
                                  fontSize: k == 1 ? 40 : 26,
                                  fontWeight: k == 1 ? FontWeight.w400 : FontWeight.w700,
                                  color: GColors.white,
                                )),
                          ),
                        ),
                    ]);
                  },
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _error != null
                    ? 'Hmm.'
                    : (_downloading ? 'Getting ${widget.name} ready…' : '$hello! Switching to ${widget.name}…'),
                translate: false,
                style: const TextStyle(
                    fontFamily: AppTheme.display, fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.8, color: GColors.white),
              ),
              const SizedBox(height: 10),
              Text(
                _error ??
                    (_downloading
                        ? 'First time only. We’re downloading the ${widget.name} language pack (about 30 MB) so it works offline after this.'
                        : 'Translating the app on your phone.'),
                translate: false,
                style: TextStyle(fontSize: 15, height: 1.45, color: GColors.white.withValues(alpha: 0.8)),
              ),
              const SizedBox(height: 22),
              if (_error == null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: const LinearProgressIndicator(
                    minHeight: 6,
                    color: GColors.green,
                    backgroundColor: Color(0xFF3D3936),
                  ),
                )
              else
                BigButton(label: 'Back', color: GColors.white, onTap: () => Navigator.of(context).pop()),
              const Spacer(flex: 2),
            ]),
          ),
        ),
      ),
    );
  }
}
