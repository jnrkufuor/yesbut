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
  double _speed = 1.4; // radians per second
  bool _done = false;
  double _doneAt = 0;
  double _pop = 0; // 0..1 bubble pop
  bool _downloading = false;
  String? _error;

  static const _accel = 0.75; // seconds of speeding up once done
  static const _popTime = 0.32;

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
    if (!_done) {
      // Slow, gently rising while we work.
      _speed = math.min(2.6, 1.4 + _t * 0.15);
    } else {
      final k = ((_t - _doneAt) / _accel).clamp(0.0, 1.0);
      _speed = 2.6 + 26 * k * k; // ease-in: whoosh
      if (k >= 1) {
        _pop = ((_t - _doneAt - _accel) / _popTime).clamp(0.0, 1.0);
        if (_pop >= 1) {
          _ticker.stop();
          if (mounted) Navigator.of(context).pop();
          return;
        }
      }
    }
    _angle += _speed * dt;
    setState(() {});
  }

  Future<void> _run() async {
    final state = context.read<AppState>();
    final minWait = Future<void>.delayed(const Duration(milliseconds: 1200));
    try {
      if (!await OfflineTranslator.isReady(widget.code)) {
        if (mounted) setState(() => _downloading = true);
        await OfflineTranslator.prepare(widget.code);
      }
      await state.updateSettings(state.settings.copyWith(resultLanguage: widget.code));
      if (mounted) setState(() => _downloading = false);
      // Wait until the screens underneath have actually been translated.
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await state.i18n.settle();
      await minWait;
      if (mounted) {
        _doneAt = _t;
        _done = true;
      }
    } catch (_) {
      if (mounted) setState(() => _error = _w.failed);
    }
  }

  Color _color() {
    const cs = [GColors.red, GColors.blue, GColors.green, GColors.ink];
    final x = (_t * 0.55) % cs.length;
    final i = x.floor();
    final f = Curves.easeInOut.transform(x - i);
    return Color.lerp(cs[i], cs[(i + 1) % cs.length], f)!;
  }

  @override
  Widget build(BuildContext context) {
    final c = _error != null ? GColors.inkFaint : _color();
    final bubble = Curves.easeOut.transform(_pop);
    return PopScope(
      canPop: _error != null,
      child: Scaffold(
        backgroundColor: GColors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(children: [
              const Spacer(),
              SizedBox(
                width: 180,
                height: 180,
                child: Stack(alignment: Alignment.center, children: [
                  // The bubble's skin: a thin ring that bursts outward.
                  if (_pop > 0)
                    Opacity(
                      opacity: (1 - bubble).clamp(0.0, 1.0),
                      child: Container(
                        width: 70 + 110 * bubble,
                        height: 70 + 110 * bubble,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: c, width: 2.5 * (1 - bubble) + 0.5),
                        ),
                      ),
                    ),
                  Opacity(
                    opacity: (1 - bubble * 1.4).clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: 1 + 0.5 * bubble,
                      child: Transform.rotate(angle: _angle, child: BrandAsterisk(size: 72, color: c)),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 28),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _done ? 0 : 1,
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
              if (_error != null) ...[
                const SizedBox(height: 24),
                BigButton(label: _w.back, color: GColors.ink, onTap: () => Navigator.of(context).pop()),
              ],
              const Spacer(flex: 2),
            ]),
          ),
        ),
      ),
    );
  }
}
