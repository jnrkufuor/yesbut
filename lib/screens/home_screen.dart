import 'package:flutter/material.dart';
import 'package:animations/animations.dart';
import 'package:provider/provider.dart';

import '../services/catalog_repository.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/loopy.dart';
import '../widgets/tiles.dart';
import 'flows.dart';
import 'link_screen.dart';
import 'paste_screen.dart';
import 'scan_screen.dart';
import 'upload_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onSeeLibrary, required this.onSeeHistory, this.onSearch});
  final VoidCallback onSeeLibrary;
  final VoidCallback onSeeHistory;
  final VoidCallback? onSearch;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  // One controller drives the staggered load-in of every block.
  late final AnimationController _in =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..forward();

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  Widget _stagger(int i, Widget child, {double rise = 14, bool pop = false}) {
    final start = (i * 0.07).clamp(0.0, 0.7);
    final anim = CurvedAnimation(
      parent: _in,
      curve: Interval(start, (start + 0.45).clamp(0.0, 1.0), curve: Curves.easeOutBack),
    );
    final fade = CurvedAnimation(parent: _in, curve: Interval(start, (start + 0.3).clamp(0.0, 1.0)));
    return AnimatedBuilder(
      animation: _in,
      builder: (context, c) => Opacity(
        opacity: fade.value,
        child: Transform.translate(
          offset: Offset(0, (1 - anim.value) * (pop ? 26 : rise)),
          child: Transform.scale(scale: pop ? 0.9 + 0.1 * anim.value : 1, child: c),
        ),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final recent = state.history.take(3).toList();
    final t = Theme.of(context).textTheme;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 130),
        children: [
          _stagger(
            0,
            Row(children: [
              const Wordmark(size: 25),
              const Spacer(),
              if (state.settings.aiReady)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: GColors.line, width: 1),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const Text('AI on',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: GColors.blue)),
                ),
              RoundIconButton(
                icon: 'settings',
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
              ),
            ]),
          ),
          const SizedBox(height: 28),
          _stagger(1, const HeadingText('What are you\nabout to ', serif: 'agree to?', size: 36), rise: 18),
          const SizedBox(height: 10),
          _stagger(
            2,
            Text('We read the fine print and point out the catch, in plain English.',
                style: t.bodyLarge?.copyWith(color: GColors.inkSoft)),
          ),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
              child: _stagger(
                3,
                _GrowCard(
                  page: const ScanScreen(),
                  title: 'Scan it',
                  subtitle: 'Paper in front of you',
                  icon: 'scan',
                  color: GColors.red,
                                  ),
                pop: true,
              ),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: _stagger(
                4,
                _GrowCard(
                  page: const UploadScreen(),
                  title: 'Upload',
                  subtitle: 'PDF or text file',
                  icon: 'upload',
                  color: GColors.blue,
                                  ),
                pop: true,
              ),
            ),
          ]),
          const SizedBox(height: 5),
          Row(children: [
            Expanded(
              child: _stagger(
                5,
                _GrowCard(
                  page: const PasteScreen(),
                  title: 'Paste text',
                  subtitle: 'Copy, paste, done',
                  icon: 'paste',
                  color: GColors.green,
                                  ),
                pop: true,
              ),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: _stagger(
                6,
                _GrowCard(
                  page: const LinkScreen(),
                  title: 'Drop a link',
                  subtitle: 'Any T&C web page',
                  icon: 'link',
                  color: GColors.ink,
                                  ),
                pop: true,
              ),
            ),
          ]),
          const SizedBox(height: 28),
          _stagger(
            7,
            Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Expanded(child: Text('Popular fine print', style: t.titleLarge)),
              TextLink('See all', onTap: widget.onSeeLibrary),
            ]),
          ),
          const SizedBox(height: 12),
          _stagger(
            9,
            SizedBox(
              height: 42,
              child: FutureBuilder<List<CatalogItem>>(
                future: state.catalog.load(),
                builder: (context, snap) {
                  final items = snap.data ?? const <CatalogItem>[];
                  return ListView.separated(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    itemCount: items.length.clamp(0, 12).toInt(),
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (context, i) => BrandPill(
                      letter: items[i].initial,
                      name: items[i].name,
                      color: items[i].brandColor,
                      onTap: () => _openLibrary(context, state, items[i]),
                    ),
                  );
                },
              ),
            ),
          ),
          if (recent.isNotEmpty) ...[
            const SizedBox(height: 28),
            Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Expanded(child: Text('Recent checks', style: t.titleLarge)),
              TextLink('History', onTap: widget.onSeeHistory),
            ]),
            const SizedBox(height: 12),
            for (final r in recent) HistoryTile(result: r, onTap: () => Flows.open(context, r)),
          ],
          const SizedBox(height: 22),
          Center(
            child: Text(
              'Not legal advice, just a very fast friend who reads contracts.',
              textAlign: TextAlign.center,
              style: t.bodySmall?.copyWith(color: GColors.inkFaint),
            ),
          ),
        ],
      ),
    );
  }
}

/// A home card that grows into its full-screen sheet (container transform),
/// and shrinks back into place when you go back.
class _GrowCard extends StatelessWidget {
  const _GrowCard({
    required this.page,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
  final Widget page;
  final String title;
  final String subtitle;
  final String icon;
  final Color color;

  @override
  Widget build(BuildContext context) => OpenContainer(
        transitionDuration: const Duration(milliseconds: 420),
        transitionType: ContainerTransitionType.fade,
        closedElevation: 0,
        openElevation: 0,
        closedColor: color,
        openColor: color,
        middleColor: color,
        closedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
        openShape: const RoundedRectangleBorder(),
        tappable: false,
        closedBuilder: (context, open) => ActionTile(
          title: title,
          subtitle: subtitle,
          icon: icon,
          color: color,
          onTap: open,
        ),
        openBuilder: (context, _) => page,
      );
}

/// Library items: reuse a fresh saved check (< 7 days) or fetch live.
void _openLibrary(BuildContext context, AppState state, CatalogItem item) {
  final cached = state.cachedFor(item.url);
  if (cached != null && DateTime.now().difference(cached.analyzedAt).inDays < 7) {
    Flows.open(context, cached);
  } else {
    Flows.library(context, item);
  }
}

void openLibraryItem(BuildContext context, AppState state, CatalogItem item) =>
    _openLibrary(context, state, item);

/// Top row shared by every main tab: page icon + name at the same size as the
/// home logo, settings on the right. Keeps the big heading at the same height
/// on every screen.
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, required this.icon});
  final String title;
  final String icon;

  @override
  Widget build(BuildContext context) => Row(children: [
        LoopyIcon(icon, size: 26, stroke: 2.6),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
              fontFamily: AppTheme.display,
              fontSize: 25,
              fontWeight: FontWeight.w700,
              letterSpacing: -1,
              height: 1,
            )),
        const Spacer(),
        RoundIconButton(
          icon: 'settings',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
        ),
      ]);
}

/// 50px circle with a hairline border and a loopy icon (settings, back, share).
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({super.key, required this.icon, required this.onTap, this.label});
  final String icon;
  final VoidCallback onTap;
  final String? label;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: Container(
          height: 50,
          width: label == null ? 50 : null,
          padding: label == null ? null : const EdgeInsets.fromLTRB(14, 0, 18, 0),
          decoration: BoxDecoration(
            color: GColors.white,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: GColors.line, width: 1),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
            LoopyIcon(icon, size: 24, stroke: 2.4),
            if (label != null) ...[
              const SizedBox(width: 6),
              Text(label!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ]),
        ),
      );
}

class TextLink extends StatelessWidget {
  const TextLink(this.label, {super.key, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Text(label,
              style: const TextStyle(
                color: GColors.ink,
                fontWeight: FontWeight.w400,
                fontSize: 13,
                decoration: TextDecoration.underline,
              )),
        ),
      );
}

/// Pill that looks like a search field and opens the web search.
class SearchBarButton extends StatelessWidget {
  const SearchBarButton({super.key, required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Pressable(
        scale: 0.98,
        onTap: onTap,
        child: Container(
          height: 50,
          padding: const EdgeInsets.fromLTRB(16, 0, 6, 0),
          decoration: BoxDecoration(
            color: GColors.surface,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Row(children: [
            const LoopyIcon('search', size: 22, stroke: 2.6),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Search any company’s terms',
                  style: TextStyle(fontSize: 14.5, color: GColors.inkSoft)),
            ),
            Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: GColors.ink, borderRadius: BorderRadius.circular(99)),
              child: const Text('Find',
                  style: TextStyle(
                      fontFamily: AppTheme.display, color: GColors.white, fontWeight: FontWeight.w700, fontSize: 14)),
            ),
          ]),
        ),
      );
}
