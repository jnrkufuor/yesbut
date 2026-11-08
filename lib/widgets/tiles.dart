import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;
import '../i18n/text.dart';

import '../models/analysis.dart';
import '../services/catalog_repository.dart';
import '../theme/app_theme.dart';
import 'common.dart';
import 'loopy.dart';

/// Big colored entry-point card on the home screen (V2).
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
  final String icon; // Loopy icon + accent name
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = GColors.onColor(color);
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 172,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(40)),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          Positioned(
            right: -6,
            bottom: -8,
            child: LoopyAccent(icon, color: GColors.deep(color), size: 128, stroke: 2),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 20, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Transform.translate(
                    offset: const Offset(-8, -8),
                    child: _TileIcon(icon, color: fg),
                  ),
                  const Spacer(),
                  FlowArrow(color: fg, size: 22),
                ]),
                const Spacer(),
                Text(title,
                    style: TextStyle(
                      fontFamily: AppTheme.display,
                      color: fg,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      height: 1.1,
                    )),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: TextStyle(
                      color: fg.withValues(alpha: 0.85),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w400,
                    )),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

/// Outlined brand pill: colored letter circle + name.
class BrandPill extends StatelessWidget {
  const BrandPill({super.key, required this.letter, required this.name, required this.color, required this.onTap});
  final String letter;
  final String name;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: Container(
          height: 42,
          padding: const EdgeInsets.fromLTRB(5, 0, 13, 0),
          decoration: BoxDecoration(
            color: GColors.white,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: GColors.ink, width: 1),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Text(letter,
                  style: TextStyle(
                      color: color.computeLuminance() > 0.6 ? GColors.ink : GColors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13)),
            ),
            const SizedBox(width: 7),
            Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400)),
          ]),
        ),
      );
}

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
          color: GColors.surface,
          borderRadius: BorderRadius.circular(GRadius.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              LetterBadge(letter: item.initial, color: item.brandColor, size: 40),
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
          padding: const EdgeInsets.all(10),
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: GColors.white,
            border: Border.all(color: GColors.line, width: 1),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Row(children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: GColors.forScore(r.score),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text('${r.score}',
                  style: TextStyle(
                    fontFamily: AppTheme.display,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: GColors.onColor(GColors.forScore(r.score)),
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
                      style: const TextStyle(
                          fontFamily: AppTheme.display, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                  const SizedBox(height: 3),
                  Text(
                    '${red == 0 ? 'No red flags' : '$red red flag${red == 1 ? '' : 's'}'} · ${r.sourceKind.label} · ${timeAgo(r.analyzedAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, color: GColors.inkSoft, fontWeight: FontWeight.w400),
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


/// The big card icon does its own little move when the card is tapped:
/// scan pinches in, upload lifts, paste wobbles, link swings.
class _TileIcon extends TapReactive {
  const _TileIcon(this.icon, {required this.color});
  final String icon;
  final Color color;
  @override
  State<_TileIcon> createState() => _TileIconState();
}

class _TileIconState extends TapReactiveState<_TileIcon> {
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: tap,
        builder: (_, child) {
          final v = tap.value;
          if (!tap.isAnimating) return child!;
          final decay = 1 - v;
          return switch (widget.icon) {
            'scan' => Transform.scale(scale: 1 - 0.16 * math.sin(v * math.pi * 2) * decay, child: child),
            'upload' => Transform.translate(offset: Offset(0, -9 * math.sin(v * math.pi) * (v < 0.6 ? 1 : decay * 2.5)), child: child),
            'paste' => Transform.rotate(angle: 0.16 * math.sin(v * math.pi * 3) * decay, child: child),
            _ => Transform.rotate(
                angle: 0.28 * math.sin(v * math.pi * 2.5) * decay,
                alignment: const Alignment(0.2, -0.7),
                child: child,
              ),
          };
        },
        child: LoopyIcon(widget.icon, size: 70, color: widget.color, stroke: 1.5),
      );
}
