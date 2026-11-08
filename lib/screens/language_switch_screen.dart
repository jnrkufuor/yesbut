import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/scheduler.dart';
import '../i18n/text.dart';
import 'package:provider/provider.dart';

import '../services/analysis/offline_translator.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/loopy.dart';

/// Shown while the app changes language: white page, the brand asterisk
/// spinning slowly and shifting colour while the phone downloads and
/// translates, then speeding up, popping like a bubble and fading away once
/// the app underneath is really in the new language. All words here are in
/// the language you picked.
class LanguageSwitchScreen extends StatefulWidget {
  const LanguageSwitchScreen({super.key, required this.code, required this.name});
  final String code;
  final String name;
  @override
  State<LanguageSwitchScreen> createState() => _LanguageSwitchScreenState();
}

class _Words {
  const _Words(this.switching, this.translating, this.getting, this.firstTime, this.failed, this.back);
  final String switching, translating, getting, firstTime, failed, back;
}

const _copy = <String, _Words>{
  'en': _Words('Switching to English', 'Translating the app on your phone.', 'Getting English ready',
      'First time only: downloading the language pack (about 30 MB) so it works offline after this.',
      'Couldn’t download the language. Connect to the internet and try again.', 'Back'),
  'fr': _Words('Passage au français', 'Traduction de l’application sur votre téléphone.', 'Préparation du français',
      'Une seule fois : téléchargement du pack de langue (environ 30 Mo) pour qu’il fonctionne ensuite hors ligne.',
      'Impossible de télécharger la langue. Connectez-vous à Internet et réessayez.', 'Retour'),
  'es': _Words('Cambiando a español', 'Traduciendo la app en tu teléfono.', 'Preparando el español',
      'Solo la primera vez: descargando el paquete de idioma (unos 30 MB) para que luego funcione sin conexión.',
      'No se pudo descargar el idioma. Conéctate a internet e inténtalo de nuevo.', 'Volver'),
  'de': _Words('Wechsel zu Deutsch', 'Die App wird auf deinem Handy übersetzt.', 'Deutsch wird vorbereitet',
      'Nur beim ersten Mal: Das Sprachpaket (ca. 30 MB) wird geladen, danach klappt es auch offline.',
      'Die Sprache konnte nicht geladen werden. Verbinde dich mit dem Internet und versuche es erneut.', 'Zurück'),
  'pt': _Words('Mudando para português', 'Traduzindo o app no seu celular.', 'Preparando o português',
      'Só na primeira vez: baixando o pacote de idioma (cerca de 30 MB) para funcionar offline depois.',
      'Não foi possível baixar o idioma. Conecte-se à internet e tente de novo.', 'Voltar'),
  'it': _Words('Passaggio all’italiano', 'Traduzione dell’app sul tuo telefono.', 'Preparazione dell’italiano',
      'Solo la prima volta: scarico il pacchetto lingua (circa 30 MB) così poi funziona offline.',
      'Impossibile scaricare la lingua. Connettiti a internet e riprova.', 'Indietro'),
};

class _LanguageSwitchScreenState extends State<LanguageSwitchScreen> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;
  double _t = 0; // seconds since start
  double _angle = 0;
  bool _downloading = false;
  String? _error;

  _Words get _w => _copy[widget.code] ?? _copy['en']!;

  @override
  void initState() {
    super.initState();
    _ticker.start();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _tick(Duration now) {
    final dt = (now - _last).inMicroseconds / 1e6;
    _last = now;
    _t += dt;
    // Turns in surges: quick, then lazy, then quick again.
    final speed = 1.1 + 2.6 * math.pow(0.5 + 0.5 * math.sin(_t * 2.2), 3);
    _angle += speed * dt;
    setState(() {});
  }

  /// Each leg swells and shrinks in turn, going round clockwise, like a cell
  /// breathing.
  List<double> get _legs => [
        for (var i = 0; i < 6; i++) 0.5 + 0.5 * math.pow(0.5 + 0.5 * math.sin(_t * 9 - i * math.pi / 3), 1.6),
      ];

  Future<void> _run() async {
    final state = context.read<AppState>();
    final nav = Navigator.of(context);
    final minWait = Future<void>.delayed(const Duration(milliseconds: 1200));
    try {
      if (!await OfflineTranslator.isReady(widget.code)) {
        if (mounted) setState(() => _downloading = true);
        await OfflineTranslator.prepare(widget.code);
      }
      await state.updateSettings(state.settings.copyWith(resultLanguage: widget.code));
      // Wait until the screens underneath have actually been translated.
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await state.i18n.settle();
      await minWait;
      if (mounted) nav.pop(); // the route fades out
    } catch (_) {
      if (mounted) setState(() => _error = _w.failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _error != null ? GColors.inkFaint : GColors.red;
    return PopScope(
      canPop: _error != null,
      child: Scaffold(
        backgroundColor: GColors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Spacer(),
              Center(
                child: SizedBox.square(
                  dimension: 120,
                  child: Center(
                    child: Transform.rotate(
                      angle: _angle,
                      child: BrandAsterisk(size: 84, color: c, legs: _error != null ? null : _legs),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              // Fixed-height text block so nothing jumps when the words change.
              SizedBox(
                height: 120,
                child: Column(children: [
                  Text(
                    _error != null ? '…' : (_downloading ? _w.getting : _w.switching),
                    translate: false,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontFamily: AppTheme.display, fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.6, color: GColors.ink),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _error ?? (_downloading ? _w.firstTime : _w.translating),
                    translate: false,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14.5, height: 1.45, color: GColors.inkSoft),
                  ),
                ]),
              ),
              SizedBox(
                height: 58,
                child: _error == null
                    ? null
                    : BigButton(label: _w.back, color: GColors.ink, onTap: () => Navigator.of(context).pop()),
              ),
              const Spacer(flex: 2),
            ]),
          ),
        ),
      ),
    );
  }
}
