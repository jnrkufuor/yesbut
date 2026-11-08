import 'dart:convert';

import 'package:flutter/material.dart' hide Text;
import '../i18n/text.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/catalog_repository.dart';
import '../services/ingestion/page_meta.dart';
import '../services/ingestion/web_fetcher.dart';
import '../services/watch_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/loopy.dart';
import 'flows.dart';
import 'home_screen.dart' show PageHeader, TextLink;

/// Live: what changed in the terms you watch, what you're watching, and
/// which popular services updated their terms recently.
class LiveScreen extends StatefulWidget {
  const LiveScreen({super.key});
  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  List<_Trend>? _trending;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().refreshWatch();
      _loadTrending();
    });
  }

  Future<void> _loadTrending({bool force = false}) async {
    final state = context.read<AppState>();
    final items = (await state.catalog.load()).take(10).toList();
    final t = await _TrendCache.get(items, force: force);
    if (mounted) setState(() => _trending = t);
  }

  Future<void> _refresh() async {
    final state = context.read<AppState>();
    final n = await state.refreshWatch();
    await _loadTrending(force: true);
    if (mounted) showToast(context, n == 0 ? 'Nothing new right now.' : '$n of your terms changed.');
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final t = Theme.of(context).textTheme;
    final changed = state.watchlist.where((w) => w.changed).toList();
    final watching = state.watchlist;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: GColors.ink,
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 130),
          children: [
            ...staggered([
              const PageHeader(title: 'Live', icon: 'eye'),
              const SizedBox(height: 28),
              const HeadingText('What’s\n', serif: 'changed', size: 36),
              const SizedBox(height: 10),
              Text('Terms you watch are re-checked a couple of times a day. We’ll send a notification when one changes.',
                  style: t.bodyLarge?.copyWith(color: GColors.inkSoft)),
            ]),
            const SizedBox(height: 20),
            FadeInUp(index: 4, child: _sectionHead('Changes', state.checkingWatch ? 'Checking now…' : null)),
            if (changed.isEmpty)
              FadeInUp(
                index: 5,
                child: _Quiet(
                  text: watching.isEmpty
                      ? 'Watch a check and its changes show up here.'
                      : 'No changes since you started watching.',
                ),
              )
            else
              for (var i = 0; i < changed.length; i++) FadeInUp(index: 5 + i, child: _ChangeCard(item: changed[i])),
            const SizedBox(height: 18),
            FadeInUp(index: 7, child: _sectionHead('Watching', watching.isEmpty ? null : '${watching.length}')),
            if (watching.isEmpty)
              FadeInUp(
                index: 8,
                child: const _Hint(
                  'Open any check that came from a website and tap “Watch for changes”. '
                  'We’ll keep an eye on it for you.',
                ),
              )
            else
              for (var i = 0; i < watching.length; i++) FadeInUp(index: 8 + i, child: _WatchRow(item: watching[i])),
            const SizedBox(height: 18),
            FadeInUp(index: 10, child: _sectionHead('Recently updated', 'Popular services')),
            if (_trending == null)
              const FadeInUp(index: 11, child: _Quiet(text: 'Looking at popular terms…'))
            else
              for (var i = 0; i < _trending!.length; i++) FadeInUp(index: 11 + i, child: _TrendRow(t: _trending![i])),
          ],
        ),
      ),
    );
  }

  Widget _sectionHead(String title, String? trailing) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
          if (trailing != null) Text(trailing, style: const TextStyle(fontSize: 13, color: GColors.inkSoft)),
        ]),
      );
}

class _ChangeCard extends StatelessWidget {
  const _ChangeCard({required this.item});
  final WatchItem item;
  @override
  Widget build(BuildContext context) => Pressable(
        scale: 0.98,
        onTap: () => Flows.analyzeUrl(context, item.url, title: item.title),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: GColors.ink, borderRadius: BorderRadius.circular(30)),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: GColors.red, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text('CHANGED ${item.changedAt == null ? '' : timeAgo(item.changedAt!).toUpperCase()}',
                      style: TextStyle(
                          fontSize: 10.5, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: GColors.white.withValues(alpha: 0.7))),
                ]),
                const SizedBox(height: 6),
                Text(item.title,
                    style: const TextStyle(
                        fontFamily: AppTheme.display, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: GColors.white)),
                const SizedBox(height: 4),
                Text(
                  item.pageDate != null ? 'Now says updated ${PageMeta.formatMonth(item.pageDate!)}. Tap to see what’s different.' : 'Their terms were edited. Tap to re-check.',
                  style: TextStyle(fontSize: 13.5, height: 1.4, color: GColors.white.withValues(alpha: 0.85)),
                ),
              ]),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.arrow_outward_rounded, color: GColors.white),
          ]),
        ),
      );
}

class _WatchRow extends StatelessWidget {
  const _WatchRow({required this.item});
  final WatchItem item;
  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final score = item.score;
    return Pressable(
      scale: 0.98,
      onTap: () => Flows.analyzeUrl(context, item.url, title: item.title),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: GColors.line, width: 1),
        ),
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: score == null ? GColors.surface : GColors.forScore(score), shape: BoxShape.circle),
            child: Text(score == null ? '–' : '$score',
                style: TextStyle(
                    fontFamily: AppTheme.display,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: score == null ? GColors.inkSoft : GColors.onColor(GColors.forScore(score)))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: AppTheme.display, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
              Text(item.lastChecked == null ? 'Not checked yet' : 'Checked ${timeAgo(item.lastChecked!)}',
                  style: const TextStyle(fontSize: 12.5, color: GColors.inkSoft)),
            ]),
          ),
          Semantics(
            label: 'Stop watching',
            child: IconButton(
              onPressed: () => state.unwatch(item.url),
              icon: const LoopyIcon('eye', size: 24, color: GColors.ink, stroke: 2.4),
              tooltip: 'Stop watching',
            ),
          ),
        ]),
      ),
    );
  }
}

class _TrendRow extends StatelessWidget {
  const _TrendRow({required this.t});
  final _Trend t;
  @override
  Widget build(BuildContext context) {
    final fresh = t.updated != null && DateTime.now().difference(t.updated!).inDays < 60;
    return Pressable(
      scale: 0.98,
      onTap: () => Flows.library(context, t.item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: GColors.line, width: 1),
        ),
        child: Row(children: [
          LetterBadge(letter: t.item.initial, color: t.item.brandColor, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.item.name, style: const TextStyle(fontFamily: AppTheme.display, fontSize: 16, fontWeight: FontWeight.w700)),
              Text(t.updated == null ? 'Date not listed' : 'Updated ${PageMeta.formatMonth(t.updated!)}',
                  style: const TextStyle(fontSize: 12.5, color: GColors.inkSoft)),
            ]),
          ),
          if (fresh)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: GColors.red, borderRadius: BorderRadius.circular(99)),
              child: const Text('New', style: TextStyle(color: GColors.white, fontSize: 11.5, fontWeight: FontWeight.w600)),
            ),
        ]),
      ),
    );
  }
}

class _Quiet extends StatelessWidget {
  const _Quiet({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
        child: Row(children: [
          const LoopyIcon('check', size: 22, color: GColors.inkFaint, stroke: 2.2),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14, color: GColors.inkSoft))),
        ]),
      );
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: GColors.line, width: 1),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const LoopyIcon('eye', size: 26, stroke: 2.2),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5, height: 1.45))),
        ]),
      );
}

class _Trend {
  final CatalogItem item;
  final DateTime? updated;
  const _Trend(this.item, this.updated);
}

/// Reads the "Last updated" date of popular terms pages, cached for a day.
class _TrendCache {
  static const _key = 'trending_v1';

  static Future<List<_Trend>> get(List<CatalogItem> items, {bool force = false}) async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> cache = {};
    try {
      cache = jsonDecode(prefs.getString(_key) ?? '{}') as Map<String, dynamic>;
    } catch (_) {}
    final fresh = DateTime.tryParse('${cache['at']}');
    final stale = force || fresh == null || DateTime.now().difference(fresh).inHours > 24;
    final dates = Map<String, dynamic>.from((cache['dates'] as Map?) ?? {});
    if (stale) {
      await Future.wait(items.map((i) async {
        try {
          final p = await WebFetcher().fetch(i.url).timeout(const Duration(seconds: 15));
          dates[i.id] = p.updated?.toIso8601String();
        } catch (_) {}
      }));
      await prefs.setString(_key, jsonEncode({'at': DateTime.now().toIso8601String(), 'dates': dates}));
    }
    final list = [for (final i in items) _Trend(i, DateTime.tryParse('${dates[i.id]}'))]
      ..sort((a, b) => (b.updated ?? DateTime(1990)).compareTo(a.updated ?? DateTime(1990)));
    return list;
  }
}
