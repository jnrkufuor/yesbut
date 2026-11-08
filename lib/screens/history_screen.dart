import 'package:flutter/material.dart' hide Text;
import '../i18n/text.dart';
import 'package:provider/provider.dart';

import '../models/analysis.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/dialogs.dart';
import '../widgets/loopy.dart';
import '../widgets/tiles.dart';
import 'home_screen.dart' show PageHeader, TextLink;
import 'flows.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  Future<void> _actions(BuildContext context, AppState state, AnalysisResult r) async {
    final v = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: GColors.white,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.edit_rounded),
            title: const Text('Rename', style: TextStyle(fontWeight: FontWeight.w700)),
            onTap: () => Navigator.pop(ctx, 'rename'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_rounded, color: GColors.red),
            title: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700, color: GColors.red)),
            onTap: () => Navigator.pop(ctx, 'delete'),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (!context.mounted) return;
    if (v == 'delete' && await confirmDeleteOne(context, r.title)) await state.delete(r.id);
    if (v == 'rename') {
      if (!context.mounted) return;
      final c = TextEditingController(text: r.title);
      final name = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: GColors.white,
          title: const Text('Rename check'),
          content: TextField(controller: c, autofocus: true),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Save')),
          ],
        ),
      );
      if (name != null && name.isNotEmpty) await state.rename(r.id, name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final t = Theme.of(context).textTheme;
    final items = state.history;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 130),
        children: [
          ...staggered([
            const PageHeader(title: 'History', icon: 'history'),
            const SizedBox(height: 28),
            const HeadingText('Everything you’ve\n', serif: 'checked', size: 36),
            const SizedBox(height: 10),
            Text('Saved on this phone. Long-press a check to rename or delete it.',
                style: t.bodyLarge?.copyWith(color: GColors.inkSoft)),
            const SizedBox(height: 20),
            if (items.isNotEmpty)
              Row(children: [
                Text('${items.length} CHECK${items.length == 1 ? '' : 'S'}',
                    style: const TextStyle(
                        fontSize: 10.5, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: GColors.inkSoft)),
                const Spacer(),
                TextLink('Clear history', onTap: () => showClearHistorySheet(context)),
              ]),
          ]),
          const SizedBox(height: 10),
          if (items.isEmpty)
            const FadeInUp(
              index: 5,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Column(children: [
                  LoopyIcon('sleep', size: 84, stroke: 1.8),
                  SizedBox(height: 16),
                  Text('Nothing here yet',
                      style: TextStyle(fontFamily: AppTheme.display, fontSize: 21, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
                  SizedBox(height: 4),
                  Text('Scan, upload, paste or link something and it’ll show up here.',
                      textAlign: TextAlign.center, style: TextStyle(color: GColors.inkSoft)),
                ]),
              ),
            )
          else
            for (var i = 0; i < items.length; i++)
              FadeInUp(
                index: 5 + i,
                child: HistoryTile(
                  result: items[i],
                  onTap: () => Flows.open(context, items[i]),
                  onLongPress: () => _actions(context, state, items[i]),
                ),
              ),
        ],
      ),
    );
  }
}
