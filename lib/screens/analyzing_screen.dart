import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/analysis.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
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
  ];

  int _quip = 0;
  int _step = 0; // 0 fetch/read, 1 analyze, 2 done
  String? _error;
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
      if (mounted) setState(() => _error = e.toString());
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
      appBar: AppBar(leading: const CloseButton()),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 40),
          child: Column(
            children: [
              const Spacer(flex: 2),
              const HopDots(size: 22),
              const SizedBox(height: 44),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                child: Text(
                  _quips[_quip],
                  key: ValueKey(_quip),
                  textAlign: TextAlign.center,
                  style: t.headlineMedium?.copyWith(fontSize: 24),
                ),
              ),
              const Spacer(flex: 2),
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
        appBar: AppBar(leading: const CloseButton()),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(color: GColors.redSoft, borderRadius: BorderRadius.circular(22)),
                  child: const Icon(Icons.sentiment_dissatisfied_rounded, color: GColors.red, size: 34),
                ),
                const SizedBox(height: 20),
                Text('Whoops, we hit a wall.', style: t.headlineMedium),
                const SizedBox(height: 10),
                Text(_error!, style: t.bodyLarge?.copyWith(color: GColors.inkSoft)),
                const Spacer(flex: 2),
                BigButton(label: 'Try again', icon: Icons.refresh_rounded, onTap: _run),
                const SizedBox(height: 10),
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
    final color = switch (state) { 2 => GColors.green, 1 => GColors.blue, _ => GColors.line };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 26,
          height: 26,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: state == 2
              ? const Icon(Icons.check_rounded, size: 16, color: GColors.white)
              : (state == 1
                  ? const Padding(
                      padding: EdgeInsets.all(6),
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: GColors.white),
                    )
                  : null),
        ),
        const SizedBox(width: 14),
        Text(label,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: state == 0 ? GColors.inkFaint : GColors.ink,
            )),
      ]),
    );
  }
}
