import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import '../i18n/text.dart';
import 'package:provider/provider.dart';

import '../services/catalog_repository.dart';
import '../services/ingestion/page_meta.dart';
import '../services/ingestion/terms_finder.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/search_scene.dart';
import '../widgets/dialogs.dart';
import '../widgets/loopy.dart';
import 'flows.dart';
import 'home_screen.dart' show RoundIconButton, PageHeader;
import 'library_screen.dart';

/// "Find the fine print": search the web for a company's terms, show what we
/// found with how fresh each page is, then check the one you pick.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.initialQuery, this.embedded = false});
  final String? initialQuery;
  /// True when shown as a tab in the nav bar (no back button, room for the nav).
  final bool embedded;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _q = TextEditingController();
  final _focus = FocusNode();
  bool _busy = false;
  String _searched = '';
  FinderProgress _progress = const FinderProgress(FinderStage.searching);
  List<TermsCandidate>? _results;
  int _run = 0;

  @override
  void initState() {
    super.initState();
    _q.addListener(() => setState(() {}));
    if ((widget.initialQuery ?? '').isNotEmpty) {
      _q.text = widget.initialQuery!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _go());
    }
  }

  @override
  void dispose() {
    _q.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _go([String? preset]) async {
    final query = (preset ?? _q.text).trim();
    if (query.isEmpty) return;
    if (preset != null) _q.text = preset;
    _focus.unfocus();
    final run = ++_run;
    setState(() {
      _busy = true;
      _searched = query;
      _results = null;
      _progress = const FinderProgress(FinderStage.searching);
    });
    final minWait = Future<void>.delayed(const Duration(milliseconds: 1400));
    final lang = context.read<AppState>().settings.resultLanguage;
    final found = await TermsFinder().find(query, lang: lang, onProgress: (p) {
      if (mounted && run == _run) setState(() => _progress = p);
    });
    await minWait;
    if (!mounted || run != _run) return;
    setState(() {
      _busy = false;
      _results = found;
    });
  }

  void _open(TermsCandidate c) => Flows.analyzeUrl(
        context,
        c.url,
        title: c.title,
        pageDate: c.updated,
      );

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final page = Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 18, 16, widget.embedded ? 130 : 40),
          children: [
            ...staggered([
              if (!widget.embedded)
                Row(children: [RoundIconButton(icon: 'back', onTap: () => Navigator.of(context).maybePop())])
              else
                const PageHeader(title: 'Search', icon: 'search'),
              const SizedBox(height: 28),
              const FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: HeadingText('Look up any ', serif: 'company', size: 36),
              ),
              const SizedBox(height: 10),
              Text('Type a company or website. We’ll sniff out its terms and check how fresh they are.',
                  style: t.bodyLarge?.copyWith(color: GColors.inkSoft)),
              const SizedBox(height: 20),
              _SearchField(
                controller: _q,
                focus: _focus,
                busy: _busy,
                onSubmit: () => _go(),
              ),
            ]),
            const SizedBox(height: 32),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              switchInCurve: Curves.easeOutCubic,
              transitionBuilder: (c, a) => FadeTransition(
                opacity: a,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(a),
                  child: c,
                ),
              ),
              child: _busy
                  ? _Sniffing(key: const ValueKey('busy'), query: _searched, progress: _progress)
                  : _results == null
                      ? Column(
                          key: const ValueKey('idle'),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('OR PICK A POPULAR ONE',
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: GColors.inkSoft)),
                            const SizedBox(height: 10),
                            LibraryScreen(bare: true, query: _q.text.trim()),
                          ],
                        )
                      : _Results(
                          key: ValueKey('r$_run'),
                          query: _searched,
                          results: _results!,
                          onOpen: _open,
                          onRetry: () => _go(),
                        ),
            ),
          ],
        ),
      ),
    );
    return page;
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.focus, required this.busy, required this.onSubmit});
  final TextEditingController controller;
  final FocusNode focus;
  final bool busy;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final ok = controller.text.trim().isNotEmpty && !busy;
    return Container(
      height: 56,
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: GColors.ink, width: 1),
      ),
      child: Row(children: [
        const LoopyIcon('search', size: 22, stroke: 2.6),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focus,
            autofocus: false,
            textInputAction: TextInputAction.search,
            autocorrect: false,
            onSubmitted: (_) => onSubmit(),
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              hintText: context.tr('Netflix, gym name, netflix.com…'),
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
          ),
        ),
        Pressable(
          onTap: ok ? onSubmit : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ok ? GColors.ink : GColors.surface,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text('Search',
                style: TextStyle(
                  fontFamily: AppTheme.display,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: ok ? GColors.white : GColors.inkFaint,
                )),
          ),
        ),
      ]),
    );
  }
}

/// Idle state: a few one-tap ideas from the library.
class _Suggestions extends StatelessWidget {
  const _Suggestions({super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return FutureBuilder<List<CatalogItem>>(
      future: state.catalog.load(),
      builder: (context, snap) {
        final items = (snap.data ?? const <CatalogItem>[]).take(8).toList();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('TRY ONE',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: GColors.inkSoft)),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final i in items)
              Pressable(
                onTap: () => context.findAncestorStateOfType<_SearchScreenState>()?._go(i.name),
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.fromLTRB(5, 0, 12, 0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: GColors.ink, width: 1),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    LetterBadge(letter: i.initial, color: i.brandColor, size: 28),
                    const SizedBox(width: 7),
                    Text(i.name, style: const TextStyle(fontSize: 13)),
                  ]),
                ),
              ),
          ]),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: GColors.surface, borderRadius: BorderRadius.circular(24)),
            child: const Text(
              'We read the “Last updated” date on each page. If the newest version we can find is more than a '
              'year old, we’ll flag it so you know there might be a newer one.',
              style: TextStyle(fontSize: 13, height: 1.45, color: GColors.inkSoft),
            ),
          ),
        ]);
      },
    );
  }
}

/// Loading state: magnifier sweeping fine print + a live step list.
class _Sniffing extends StatefulWidget {
  const _Sniffing({super.key, required this.query, required this.progress});
  final String query;
  final FinderProgress progress;
  @override
  State<_Sniffing> createState() => _SniffingState();
}

class _SniffingState extends State<_Sniffing> {
  static const _quips = [
    'Sniffing out', 'Rummaging through', 'Squinting at', 'Digging up', 'Hunting down',
  ];
  int _i = 0;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 1700), (_) {
      if (mounted) setState(() => _i = (_i + 1) % _quips.length);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.progress;
    final step = switch (p.stage) {
      FinderStage.searching => 0,
      FinderStage.checking => 1,
      FinderStage.dating => 2,
      FinderStage.done => 3,
    };
    final name = widget.query.length > 22 ? '${widget.query.substring(0, 20)}…' : widget.query;
    final base = Theme.of(context).textTheme.headlineMedium!.copyWith(fontSize: 24);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SearchScene(height: 150, text: widget.query),
      const SizedBox(height: 24),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Text.rich(
          key: ValueKey(_i),
          TextSpan(children: [
            TextSpan(text: '${_quips[_i]} '),
            TextSpan(text: '$name’s', style: AppTheme.serifOf(base)),
            const TextSpan(text: ' terms…'),
          ]),
          style: base,
        ),
      ),
      const SizedBox(height: 18),
      _Step(label: 'Searching the web', state: step > 0 ? 2 : 1),
      _Step(
        label: p.total == 0 ? 'Checking pages that look legal' : 'Checking ${p.total} pages that look legal (${p.checked}/${p.total})',
        state: step > 1 ? 2 : (step == 1 ? 1 : 0),
      ),
      _Step(label: 'Reading the dates', state: step > 2 ? 2 : (step == 2 ? 1 : 0)),
    ]);
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.label, required this.state});
  final String label;
  final int state; // 0 pending, 1 active, 2 done
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: state == 2 ? GColors.blue : GColors.white,
              shape: BoxShape.circle,
              border: Border.all(color: state == 0 ? GColors.line : (state == 2 ? GColors.blue : GColors.ink), width: 1),
            ),
            child: state == 2
                ? const Icon(Icons.check_rounded, size: 15, color: GColors.white)
                : state == 1
                    ? const Center(child: _BlinkDot())
                    : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: TextStyle(fontSize: 15, color: state == 0 ? GColors.inkFaint : GColors.ink)),
          ),
        ]),
      );
}

class _BlinkDot extends StatefulWidget {
  const _BlinkDot();
  @override
  State<_BlinkDot> createState() => _BlinkDotState();
}

class _BlinkDotState extends State<_BlinkDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween(begin: 0.25, end: 1.0).animate(_c),
        child: Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(color: GColors.red, shape: BoxShape.circle),
        ),
      );
}

class _Results extends StatelessWidget {
  const _Results({super.key, required this.query, required this.results, required this.onOpen, required this.onRetry});
  final String query;
  final List<TermsCandidate> results;
  final ValueChanged<TermsCandidate> onOpen;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Couldn’t sniff anything out', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text(
          'Try the company’s website address (like netflix.com), or a different spelling. '
          'Some sites block automated readers. If you can open the terms in your browser, use Drop a link or Paste text.',
          style: TextStyle(fontSize: 14, height: 1.45, color: GColors.inkSoft),
        ),
        const SizedBox(height: 16),
        BigButton(label: 'Try again', onTap: onRetry),
      ]);
    }
    final host = results.first.host.replaceFirst('www.', '');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('FOUND ${results.length} PAGE${results.length == 1 ? '' : 'S'} ON ${host.toUpperCase()}',
          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: GColors.inkSoft)),
      const SizedBox(height: 10),
      for (var i = 0; i < results.length; i++)
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 380 + i * 90),
          curve: Curves.easeOutBack,
          builder: (context, v, child) => Opacity(
            opacity: v.clamp(0.0, 1.0),
            child: Transform.translate(offset: Offset(0, (1 - v) * 18), child: child),
          ),
          child: _ResultCard(c: results[i], best: i == 0, onTap: () => onOpen(results[i])),
        ),
      const SizedBox(height: 8),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          'Dates come from the page itself (“Last updated…”). Older than about a year? We flag it.',
          style: TextStyle(fontSize: 12.5, height: 1.45, color: GColors.inkSoft),
        ),
      ),
    ]);
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.c, required this.best, required this.onTap});
  final TermsCandidate c;
  final bool best;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = GColors.parseHex(c.themeColor) ?? GColors.ink;
    final letter = c.siteName.isEmpty ? '?' : c.siteName.characters.first.toUpperCase();
    final path = Uri.tryParse(c.url);
    final shortUrl = path == null ? c.url : '${path.host.replaceFirst('www.', '')}${path.path}';
    final chips = <Widget>[
      if (best) const _Chip('Best match', bg: GColors.ink, fg: GColors.white),
      if (c.updated != null)
        _Chip('Updated ${PageMeta.formatMonth(c.updated!)}',
            dot: c.stale ? GColors.green : GColors.blue, border: true)
      else
        const _Chip('Date not listed', bg: GColors.surface, fg: GColors.inkSoft),
      if (c.stale) const _Chip('May be out of date', bg: GColors.redSoft, fg: GColors.redText),
      if (c.scriptBuilt) const _Chip('Loads with scripts', bg: GColors.surface, fg: GColors.inkSoft),
    ];
    return Pressable(
      scale: 0.98,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: best ? GColors.ink : GColors.line, width: 1),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          LetterBadge(letter: letter, color: brand, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.title,
                  style: const TextStyle(
                      fontFamily: AppTheme.display, fontWeight: FontWeight.w700, fontSize: 17, letterSpacing: -0.4, height: 1.2)),
              const SizedBox(height: 3),
              Text(shortUrl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, color: GColors.inkSoft)),
              const SizedBox(height: 10),
              Wrap(spacing: 5, runSpacing: 5, children: chips),
            ]),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 10, left: 6),
            child: Icon(Icons.arrow_outward_rounded, size: 20, color: GColors.ink),
          ),
        ]),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, {this.bg = GColors.white, this.fg = GColors.ink, this.dot, this.border = false});
  final String label;
  final Color bg;
  final Color fg;
  final Color? dot;
  final bool border;
  @override
  Widget build(BuildContext context) => Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(99),
          border: border ? Border.all(color: GColors.line, width: 1) : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (dot != null) ...[
            Container(width: 7, height: 7, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
            const SizedBox(width: 6),
          ],
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
        ]),
      );
}
