import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/analysis.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

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

  void _share() => Share.share(r.toShareText(), subject: 'YesBut: ${r.title}');

  Future<void> _menu(String v) async {
    switch (v) {
      case 'text':
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => _OriginalTextScreen(title: r.title, text: r.text),
        ));
      case 'delete':
        await context.read<AppState>().delete(r.id);
        if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final shown = _filter == null ? r.findings : r.bySeverity(_filter!);
    final jargon = _allJargon ? r.jargon : r.jargon.take(5).toList();

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        actions: [
          IconButton(onPressed: _share, icon: const Icon(Icons.ios_share_rounded), tooltip: 'Share'),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz_rounded),
            onSelected: _menu,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GRadius.md)),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'text', child: Text('View original text')),
              PopupMenuItem(value: 'delete', child: Text('Delete this check')),
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        children: [
          _SourceChip(result: r),
          const SizedBox(height: 10),
          Text(r.title, style: t.headlineMedium),
          const SizedBox(height: 18),
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
            _Tldr(lines: r.tldr),
          ],
          const SizedBox(height: 30),
          SectionTitle('The gotchas', trailing: Text('${r.findings.length}', style: t.titleLarge?.copyWith(color: GColors.inkFaint))),
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
                _filter == null ? 'No gotchas spotted.' : 'Nothing in this bucket.',
                style: const TextStyle(color: GColors.inkSoft, fontWeight: FontWeight.w600),
              ),
            )
          else
            for (final f in shown) _FindingCard(finding: f),
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
        ],
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
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: GColors.surface, borderRadius: BorderRadius.circular(99)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: GColors.inkSoft),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: GColors.inkSoft)),
          ),
        ]),
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.result});
  final AnalysisResult result;

  @override
  Widget build(BuildContext context) {
    final r = result;
    final c = GColors.textForScore(r.score);
    return SoftCard(
      color: GColors.softForScore(r.score),
      padding: const EdgeInsets.all(18),
      radius: GRadius.xl,
      child: Row(children: [
        ScoreRing(score: r.score, size: 104),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('FAIRNESS SCORE',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: c)),
              const SizedBox(height: 2),
              Text(r.verdict,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.8, height: 1.1)),
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final s in Severity.values)
                  if (r.count(s) > 0) _MiniCount(severity: s, count: r.count(s)),
              ]),
              if (r.findings.isEmpty)
                Text('${r.readMinutes} min read saved',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: GColors.inkSoft)),
            ],
          ),
        ),
      ]),
    );
  }
}

class _MiniCount extends StatelessWidget {
  const _MiniCount({required this.severity, required this.count});
  final Severity severity;
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = GColors.textForSeverity(severity);
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 4, 9, 4),
      decoration: BoxDecoration(color: GColors.white, borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(severityIcon(severity), size: 13, color: c),
        const SizedBox(width: 4),
        Text('$count', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: c)),
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
              border: Border.all(color: GColors.line, width: 1.5),
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
  const _Tldr({required this.lines});
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    const dots = [GColors.red, GColors.blue, GColors.green];
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      decoration: BoxDecoration(color: GColors.ink, borderRadius: BorderRadius.circular(GRadius.xl)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.bolt_rounded, color: GColors.white, size: 20),
          SizedBox(width: 6),
          Text('The short version',
              style: TextStyle(color: GColors.white, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
        ]),
        const SizedBox(height: 14),
        for (var i = 0; i < lines.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 9,
                height: 9,
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(color: dots[i % 3], shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(lines[i],
                    style: TextStyle(
                      color: GColors.white.withValues(alpha: 0.92),
                      fontSize: 15,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
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
            color: selected ? color : GColors.white,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: selected ? color : GColors.line, width: 1.5),
          ),
          child: Text('$label  $count',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13.5,
                color: selected ? GColors.onColor(color) : GColors.ink,
              )),
        ),
      ),
    );
  }
}

class _FindingCard extends StatefulWidget {
  const _FindingCard({required this.finding});
  final Finding finding;

  @override
  State<_FindingCard> createState() => _FindingCardState();
}

class _FindingCardState extends State<_FindingCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final f = widget.finding;
    final c = GColors.forSeverity(f.severity);
    final ct = GColors.textForSeverity(f.severity);
    final hasQuote = f.quote != null && f.quote!.trim().isNotEmpty;
    return Pressable(
      scale: 0.985,
      onTap: hasQuote ? () => setState(() => _open = !_open) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: GColors.white,
          borderRadius: BorderRadius.circular(GRadius.lg),
          border: Border.all(color: _open ? c : GColors.line, width: 1.5),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: GColors.softForSeverity(f.severity), borderRadius: BorderRadius.circular(13)),
              child: Icon(severityIcon(f.severity), color: ct, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${f.severity.label.toUpperCase()} · ${f.category.toUpperCase()}',
                    style: TextStyle(fontSize: 10.5, letterSpacing: 0.9, fontWeight: FontWeight.w800, color: ct)),
                const SizedBox(height: 3),
                Text(f.title,
                    style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, letterSpacing: -0.3, height: 1.2)),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          Text(f.plain, style: const TextStyle(fontSize: 14.5, height: 1.45, color: Color(0xFF34374A))),
          if (hasQuote)
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 220),
              crossFadeState: _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              firstChild: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(children: [
                  Text('See what it actually says',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: ct)),
                  Icon(Icons.expand_more_rounded, size: 18, color: ct),
                ]),
              ),
              secondChild: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: GColors.softForSeverity(f.severity),
                  borderRadius: BorderRadius.circular(GRadius.sm),
                ),
                child: Text('“${f.quote!.trim()}”',
                    style: const TextStyle(fontSize: 13.5, height: 1.5, fontStyle: FontStyle.italic, color: GColors.inkSoft)),
              ),
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
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: GColors.line, width: 1.5))),
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
