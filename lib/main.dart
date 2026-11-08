import 'package:flutter/material.dart' hide Text;
import 'i18n/text.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'screens/onboarding_screen.dart';
import 'screens/root_shell.dart';
import 'services/storage.dart';
import 'services/watch_service.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'widgets/loopy.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  WatchService.initNotifications().catchError((_) {});
  runApp(const YesButApp());
}

class YesButApp extends StatefulWidget {
  const YesButApp({super.key});
  @override
  State<YesButApp> createState() => _YesButAppState();
}

class _YesButAppState extends State<YesButApp> {
  final _state = AppState(Storage());
  // Show the animated splash for at least its full run, even if init is fast.
  late final Future<void> _ready = Future.wait([
    _state.init(),
    Future<void>.delayed(const Duration(milliseconds: 3600)), // 1s pause + animation + a beat
  ]);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _state,
      child: ChangeNotifierProvider.value(
        value: _state.i18n,
        child: MaterialApp(
        title: 'Yes,But',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        // Accessibility settings applied app-wide.
        builder: (context, child) {
          final st = context.watch<AppState>().settings;
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(
              textScaler: st.largerText ? TextScaler.linear(mq.textScaler.scale(1) * 1.2) : mq.textScaler,
              boldText: st.boldText || mq.boldText,
              disableAnimations: st.reduceMotion || mq.disableAnimations,
            ),
            child: child!,
          );
        },
        home: FutureBuilder<void>(
          future: _ready,
          builder: (context, snap) => AnimatedSwitcher(
            duration: const Duration(milliseconds: 380),
            child: snap.connectionState != ConnectionState.done
                ? const SplashScreen()
                : Consumer<AppState>(
                    builder: (context, s, _) =>
                        s.onboarded ? const RootShell() : const OnboardingScreen(),
                  ),
          ),
        ),
      ),
      ),
    );
  }
}

/// "yes," rises in, then "but" bursts in magnified like an interjection,
/// the asterisk spins on, and the tagline settles underneath.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));

  @override
  void initState() {
    super.initState();
    // A one-second pause on a blank screen before "yes," arrives.
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) _c.forward();
    });
  }

  double _seg(double a, double b, [Curve curve = Curves.linear]) =>
      curve.transform(((_c.value - a) / (b - a)).clamp(0.0, 1.0));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const size = 66.0;
    return Scaffold(
      backgroundColor: GColors.white,
      body: Center(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final yes = _seg(0.08, 0.38, Curves.easeOutBack);
            final yesFade = _seg(0.08, 0.25);
            // "but": tiny -> 1.75x pop -> settle to 1x with a spring.
            final popIn = _seg(0.42, 0.56, Curves.easeOutBack);
            final settle = _seg(0.62, 0.86, Curves.elasticOut);
            final butScale = _c.value < 0.42 ? 0.25 : (0.25 + 1.5 * popIn) - 0.75 * settle;
            final butFade = _seg(0.42, 0.47);
            final tilt = (-0.1 * popIn) * (1 - settle);
            final star = _seg(0.66, 0.92, Curves.easeOutBack);
            final tag = _seg(0.8, 1.0, Curves.easeOutCubic);
            return Column(mainAxisSize: MainAxisSize.min, children: [
              Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Opacity(
                  opacity: yesFade,
                  child: Transform.translate(
                    offset: Offset(0, (1 - yes) * 22),
                    child: const Text('yes,', translate: false,
                        style: TextStyle(
                          fontFamily: AppTheme.display,
                          fontSize: size,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -2.6,
                          color: GColors.ink,
                          height: 1,
                        )),
                  ),
                ),
                const SizedBox(width: 3),
                Opacity(
                  opacity: butFade,
                  child: Transform.rotate(
                    angle: tilt,
                    alignment: const Alignment(-0.4, 0.5),
                    child: Transform.scale(
                      scale: butScale,
                      alignment: const Alignment(-0.4, 0.5),
                      child: const Text('but', translate: false,
                          style: TextStyle(
                            fontFamily: AppTheme.serif,
                            fontStyle: FontStyle.italic,
                            fontSize: size * 1.1,
                            letterSpacing: -1.3,
                            color: GColors.ink,
                            height: 0.95,
                          )),
                    ),
                  ),
                ),
                Opacity(
                  opacity: star.clamp(0.0, 1.0),
                  child: Transform.rotate(
                    angle: (1 - star) * -3.4,
                    child: Transform.scale(
                      scale: 0.2 + 0.8 * star,
                      child: const Padding(
                        padding: EdgeInsets.only(left: 3, top: 0),
                        child: BrandAsterisk(size: 26),
                      ),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 18),
              Opacity(
                opacity: tag,
                child: Transform.translate(
                  offset: Offset(0, (1 - tag) * 8),
                  child: const Text('We read the fine print.',
                      style: TextStyle(fontSize: 15, color: GColors.inkSoft)),
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }
}
