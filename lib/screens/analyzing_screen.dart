import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import '../i18n/text.dart';
import 'package:provider/provider.dart';

import '../models/analysis.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../services/ingestion/web_fetcher.dart';
import '../widgets/common.dart';
import '../widgets/dialogs.dart';
import '../widgets/loopy.dart';
import 'home_screen.dart' show RoundIconButton;
import 'paste_screen.dart';
import 'result_screen.dart';

class AnalyzingScreen extends StatefulWidget {
  const AnalyzingScreen({super.key, required this.load, this.fetching = false});
  final Future<ContractInput> Function() load;
  final bool fetching;

  @override
  State<AnalyzingScreen> createState() => _AnalyzingScreenState();
}

class _AnalyzingScreenState extends State<AnalyzingScreen> {
  static const _quips = [
    'Reading the fine print so you don\'t have to…',
    'Squinting at the tiny text…',
    'Hunting for sneaky renewals…',
    'Translating legalese to human…',
    'Checking who pays when things go wrong…',
    'Finding the “but” in your “yes”…',
    'Sniffing out the catch…',
  ];

  int _quip = 0;
  int _step = 0; // 0 fetch/read, 1 analyze, 2 done
  String? _error;
  bool _scriptPage = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 1800), (_) {
      if (mounted) setState(() => _quip = (_quip + 1) % _quips.length);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _run() async {
    setState(() {
      _error = null;
      _scriptPage = false;
      _step = 0;
    });
    final state = context.read<AppState>();
    final minWait = Future<void>.delayed(const Duration(milliseconds: 1700));
    try {
      final input = await widget.load();
      if (!mounted) return;
      setState(() => _step = 1);
      final result = await state.analyze(input);
      await minWait;
      if (!mounted) return;
      setState(() => _step = 2);
      Navigator.of(context).pushReplacement(PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 420),
        pageBuilder: (_, __, ___) => ResultScreen(result: result, fresh: true),
        transitionsBuilder: (_, a, __, child) => FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.04), end: Offset.zero)
                .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
      ));
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _scriptPage = e is ScriptPageException;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    if (_error != null) return _errorView(t);

    final steps = [
      widget.fetching ? 'Grabbing the page' : 'Reading the text',
      'Spotting the gotchas',
      'Writing it in plain English',
    ];

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RoundIconButton(icon: 'back', onTap: () => Navigator.of(context).maybePop()),
              const Spacer(),
              const SniffLoader(height: 240),
              const SizedBox(height: 28),
              SizedBox(
                height: 64,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: (c, a) => FadeTransition(
                    opacity: a,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(a),
                      child: c,
                    ),
                  ),
                  child: Align(
                    key: ValueKey(_quip),
                    alignment: Alignment.topLeft,
                    child: Text(
                      _quips[_quip],
                      style: t.headlineMedium?.copyWith(fontSize: 24),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              for (var i = 0; i < steps.length; i++)
                _StepRow(label: steps[i], state: i < _step ? 2 : (i == _step ? 1 : 0)),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorView(TextTheme t) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RoundIconButton(icon: 'back', onTap: () => Navigator.of(context).maybePop()),
                const Spacer(),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: _scriptPage ? GColors.green : GColors.red,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: LoopyIcon(_scriptPage ? 'eye' : 'flag',
                      size: 40, color: _scriptPage ? GColors.ink : GColors.white, stroke: 2.2),
                ),
                const SizedBox(height: 22),
                HeadingText(
                  _scriptPage ? 'This page is shy on the ' : 'Whoops, we ',
                  serif: _scriptPage ? 'first try.' : 'hit a wall.',
                  size: 30,
                ),
                const SizedBox(height: 12),
                Text(
                  _scriptPage
                      ? 'Some sites build their page with scripts, so our first read can come back empty. '
                          'We already tried twice. Another go usually works. If it keeps happening, open the '
                          'page in your browser, copy the text and paste it here.'
                      : _error!,
                  style: t.bodyLarge?.copyWith(color: GColors.inkSoft),
                ),
                const Spacer(flex: 2),
                BigButton(label: 'Try again', icon: Icons.refresh_rounded, onTap: _run),
                const SizedBox(height: 8),
                BigButton(
                  label: 'Paste the text instead',
                  color: GColors.green,
                  onTap: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const PasteScreen())),
                ),
              ],
            ),
          ),
        ),
      );
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.label, required this.state});
  final String label;
  final int state; // 0 pending, 1 active, 2 done

  @override
  Widget build(BuildContext context) {
    final color = switch (state) { 2 => GColors.blue, 1 => GColors.ink, _ => GColors.line };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: state == 2 ? color : GColors.white,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1),
          ),
          child: state == 2
              ? const Icon(Icons.check_rounded, size: 15, color: GColors.white)
              : (state == 1
                  ? const Padding(
                      padding: EdgeInsets.all(6),
                      child: CircularProgressIndicator(strokeWidth: 1.6, color: GColors.red),
                    )
                  : null),
        ),
        const SizedBox(width: 14),
        Text(label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: state == 0 ? GColors.inkFaint : GColors.ink,
            )),
      ]),
    );
  }
}
