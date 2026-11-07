import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'screens/onboarding_screen.dart';
import 'screens/root_shell.dart';
import 'services/storage.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'widgets/common.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const YesButApp());
}

class YesButApp extends StatefulWidget {
  const YesButApp({super.key});
  @override
  State<YesButApp> createState() => _YesButAppState();
}

class _YesButAppState extends State<YesButApp> {
  final _state = AppState(Storage());
  late final Future<void> _ready = _state.init();

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _state,
      child: MaterialApp(
        title: 'YesBut',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: FutureBuilder<void>(
          future: _ready,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const _Splash();
            }
            return Consumer<AppState>(
              builder: (context, s, _) =>
                  s.onboarded ? const RootShell() : const OnboardingScreen(),
            );
          },
        ),
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Wordmark(size: 40)),
      );
}
