import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/catalog_repository.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/loopy.dart';
import 'flows.dart';
import 'home_screen.dart' show openLibraryItem, PageHeader;

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
              ...staggered([
                const PageHeader(title: 'Library', icon: 'library'),
                const SizedBox(height: 28),
                const HeadingText('Terms you’ve\n', serif: 'probably agreed to', size: 36),
                const SizedBox(height: 10),
                Text('Popular apps and services. We fetch their latest terms live and check them for you.',
                    style: t.bodyLarge?.copyWith(color: GColors.inkSoft)),
              ]),
              const SizedBox(height: 20),
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
              for (var i = 0; i < items.length; i++)
                FadeInUp(index: 4 + i, child: _Row(item: items[i], state: state)),
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
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
        decoration: BoxDecoration(
          color: GColors.white,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: GColors.ink, width: 1),
        ),
        child: Row(children: [
          LetterBadge(letter: item.initial, color: item.brandColor, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: AppTheme.display, fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
              const SizedBox(height: 1),
              Text('${item.kind} · ${item.category}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, color: GColors.inkSoft)),
            ]),
          ),
          const SizedBox(width: 8),
          if (cached != null)
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: GColors.forScore(cached.score), shape: BoxShape.circle),
              child: Text('${cached.score}',
                  style: TextStyle(
                    fontFamily: AppTheme.display,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: GColors.onColor(GColors.forScore(cached.score)),
                  )),
            )
          else
            // Not checked yet: a greyed-out search circle.
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: GColors.surface, shape: BoxShape.circle),
              child: const LoopyIcon('search', size: 22, color: GColors.inkFaint, stroke: 2.6),
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
              border: Border.all(color: GColors.ink, width: 1),
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
