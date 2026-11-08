import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/catalog_repository.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/loopy.dart';
import 'flows.dart';
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
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 130),
            children: [
              const HeadingText('The ', serif: 'library'),
              const SizedBox(height: 6),
              Text('Popular terms we can fetch and check live — always the latest version.',
                  style: t.bodyLarge?.copyWith(color: GColors.inkSoft)),
              const SizedBox(height: 18),
              TextField(
                onChanged: (v) => setState(() => _q = v),
                textInputAction: TextInputAction.search,
                onSubmitted: (v) {
                  if (v.trim().isNotEmpty) Flows.search(context, query: v.trim());
                },
                decoration: InputDecoration(
                  hintText: 'Search Netflix, Spotify, or any company…',
                  prefixIcon: const Padding(
                    padding: EdgeInsets.all(13),
                    child: LoopyIcon('search', size: 22, stroke: 2.6),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(99),
                    borderSide: const BorderSide(color: GColors.ink, width: 1),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(99),
                    borderSide: const BorderSide(color: GColors.ink, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(99),
                    borderSide: const BorderSide(color: GColors.ink, width: 1),
                  ),
                ),
              ),
              if (_q.trim().length > 1) ...[
                const SizedBox(height: 10),
                _WebSearchRow(query: _q.trim()),
              ],
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
                    child: Text('Not in the library yet. Search the web above and we’ll sniff out their terms.',
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
          border: Border.all(color: GColors.line, width: 1),
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
              color: selected ? GColors.ink : GColors.white,
              border: Border.all(color: selected ? GColors.ink : GColors.line, width: 1),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 13.5,
                  color: selected ? GColors.white : GColors.ink,
                )),
          ),
        ),
      );
}


/// "Search the web for X" shortcut shown while typing in the library.
class _WebSearchRow extends StatelessWidget {
  const _WebSearchRow({required this.query});
  final String query;
  @override
  Widget build(BuildContext context) => Pressable(
        scale: 0.98,
        onTap: () => Flows.search(context, query: query),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(color: GColors.ink, borderRadius: BorderRadius.circular(99)),
          child: Row(children: [
            const LoopyIcon('search', size: 22, color: GColors.white, stroke: 2.6),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'Search the web for '),
                  TextSpan(text: '“$query”', style: const TextStyle(fontWeight: FontWeight.w700)),
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: GColors.white, fontSize: 14),
              ),
            ),
            const Icon(Icons.arrow_outward_rounded, color: GColors.white, size: 20),
          ]),
        ),
      );
}
