import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/catalog_repository.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'home_screen.dart' show openLibraryItem;

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String _q = '';
  String? _cat;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final t = Theme.of(context).textTheme;

    return SafeArea(
      bottom: false,
      child: FutureBuilder<List<CatalogItem>>(
        future: state.catalog.load(),
        builder: (context, snap) {
          final all = snap.data ?? const <CatalogItem>[];
          final cats = <String>{for (final i in all) i.category}.toList();
          final items = all.where((i) {
            final q = _q.toLowerCase();
            final okQ = q.isEmpty || i.name.toLowerCase().contains(q) || i.kind.toLowerCase().contains(q);
            final okC = _cat == null || i.category == _cat;
            return okQ && okC;
          }).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
            children: [
              Text('The library', style: t.headlineLarge),
              const SizedBox(height: 6),
              Text('Popular terms we can fetch and check live — always the latest version.',
                  style: t.bodyLarge?.copyWith(color: GColors.inkSoft)),
              const SizedBox(height: 18),
              TextField(
                onChanged: (v) => setState(() => _q = v),
                decoration: const InputDecoration(
                  hintText: 'Search Netflix, Spotify, Uber…',
                  prefixIcon: Icon(Icons.search_rounded, color: GColors.inkFaint),
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                child: Row(children: [
                  _Cat(label: 'All', selected: _cat == null, onTap: () => setState(() => _cat = null)),
                  for (final c in cats)
                    _Cat(label: c, selected: _cat == c, onTap: () => setState(() => _cat = c)),
                ]),
              ),
              const SizedBox(height: 16),
              for (final item in items) _Row(item: item, state: state),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Center(
                    child: Text('Not in the library yet — use "Drop a link" on the Check tab.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: GColors.inkSoft, fontWeight: FontWeight.w600)),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.item, required this.state});
  final CatalogItem item;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final cached = state.cachedFor(item.url);
    return Pressable(
      scale: 0.98,
      onTap: () => openLibraryItem(context, state, item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: GColors.line, width: 1.5),
          borderRadius: BorderRadius.circular(GRadius.md),
        ),
        child: Row(children: [
          LetterBadge(letter: item.initial, color: GColors.named(item.color)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.2)),
              const SizedBox(height: 2),
              Text('${item.kind} · ${item.category}',
                  style: const TextStyle(fontSize: 12.5, color: GColors.inkSoft, fontWeight: FontWeight.w500)),
            ]),
          ),
          if (cached != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: GColors.softForScore(cached.score),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text('${cached.score}',
                  style: TextStyle(fontWeight: FontWeight.w900, color: GColors.textForScore(cached.score))),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(color: GColors.ink, borderRadius: BorderRadius.circular(99)),
              child: const Text('Check',
                  style: TextStyle(color: GColors.white, fontWeight: FontWeight.w800, fontSize: 13)),
            ),
        ]),
      ),
    );
  }
}

class _Cat extends StatelessWidget {
  const _Cat({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Pressable(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? GColors.blue : GColors.surface,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                  color: selected ? GColors.white : GColors.ink,
                )),
          ),
        ),
      );
}
