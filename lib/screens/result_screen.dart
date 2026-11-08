import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/analysis.dart';
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
    final jargon = _allJargon ? r.jargon : r.jargon.take(5).toList();

    return LeaveGuard(
      child: Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
        children: staggered([
          Row(children: [
            RoundIconButton(icon: 'back', onTap: () => Navigator.of(context).maybePop()),
            const Spacer(),
            RoundIconButton(icon: 'share', label: 'Share', onTap: _share),
            const SizedBox(width: 6),
            PopupMenuButton<String>(
              onSelected: _menu,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GRadius.md)),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'text', child: Text('View original text')),
                PopupMenuItem(value: 'delete', child: Text('Delete this check')),
              ],
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: GColors.line, width: 1),
                ),
                child: const Icon(Icons.more_horiz_rounded, color: GColors.ink),
              ),
            ),
          ]),
          const SizedBox(height: 18),
          _SourceChip(result: r),
          const SizedBox(height: 10),
          Text(r.title, style: t.headlineLarge?.copyWith(fontSize: 32)),
          const SizedBox(height: 20),
          _ScoreCard(result: r),
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
            for (final f in shown) _FindingCard(finding: f, sourceUrl: webUrlOf(r)),
          if (r.questions.isNotEmpty) ...[
            const SizedBox(height: 26),
            const SectionTitle('Ask before you sign'),
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
          if (r.jargon.isNotEmpty) ...[
            const SizedBox(height: 26),
            const SectionTitle('Jargon decoder'),
            for (final j in jargon) _JargonRow(term: j),
            if (r.jargon.length > 5)
              Center(
                child: TextButton(
                  onPressed: () => setState(() => _allJargon = !_allJargon),
                  child: Text(_allJargon ? 'Show less' : 'Show all ${r.jargon.length} terms',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
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
        ]),
      ),
      ),
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
          height: _open ? 400 : 168,
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
            // Front: number + verdict + counts.
            AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: _open ? 0 : 1,
              child: SizedBox(
                height: 168,
                width: double.infinity,
                child: Stack(alignment: Alignment.center, children: [
                  Positioned(
                    top: 15,
                    right: 17,
                    child: Opacity(
                      opacity: 0.45,
                      child: Icon(Icons.open_in_full_rounded, size: 14, color: fg),
                    ),
                  ),
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
            // Back: what the score means.
            IgnorePointer(
              ignoring: !_open,
              child: AnimatedOpacity(
                duration: Duration(milliseconds: _open ? 350 : 150),
                opacity: _open ? 1 : 0,
                curve: _open ? const Interval(0.4, 1) : Curves.linear,
                child: const Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 18),
                  child: _ScoreExplainer(),
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
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
      const Spacer(),
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
              Container(
                width: 9,
                height: 9,
                margin: const EdgeInsets.only(top: 6),
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
  const _FindingCard({required this.finding, this.sourceUrl});
  final Finding finding;
  final Uri? sourceUrl;

  @override
  State<_FindingCard> createState() => _FindingCardState();
}

class _FindingCardState extends State<_FindingCard> {
  bool _open = false;

  static const _icon = {Severity.redFlag: 'flag', Severity.headsUp: 'eye', Severity.goodNews: 'check'};

  @override
  Widget build(BuildContext context) {
    final f = widget.finding;
    final bg = GColors.forSeverity(f.severity);
    final fg = GColors.onColor(bg);
    final hasQuote = f.quote != null && f.quote!.trim().isNotEmpty;
    final label = switch (f.severity) {
      Severity.redFlag => 'RED FLAG',
      Severity.headsUp => 'HEADS UP',
      Severity.goodNews => 'GOOD NEWS',
    };
    return Pressable(
      scale: 0.985,
      onTap: hasQuote ? () => setState(() => _open = !_open) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(30)),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          Padding(
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
              if (hasQuote)
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 220),
                  crossFadeState: _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                  firstChild: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text('See the fine print*',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                          color: fg,
                          decoration: TextDecoration.underline,
                          decorationColor: fg,
                        )),
                  ),
                  secondChild: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 12),
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
            ]),
          ),
        ]),
      ),
    );
  }
}

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
