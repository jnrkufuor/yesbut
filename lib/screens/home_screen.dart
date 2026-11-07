import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/catalog_repository.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/tiles.dart';
import 'flows.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onSeeLibrary, required this.onSeeHistory});
  final VoidCallback onSeeLibrary;
  final VoidCallback onSeeHistory;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final recent = state.history.take(3).toList();
    final t = Theme.of(context).textTheme;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
        children: [
          Row(children: [
            const Wordmark(size: 28),
            const Spacer(),
            if (state.settings.aiReady)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: GColors.greenSoft,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.auto_awesome_rounded, size: 14, color: GColors.greenText),
                  SizedBox(width: 4),
                  Text('AI on', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: GColors.greenText)),
                ]),
              ),
            _RoundIcon(
              icon: Icons.tune_rounded,
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
            ),
          ]),
          const SizedBox(height: 28),
          Text.rich(
            TextSpan(children: [
              const TextSpan(text: 'What are you\nabout to '),
              TextSpan(text: 'agree to?', style: TextStyle(color: GColors.blue, decorationColor: GColors.blue.withValues(alpha: 0.3))),
            ]),
            style: t.headlineLarge?.copyWith(fontSize: 34),
          ),
          const SizedBox(height: 10),
          Text(
            'We read the fine print and tell you the gotchas — in plain English.',
            style: t.bodyLarge?.copyWith(color: GColors.inkSoft),
          ),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
              child: ActionTile(
                title: 'Scan it',
                subtitle: 'Paper in front of you',
                icon: Icons.document_scanner_rounded,
                color: GColors.red,
                onTap: () => Flows.scan(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ActionTile(
                title: 'Upload',
                subtitle: 'PDF or text file',
                icon: Icons.upload_file_rounded,
                color: GColors.blue,
                onTap: () => Flows.upload(context),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: ActionTile(
                title: 'Paste text',
                subtitle: 'Copy, paste, done',
                icon: Icons.content_paste_rounded,
                color: GColors.green,
                onTap: () => Flows.paste(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ActionTile(
                title: 'Drop a link',
                subtitle: 'Any T&C web page',
                icon: Icons.link_rounded,
                color: GColors.ink,
                onTap: () => Flows.link(context),
              ),
            ),
          ]),
          const SizedBox(height: 30),
          SectionTitle('Popular fine print',
              trailing: _TextLink('See all', onTap: onSeeLibrary)),
          SizedBox(
            height: 132,
            child: FutureBuilder<List<CatalogItem>>(
              future: state.catalog.load(),
              builder: (context, snap) {
                final items = snap.data ?? const <CatalogItem>[];
                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  itemCount: items.length.clamp(0, 10).toInt(),
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, i) => LibraryCard(
                    item: items[i],
                    checked: state.cachedFor(items[i].url),
                    onTap: () => _openLibrary(context, state, items[i]),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 30),
          SectionTitle('Recent checks',
              trailing: recent.isEmpty ? null : _TextLink('History', onTap: onSeeHistory)),
          if (recent.isEmpty)
            SoftCard(
              child: Row(children: [
                const HopDots(size: 10),
                const SizedBox(width: 16),
                Expanded(
                  child: Text('Nothing yet. Your first check is one tap away.',
                      style: t.bodyMedium?.copyWith(color: GColors.inkSoft, fontWeight: FontWeight.w600)),
                ),
              ]),
            )
          else
            for (final r in recent)
              HistoryTile(result: r, onTap: () => Flows.open(context, r)),
          const SizedBox(height: 22),
          Center(
            child: Text(
              'Not legal advice — just a very fast friend who reads contracts.',
              textAlign: TextAlign.center,
              style: t.bodySmall?.copyWith(color: GColors.inkFaint),
            ),
          ),
        ],
      ),
    );
  }
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

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(color: GColors.surface, shape: BoxShape.circle),
          child: Icon(icon, color: GColors.ink, size: 21),
        ),
      );
}

class _TextLink extends StatelessWidget {
  const _TextLink(this.label, {required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Text(label,
              style: const TextStyle(color: GColors.blue, fontWeight: FontWeight.w800, fontSize: 14)),
        ),
      );
}
