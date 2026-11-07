import 'package:flutter/material.dart';

import '../models/analysis.dart';
import '../services/catalog_repository.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// Big colored entry-point tile on the home screen.
class ActionTile extends StatelessWidget {
  const ActionTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = GColors.onColor(color);
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 156,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(GRadius.lg)),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          Positioned(
            right: -26,
            bottom: -30,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: GColors.white.withValues(alpha: 0.13),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 22,
            top: 22,
            child: Icon(Icons.arrow_outward_rounded,
                color: fg.withValues(alpha: 0.7), size: 20),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: GColors.white,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(icon, color: color == GColors.green ? GColors.greenText : color, size: 24),
                ),
                const Spacer(),
                Text(title,
                    style: TextStyle(
                      color: fg,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    )),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                      color: fg.withValues(alpha: 0.82),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    )),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

/// Small card for a library item.
class LibraryCard extends StatelessWidget {
  const LibraryCard({super.key, required this.item, required this.onTap, this.checked});
  final CatalogItem item;
  final VoidCallback onTap;
  final AnalysisResult? checked;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: GColors.softNamed(item.color),
          borderRadius: BorderRadius.circular(GRadius.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              LetterBadge(letter: item.initial, color: GColors.named(item.color), size: 40),
              const Spacer(),
              if (checked != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: GColors.white,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text('${checked!.score}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: GColors.textForScore(checked!.score),
                      )),
                ),
            ]),
            const Spacer(),
            Text(item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
            Text(item.kind,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: GColors.inkSoft, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/// Row for a past check.
class HistoryTile extends StatelessWidget {
  const HistoryTile({super.key, required this.result, required this.onTap, this.onLongPress});
  final AnalysisResult result;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final r = result;
    final red = r.count(Severity.redFlag);
    return GestureDetector(
      onLongPress: onLongPress,
      child: Pressable(
        onTap: onTap,
        scale: 0.98,
        child: Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: GColors.white,
            border: Border.all(color: GColors.line, width: 1.5),
            borderRadius: BorderRadius.circular(GRadius.md),
          ),
          child: Row(children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: GColors.softForScore(r.score),
                borderRadius: BorderRadius.circular(15),
              ),
              alignment: Alignment.center,
              child: Text('${r.score}',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: GColors.textForScore(r.score),
                    letterSpacing: -0.5,
                  )),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, letterSpacing: -0.2)),
                  const SizedBox(height: 3),
                  Text(
                    '${red == 0 ? 'No red flags' : '$red red flag${red == 1 ? '' : 's'}'} · ${r.sourceKind.label} · ${timeAgo(r.analyzedAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, color: GColors.inkSoft, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: GColors.inkFaint),
          ]),
        ),
      ),
    );
  }
}
