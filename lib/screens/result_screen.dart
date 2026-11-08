import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;
import '../i18n/text.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/analysis.dart';
import '../services/analysis/context_profile.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/dialogs.dart';
import '../widgets/loopy.dart';
import 'home_screen.dart' show RoundIconButton;

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key, required this.result, this.fresh = false});
  final AnalysisResult result;
  final bool fresh;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  Severity? _filter;
  bool _allJargon = false;

  AnalysisResult get r => widget.result;

  final _scroll = ScrollController();
  bool _showMini = false; // score badge top-right once the hero scrolls away
  bool _showTop = false; // back-to-top button

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final o = _scroll.offset;
      final mini = o > 300, top = o > 700;
      if (mini != _showMini || top != _showTop) {
        setState(() {
          _showMini = mini;
          _showTop = top;
        });
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _tts?.stop();
    super.dispose();
  }

  // ---- read aloud
  FlutterTts? _tts;
  bool _speaking = false;

  String _script() {
    final b = StringBuffer()
      ..writeln('${r.title}.')
      ..writeln(r.summary ?? '')
      ..writeln('Fairness score: ${r.score} out of 100. ${r.verdict}.');
    for (final t in r.tldr) {
      b.writeln(t);
    }
    for (final f in r.findings) {
      final label = switch (f.severity) {
        Severity.redFlag => 'Red flag',
        Severity.headsUp => 'Heads up',
        Severity.goodNews => 'Good news',
      };
      b.writeln('$label: ${f.title}. ${f.plain}');
    }
    return b.toString();
  }

  Future<void> _toggleSpeak() async {
    final tts = _tts ??= FlutterTts();
    if (_speaking) {
      await tts.stop();
      if (mounted) setState(() => _speaking = false);
      return;
    }
    tts.setCompletionHandler(() {
      if (mounted) setState(() => _speaking = false);
    });
    tts.setCancelHandler(() {
      if (mounted) setState(() => _speaking = false);
    });
    await tts.setSpeechRate(0.48);
    setState(() => _speaking = true);
    await tts.speak(_script());
  }

  void _share() => SharePlus.instance.share(
        ShareParams(text: r.toShareText(), subject: 'YesBut: ${r.title}'),
      );

  Future<void> _menu(String v) async {
    switch (v) {
      case 'text':
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => _OriginalTextScreen(title: r.title, text: r.text),
        ));
      case 'delete':
        if (!await confirmDeleteOne(context, r.title)) return;
        if (!mounted) return;
        await context.read<AppState>().delete(r.id);
        if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final shown = _filter == null ? r.findings : r.bySeverity(_filter!);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Stack(children: [
        CustomScrollView(
        controller: _scroll,
        slivers: [
        SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        sliver: SliverList.list(children: staggered([
          Row(children: [
            RoundIconButton(icon: 'back', onTap: () => Navigator.of(context).maybePop()),
            const Spacer(),
            if (webUrlOf(r) != null) ...[
              _TrackButton(result: r),
              const SizedBox(width: 6),
            ],
            Semantics(label: 'Share', button: true, child: RoundIconButton(icon: 'share', onTap: _share)),
            const SizedBox(width: 6),
            Semantics(
              label: 'Delete this check',
              button: true,
              child: Pressable(
                onTap: () => _menu('delete'),
                child: Container(
                  width: 50,
                  height: 50,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: GColors.red, shape: BoxShape.circle),
                  child: const LoopyIcon('trash', size: 24, color: GColors.white, stroke: 2.4),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 18),
          _SourceChip(result: r),
          const SizedBox(height: 10),
          Text(r.title, style: t.headlineLarge?.copyWith(fontSize: 32)),
          const SizedBox(height: 20),
        ])),
        ),
        // The score stays put: everything below scrolls up and tucks under it.
        PinnedHeaderSliver(
          child: ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: FadeInUp(index: 4, child: _ScoreCard(result: r)),
            ),
          ),
        ),
        SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
        sliver: SliverList.list(children: staggered([
          if (r.summary != null || r.audience != null || r.dealType != 'general' || r.industry != 'general') ...[
            const SizedBox(height: 6),
            _AboutCard(result: r),
          ],
          if (r.note != null) ...[
            const SizedBox(height: 12),
            SoftCard(
              color: GColors.blueSoft,
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                const Icon(Icons.info_rounded, color: GColors.blue, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(r.note!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
              ]),
            ),
          ],
          if (r.keyFacts.isNotEmpty) ...[
            const SizedBox(height: 26),
            const SectionTitle('Quick facts'),
            _KeyFacts(facts: r.keyFacts),
          ],

          if (r.tldr.isNotEmpty) ...[
            const SizedBox(height: 26),
            _Tldr(result: r),
          ],
          const SizedBox(height: 30),
          SectionTitle('The catches', trailing: Text('${r.findings.length}', style: t.titleLarge?.copyWith(color: GColors.inkFaint))),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(children: [
              _FilterChip(
                label: 'All',
                count: r.findings.length,
                color: GColors.ink,
                selected: _filter == null,
                onTap: () => setState(() => _filter = null),
              ),
              for (final s in Severity.values)
                _FilterChip(
                  label: s == Severity.redFlag ? 'Red flags' : s.label,
                  count: r.count(s),
                  color: GColors.forSeverity(s),
                  selected: _filter == s,
                  onTap: () => setState(() => _filter = s),
                ),
            ]),
          ),
          const SizedBox(height: 14),
          if (shown.isEmpty)
            SoftCard(
              child: Text(
                _filter == null ? 'No catches spotted.' : 'Nothing in this bucket.',
                style: const TextStyle(color: GColors.inkSoft, fontWeight: FontWeight.w600),
              ),
            )
          else
            for (final f in shown) _FindingCard(finding: f, sourceUrl: webUrlOf(r), jargon: r.jargon),
          if (r.questions.isNotEmpty) ...[
            const SizedBox(height: 26),
            const SectionTitle('Ponder before you agree'),
            SoftCard(
              color: GColors.blueSoft,
              child: Column(children: [
                for (var i = 0; i < r.questions.length; i++)
                  Padding(
                    padding: EdgeInsets.only(bottom: i == r.questions.length - 1 ? 0 : 14),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(color: GColors.blue, shape: BoxShape.circle),
                        child: Text('${i + 1}',
                            style: const TextStyle(color: GColors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(r.questions[i],
                            style: const TextStyle(fontSize: 14.5, height: 1.4, fontWeight: FontWeight.w600)),
                      ),
                    ]),
                  ),
              ]),
            ),
          ],
          const SizedBox(height: 26),
          Center(
            child: Text(
              'Checked with ${r.engine} engine · ${r.wordCount} words · ${timeAgo(r.analyzedAt)}\n'
              'Not legal advice. For big commitments, talk to a lawyer.',
              textAlign: TextAlign.center,
              style: t.bodySmall?.copyWith(color: GColors.inkFaint),
            ),
          ),
        ], start: 5)),
        ),
        ],
      ),
        // Back to top.
        Positioned(
          right: 16,
          bottom: 24 + MediaQuery.of(context).padding.bottom,
          child: IgnorePointer(
            ignoring: !_showTop,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              scale: _showTop ? 1 : 0.6,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _showTop ? 1 : 0,
                child: Semantics(
                  button: true,
                  label: 'Back to top',
                  child: Pressable(
                    onTap: () => _scroll.animateTo(0, duration: const Duration(milliseconds: 700), curve: Curves.easeOutCubic),
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: GColors.ink,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: GColors.ink.withValues(alpha: 0.2), blurRadius: 18, offset: const Offset(0, 8))],
                      ),
                      child: const Icon(Icons.arrow_upward_rounded, color: GColors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        ]),
      ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.result});
  final AnalysisResult result;

  @override
  Widget build(BuildContext context) {
    final icon = switch (result.sourceKind) {
      SourceKind.paste => Icons.content_paste_rounded,
      SourceKind.link => Icons.link_rounded,
      SourceKind.scan => Icons.document_scanner_rounded,
      SourceKind.file => Icons.description_rounded,
      SourceKind.library => Icons.auto_stories_rounded,
    };
    var label = result.sourceKind.label;
    final ref = result.sourceRef;
    if (ref != null) {
      final host = Uri.tryParse(ref)?.host ?? '';
      if (host.isNotEmpty) label = '$label · ${host.replaceFirst('www.', '')}';
    }
    final url = webUrlOf(result);
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: url == null ? GColors.surface : GColors.white,
        borderRadius: BorderRadius.circular(99),
        border: url == null ? null : Border.all(color: GColors.ink, width: 1),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: url == null ? GColors.inkSoft : GColors.ink),
        const SizedBox(width: 6),
        Flexible(
          child: Text(label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w600, color: url == null ? GColors.inkSoft : GColors.ink)),
        ),
        if (url != null) ...[
          const SizedBox(width: 6),
          const Icon(Icons.arrow_outward_rounded, size: 14, color: GColors.ink),
        ],
      ]),
    );
    return Align(
      alignment: Alignment.centerLeft,
      child: url == null
          ? chip
          : Semantics(
              link: true,
              label: 'Open the original page',
              child: Pressable(onTap: () => openExternal(context, url), child: chip),
            ),
    );
  }
}

class _ScoreCard extends StatefulWidget {
  const _ScoreCard({required this.result});
  final AnalysisResult result;
  @override
  State<_ScoreCard> createState() => _ScoreCardState();
}

/// Big colored score card. Tap it and it fades to charcoal and grows to
/// explain what the fairness score means; tap again to fold it back.
class _ScoreCardState extends State<_ScoreCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final bg = GColors.forScore(r.score);
    final fg = GColors.onColor(bg);
    return Semantics(
      button: true,
      label: 'Fairness score ${r.score}, ${r.verdict}. Tap for what it means.',
      child: GestureDetector(
        onTap: () => setState(() => _open = !_open),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          curve: const Cubic(0.2, 0.9, 0.2, 1),
          decoration: BoxDecoration(
            color: _open ? GColors.ink : bg,
            borderRadius: BorderRadius.circular(32),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(children: [
            Positioned(
              right: -36,
              top: 10,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: _open ? 0 : 1,
                child: LoopyAccent('score', color: GColors.deep(bg), size: 150, stroke: 2),
              ),
            ),
            // Front (score) and back (what it means) swap, and the card
            // grows or shrinks to fit whichever is showing.
            AnimatedSize(
              duration: const Duration(milliseconds: 560),
              curve: const Cubic(0.2, 0.9, 0.2, 1),
              alignment: Alignment.topCenter,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                switchInCurve: const Interval(0.3, 1, curve: Curves.easeOut),
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.topLeft,
                  children: [...previous, if (current != null) current],
                ),
                child: _open
                    ? const Padding(
                        key: ValueKey('back'),
                        padding: EdgeInsets.all(20),
                        child: _ScoreExplainer(),
                      )
                    : KeyedSubtree(
                        key: const ValueKey('front'),
                        child: SizedBox(
                height: 168,
                width: double.infinity,
                child: Stack(alignment: Alignment.center, children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                      Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: r.score.toDouble()),
                          duration: const Duration(milliseconds: 1100),
                          curve: Curves.easeOutCubic,
                          builder: (context, v, _) => Text('${v.round()}',
                              style: TextStyle(
                                fontFamily: AppTheme.display,
                                fontWeight: FontWeight.w700,
                                fontSize: 92,
                                letterSpacing: -5,
                                height: 0.82,
                                color: fg,
                              )),
                        ),
                        const SizedBox(height: 8),
                        Text('/100', style: TextStyle(fontSize: 13, color: fg.withValues(alpha: 0.7))),
                      ]),
                      Flexible(
                        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('FAIRNESS SCORE',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.3, color: fg)),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(r.verdict,
                                style: TextStyle(
                                  fontFamily: AppTheme.display,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.6,
                                  height: 1,
                                  color: fg,
                                )),
                          ),
                          const SizedBox(height: 7),
                          Wrap(spacing: 5, runSpacing: 5, children: [
                            for (final s in Severity.values) _MiniCount(severity: s, count: r.count(s)),
                          ]),
                        ]),
                      ),
                    ]),
                  ),
                ]),
),
                      ),
              ),
            ),
            // Expand / contract toggle, fully visible on both sides.
            Positioned(
              top: 14,
              right: 16,
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: _open ? 1 : 0),
                duration: const Duration(milliseconds: 520),
                curve: Curves.easeInOutCubic,
                builder: (context, t, _) => CustomPaint(
                  size: const Size(18, 18),
                  painter: _ExpandArrows(t, Color.lerp(fg, GColors.white, t)!),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ScoreExplainer extends StatelessWidget {
  const _ScoreExplainer();
  @override
  Widget build(BuildContext context) {
    const w = GColors.white;
    Widget row(String a, String b) => Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 92, child: Text(a, style: const TextStyle(color: w, fontSize: 13, fontWeight: FontWeight.w700))),
            Expanded(child: Text(b, style: TextStyle(color: w.withValues(alpha: 0.75), fontSize: 13, height: 1.35))),
          ]),
        );
    Widget range(Color c, String n, String l) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 9, height: 9, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(n, style: const TextStyle(color: w, fontSize: 12.5, fontWeight: FontWeight.w700)),
          Text(' $l', style: TextStyle(color: w.withValues(alpha: 0.8), fontSize: 12.5)),
        ]);
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('What the score means',
          style: TextStyle(fontFamily: AppTheme.display, color: w, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
      const SizedBox(height: 6),
      Text('How fair these terms are to you, from 0 to 100. Higher means fewer surprises.',
          style: TextStyle(color: w.withValues(alpha: 0.85), fontSize: 13.5, height: 1.4)),
      const SizedBox(height: 14),
      Text('WHAT WE LOOK AT',
          style: TextStyle(color: w.withValues(alpha: 0.55), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
      const SizedBox(height: 8),
      row('Money', 'auto-renewals, fees, price hikes, refunds'),
      row('Your rights', 'arbitration, class-action waivers, liability'),
      row('Your data', 'tracking, sharing, selling, keeping it'),
      row('Commitment', 'lock-ins, cancelling, changing the terms'),
      const SizedBox(height: 8),
      Text('Every contract starts at 100. Red flags knock off a lot, heads-ups a little, good news adds some back.',
          style: TextStyle(color: w.withValues(alpha: 0.85), fontSize: 13, height: 1.4)),
      const SizedBox(height: 16),
      Text('THE SCORES',
          style: TextStyle(color: w.withValues(alpha: 0.55), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
      const SizedBox(height: 8),
      Wrap(spacing: 14, runSpacing: 6, children: [
        range(GColors.blue, '70+', 'fair'),
        range(GColors.green, '45–69', 'careful'),
        range(GColors.red, '0–44', 'yikes'),
      ]),
      const SizedBox(height: 8),
      Text('A quick gut check, not legal advice.', style: TextStyle(color: w.withValues(alpha: 0.45), fontSize: 11)),
    ]);
  }
}

class _MiniCount extends StatelessWidget {
  const _MiniCount({required this.severity, required this.count});
  final Severity severity;
  final int count;

  @override
  Widget build(BuildContext context) {
    final dot = GColors.forSeverity(severity);
    return Container(
      height: 26,
      padding: const EdgeInsets.fromLTRB(9, 0, 10, 0),
      decoration: BoxDecoration(color: GColors.ink, borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text('$count', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: GColors.white)),
      ]),
    );
  }
}

class _KeyFacts extends StatelessWidget {
  const _KeyFacts({required this.facts});
  final List<KeyFact> facts;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final w = (box.maxWidth - 10) / 2;
      return Wrap(spacing: 10, runSpacing: 10, children: [
        for (final f in facts)
          Container(
            width: w,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: GColors.line, width: 1),
              borderRadius: BorderRadius.circular(GRadius.md),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(f.label.toUpperCase(),
                  style: const TextStyle(
                      fontSize: 10.5, letterSpacing: 1.1, fontWeight: FontWeight.w800, color: GColors.inkFaint)),
              const SizedBox(height: 4),
              Text(f.value, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, height: 1.25)),
            ]),
          ),
      ]);
    });
  }
}

class _Tldr extends StatelessWidget {
  const _Tldr({required this.result});
  final AnalysisResult result;

  /// Dot color = the severity of the catch the line talks about, so a red
  /// flag line always gets a red dot and good news always gets blue.
  bool _isSummary(String line) {
    final l = line.toLowerCase();
    return l.startsWith('found ') || l.startsWith('no common') || l.startsWith('that was short') ||
        !result.findings.any((f) => l.contains(f.title.toLowerCase()));
  }

  Color _dotFor(String line) {
    final l = line.toLowerCase();
    for (final f in result.findings) {
      final t = f.title.toLowerCase();
      if (t.isNotEmpty && (l.startsWith(t) || l.contains(t))) return GColors.forSeverity(f.severity);
    }
    if (l.startsWith('on the plus side') || l.contains('good news')) return GColors.blue;
    return GColors.forScore(result.score);
  }

  @override
  Widget build(BuildContext context) {
    final lines = result.tldr;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      decoration: BoxDecoration(color: GColors.ink, borderRadius: BorderRadius.circular(32)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'Yes, '),
            TextSpan(
              text: 'but…',
              style: AppTheme.serifOf(const TextStyle(fontSize: 20, color: GColors.white)),
            ),
          ]),
          style: const TextStyle(
              fontFamily: AppTheme.display, color: GColors.white, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.4),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < lines.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // The opening summary line gets a light asterisk; the rest get a
              // dot in the color of the catch they describe.
              i == 0 && _isSummary(lines[i])
                  ? const Padding(
                      padding: EdgeInsets.only(top: 3),
                      child: BrandAsterisk(size: 12, color: Color(0xFFD9D5D1)),
                    )
                  : Container(
                      width: 9,
                      height: 9,
                      margin: const EdgeInsets.only(top: 6, left: 1.5, right: 1.5),
                      decoration: BoxDecoration(color: _dotFor(lines[i]), shape: BoxShape.circle),
                    ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(lines[i],
                    style: TextStyle(
                      color: GColors.white.withValues(alpha: 0.92),
                      fontSize: 15,
                      height: 1.45,
                      fontWeight: FontWeight.w400,
                    )),
              ),
            ]),
          ),
      ]),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? GColors.ink : GColors.white,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: GColors.ink, width: 1),
          ),
          child: Text('$label $count',
              style: TextStyle(
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                fontSize: 12.5,
                color: selected ? GColors.white : GColors.ink,
              )),
        ),
      ),
    );
  }
}

class _FindingCard extends StatefulWidget {
  const _FindingCard({required this.finding, this.sourceUrl, this.jargon = const []});
  final Finding finding;
  final Uri? sourceUrl;
  final List<JargonTerm> jargon;

  @override
  State<_FindingCard> createState() => _FindingCardState();
}

class _FindingCardState extends State<_FindingCard> {
  bool _open = false;

  static const _icon = {Severity.redFlag: 'flag', Severity.headsUp: 'eye', Severity.goodNews: 'check'};

  /// Jargon terms that actually appear in this catch (title, plain or quote).
  List<JargonTerm> _termsHere() {
    final f = widget.finding;
    final hay = '${f.title} ${f.plain} ${f.quote ?? ''}'.toLowerCase();
    return widget.jargon.where((j) => j.term.trim().length > 2 && hay.contains(j.term.toLowerCase())).take(4).toList();
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.finding;
    final bg = GColors.forSeverity(f.severity);
    final fg = GColors.onColor(bg);
    final hasQuote = f.quote != null && f.quote!.trim().isNotEmpty;
    final terms = _termsHere();
    final label = switch (f.severity) {
      Severity.redFlag => 'RED FLAG',
      Severity.headsUp => 'HEADS UP',
      Severity.goodNews => 'GOOD NEWS',
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(30)),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$label · ${f.category.toUpperCase()}',
                  style: TextStyle(fontSize: 10.5, letterSpacing: 1.2, fontWeight: FontWeight.w600, color: fg)),
              const SizedBox(height: 6),
              Text(f.title,
                  style: TextStyle(
                      fontFamily: AppTheme.display,
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      height: 1.12,
                      color: fg)),
            ]),
          ),
          const SizedBox(width: 10),
          LoopyIcon(_icon[f.severity]!, size: 30, color: fg, stroke: 2.2),
        ]),
        const SizedBox(height: 10),
        Text(f.plain, style: TextStyle(fontSize: 14, height: 1.45, color: fg)),
        if (terms.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final j in terms)
              _JargonChip(term: j, fg: fg, bg: bg),
          ]),
        ],
        if (hasQuote) ...[
          const SizedBox(height: 12),
          // Only the link toggles the quote, not the whole card.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(_open ? 'Hide the fine print' : 'See the fine print*',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      color: fg,
                      decoration: TextDecoration.underline,
                      decorationColor: fg,
                    )),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 380),
                  curve: Curves.easeOutCubic,
                  child: Icon(Icons.expand_more_rounded, size: 18, color: fg),
                ),
              ]),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 420),
            curve: const Cubic(0.2, 0.9, 0.2, 1),
            alignment: Alignment.topCenter,
            child: !_open
                ? const SizedBox(width: double.infinity)
                : TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 360),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, child) => Opacity(
                      opacity: v,
                      child: Transform.translate(offset: Offset(0, (1 - v) * 10), child: child),
                    ),
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: GColors.white, borderRadius: BorderRadius.circular(18)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text.rich(
                          TextSpan(children: [
                            const TextSpan(text: 'The fine print* ', style: TextStyle(fontWeight: FontWeight.w700)),
                            TextSpan(
                              text: '“${f.quote!.trim()}”',
                              style: const TextStyle(fontFamily: AppTheme.serif, fontStyle: FontStyle.italic, fontSize: 14),
                            ),
                          ]),
                          style: const TextStyle(fontSize: 12.5, height: 1.45, color: GColors.ink),
                        ),
                        if (widget.sourceUrl != null) ...[
                          const SizedBox(height: 10),
                          Pressable(
                            onTap: () => openExternal(context, jumpToQuote(widget.sourceUrl!, f.quote!)),
                            child: Container(
                              height: 34,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(color: GColors.ink, borderRadius: BorderRadius.circular(99)),
                              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                Text('See it on their page',
                                    style: TextStyle(color: GColors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
                                SizedBox(width: 6),
                                Icon(Icons.arrow_outward_rounded, size: 15, color: GColors.white),
                              ]),
                            ),
                          ),
                        ],
                      ]),
                    ),
                  ),
          ),
        ],
      ]),
    );
  }
}

/// Small pop-up that explains one piece of jargon.
Future<void> showJargon(BuildContext context, JargonTerm j) => showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: GColors.ink.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (ctx, _, __) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Material(
            color: GColors.ink,
            borderRadius: BorderRadius.circular(30),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('JARGON, DECODED',
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        color: GColors.white.withValues(alpha: 0.6))),
                const SizedBox(height: 8),
                Text(j.term,
                    style: const TextStyle(
                        fontFamily: AppTheme.display,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.6,
                        color: GColors.white)),
                const SizedBox(height: 8),
                Text(j.meaning, style: const TextStyle(fontSize: 15, height: 1.45, color: GColors.white)),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerRight,
                  child: Pressable(
                    onTap: () => Navigator.of(ctx).pop(),
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: GColors.white, borderRadius: BorderRadius.circular(99)),
                      child: const Text('Got it',
                          style: TextStyle(fontFamily: AppTheme.display, fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
      transitionBuilder: (ctx, a, _, child) => FadeTransition(
        opacity: a,
        child: ScaleTransition(
          scale: Tween(begin: 0.92, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.easeOutBack)),
          child: child,
        ),
      ),
    );

class _JargonRow extends StatelessWidget {
  const _JargonRow({required this.term});
  final JargonTerm term;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: GColors.line, width: 1))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(term.term, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        const SizedBox(height: 3),
        Text(term.meaning, style: const TextStyle(color: GColors.inkSoft, height: 1.4, fontSize: 14)),
      ]),
    );
  }
}

class _OriginalTextScreen extends StatelessWidget {
  const _OriginalTextScreen({required this.title, required this.text});
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title, overflow: TextOverflow.ellipsis)),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
          child: SelectableText(text, style: const TextStyle(fontSize: 14.5, height: 1.6)),
        ),
      );
}


/// The web page a check came from, if it came from one.
Uri? webUrlOf(AnalysisResult r) {
  final ref = r.sourceRef;
  if (ref == null) return null;
  final u = Uri.tryParse(ref);
  if (u == null || !(u.scheme == 'http' || u.scheme == 'https') || u.host.isEmpty) return null;
  return u;
}

/// Link that opens the page and scrolls to (and highlights) the quoted
/// sentence, using the browser's "scroll to text" fragment. Browsers that
/// don't support it simply open the page.
Uri jumpToQuote(Uri page, String quote) {
  final words = quote
      .replaceAll(RegExp(r'[…"“”]'), ' ')
      .replaceAll(RegExp(r'\.{3,}'), ' ')
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.length < 3) return page;
  String enc(List<String> ws) => Uri.encodeComponent(ws.join(' ')).replaceAll('-', '%2D').replaceAll(',', '%2C');
  final frag = words.length > 12
      ? '${enc(words.take(5).toList())},${enc(words.sublist(words.length - 4))}'
      : enc(words);
  final base = page.toString().split('#').first;
  return Uri.parse('$base#:~:text=$frag');
}

Future<void> openExternal(BuildContext context, Uri url) async {
  final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) showToast(context, 'Couldn’t open that page.');
}


/// "What this is" + "Who it applies to", right under the score.
class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.result});
  final AnalysisResult result;

  @override
  Widget build(BuildContext context) {
    Widget label(String t) => Text(t,
        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: GColors.inkSoft));
    final r = result;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: GColors.line, width: 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (r.summary != null) ...[
          label('WHAT THIS IS'),
          const SizedBox(height: 6),
          Text(r.summary!, style: const TextStyle(fontSize: 14.5, height: 1.45)),
        ],
        if (r.audience != null) ...[
          if (r.summary != null) const SizedBox(height: 14),
          label('WHO IT APPLIES TO'),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            _RoleChip(text: r.audience!, primary: true),
            if (r.otherParty != null) _RoleChip(text: 'Also mentions ${r.otherParty}', primary: false),
          ]),
        ],
        const SizedBox(height: 14),
        label('HOW WE CHECKED IT'),
        const SizedBox(height: 6),
        Text('${ContextProfiler.weightingNote(r.dealType)} ${ContextProfiler.industryNote(r.industry)}'.trim(),
            style: const TextStyle(fontSize: 14, height: 1.45)),
        if (r.language != 'en') ...[
          const SizedBox(height: 12),
          Text('Original language: ${ContextProfiler.languageNames[r.language] ?? r.language}',
              style: const TextStyle(fontSize: 12.5, color: GColors.inkSoft)),
        ],
      ]),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.text, required this.primary});
  final String text;
  final bool primary;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: primary ? GColors.ink : GColors.white,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: GColors.ink, width: 1),
        ),
        child: Text(text,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: primary ? GColors.white : GColors.ink)),
      );
}

/// Checklist of what people care about for this kind of deal.
class _FocusList extends StatelessWidget {
  const _FocusList({required this.items});
  final List<FocusItem> items;
  @override
  Widget build(BuildContext context) => Column(children: [
        for (final f in items)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: f.found ? GColors.ink : GColors.line, width: 1),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(top: 1),
                decoration: BoxDecoration(
                  color: f.found ? GColors.blue : GColors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: f.found ? GColors.blue : GColors.line, width: 1),
                ),
                child: f.found
                    ? const Icon(Icons.check_rounded, size: 15, color: GColors.white)
                    : const Icon(Icons.remove_rounded, size: 15, color: GColors.inkFaint),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Text(f.label,
                          style: const TextStyle(
                              fontFamily: AppTheme.display, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                    ),
                    Text(f.found ? 'Covered' : 'Not mentioned',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: f.found ? GColors.blue : GColors.inkSoft)),
                  ]),
                  const SizedBox(height: 2),
                  Text(f.why, style: const TextStyle(fontSize: 13, color: GColors.inkSoft)),
                  if (f.excerpt != null) ...[
                    const SizedBox(height: 8),
                    Text('“${f.excerpt}”',
                        style: const TextStyle(
                            fontFamily: AppTheme.serif, fontStyle: FontStyle.italic, fontSize: 14, height: 1.4)),
                  ] else ...[
                    const SizedBox(height: 6),
                    const Text('Worth asking about before you agree.', style: TextStyle(fontSize: 12.5)),
                  ],
                ]),
              ),
            ]),
          ),
      ]);
}


/// Two neckless corner arrowheads. t=0: pointing out (expand). As t goes to
/// 1 each one slides toward the centre and flips, so they point in (contract).
class _ExpandArrows extends CustomPainter {
  _ExpandArrows(this.t, this.color);
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final s = size.width;
    final arm = s * 0.36;
    // Corners in the "expand" pose.
    final tr = Offset(s * 0.9, s * 0.1);
    final bl = Offset(s * 0.1, s * 0.9);
    // In the "contract" pose the corners sit nearer the middle.
    final trIn = Offset(s * 0.6, s * 0.4);
    final blIn = Offset(s * 0.4, s * 0.6);
    void corner(Offset a, Offset b, double sign) {
      final c = Offset.lerp(a, b, t)!;
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(3.14159265 * t);
      final path = Path()
        ..moveTo(-arm * sign, 0)
        ..lineTo(0, 0)
        ..lineTo(0, arm * sign);
      canvas.drawPath(path, p);
      canvas.restore();
    }

    corner(tr, trIn, 1);
    corner(bl, blIn, -1);
  }

  @override
  bool shouldRepaint(_ExpandArrows old) => old.t != t || old.color != color;
}


/// Jargon pill. Tap it: the pill fills in (so you can see which one) and a
/// small note grows out from right underneath it. Tap again or wait to close.
class _JargonChip extends StatefulWidget {
  const _JargonChip({required this.term, required this.fg, required this.bg});
  final JargonTerm term;
  final Color fg;
  final Color bg;
  @override
  State<_JargonChip> createState() => _JargonChipState();
}

class _JargonChipState extends State<_JargonChip> with SingleTickerProviderStateMixin {
  final _link = LayerLink();
  OverlayEntry? _entry;
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
  bool get _showing => _entry != null;

  void _toggle() => _showing ? _hide() : _show();

  void _show() {
    final screenW = MediaQuery.sizeOf(context).width;
    // Open toward the side with room, and never wider than that room.
    final box = context.findRenderObject() as RenderBox?;
    final left = box?.localToGlobal(Offset.zero).dx ?? 16;
    final right = left + (box?.size.width ?? 0);
    final toLeft = (left + right) / 2 > screenW / 2;
    final room = (toLeft ? right - 16 : screenW - left - 16).clamp(140.0, screenW - 32);
    final maxW = math.min(screenW * 0.72, room);
    final anchor = toLeft ? Alignment.topRight : Alignment.topLeft;
    _entry = OverlayEntry(
      builder: (ctx) => Stack(children: [
        Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: _hide)),
        CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          targetAnchor: toLeft ? Alignment.bottomRight : Alignment.bottomLeft,
          followerAnchor: anchor,
          offset: const Offset(0, 8),
          child: Align(
            alignment: anchor,
            child: ScaleTransition(
              alignment: anchor,
              scale: CurvedAnimation(parent: _c, curve: Curves.easeOutBack),
              child: FadeTransition(
                opacity: _c,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    constraints: BoxConstraints(maxWidth: maxW),
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 11),
                    decoration: BoxDecoration(
                      color: GColors.ink,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: GColors.ink.withValues(alpha: 0.2), blurRadius: 14, offset: const Offset(0, 6))],
                    ),
                    child: Text(widget.term.meaning,
                        style: const TextStyle(color: GColors.white, fontSize: 13, height: 1.4)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
    Overlay.of(context).insert(_entry!);
    _c.forward(from: 0);
    setState(() {});
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _showing) _hide();
    });
  }

  Future<void> _hide() async {
    if (!_showing) return;
    await _c.reverse();
    _entry?.remove();
    _entry = null;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _entry?.remove();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final on = _showing;
    final fg = widget.fg, bg = widget.bg;
    return CompositedTransformTarget(
      link: _link,
      child: Semantics(
        button: true,
        label: '${widget.term.term}: ${widget.term.meaning}',
        child: Pressable(
          onTap: _toggle,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 30,
            padding: const EdgeInsets.fromLTRB(11, 0, 8, 0),
            decoration: BoxDecoration(
              color: on ? fg : Colors.transparent,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: fg, width: 1),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Flexible(
                child: Text(widget.term.term,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: on ? bg : fg)),
              ),
              const SizedBox(width: 5),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 16,
                height: 16,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: on ? bg : fg, shape: BoxShape.circle),
                child: Text(on ? '×' : '?',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: on ? fg : bg, height: 1)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}


/// Bell in the header: track this page. We re-check it in the background
/// and send a notification when the terms change.
class _TrackButton extends StatelessWidget {
  const _TrackButton({required this.result});
  final AnalysisResult result;
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final on = state.isWatching(result.sourceRef);
    return Semantics(
      button: true,
      toggled: on,
      label: on ? 'Tracking changes' : 'Track changes',
      child: Pressable(
        onTap: () async {
          if (on) {
            await state.unwatch(result.sourceRef!);
            if (context.mounted) showToast(context, 'Stopped tracking.');
          } else {
            await state.watch(result);
            if (context.mounted) showToast(context, 'Tracking. We’ll let you know if these terms change.');
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 50,
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? GColors.ink : GColors.white,
            shape: BoxShape.circle,
            border: Border.all(color: on ? GColors.ink : GColors.line, width: 1),
          ),
          child: TweenAnimationBuilder<double>(
            key: ValueKey(on),
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 520),
            builder: (_, v, child) => Transform.rotate(
              angle: on ? 0.35 * (1 - v) * math.sin(v * math.pi * 4) : 0,
              alignment: Alignment.topCenter,
              child: child,
            ),
            child: LoopyIcon('bell', size: 24, color: on ? GColors.white : GColors.ink, stroke: 2.4),
          ),
        ),
      ),
    );
  }
}
