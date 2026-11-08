import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/analysis.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/tiles.dart';
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
    if (v == 'delete') await state.delete(r.id);
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
          Text('History', style: t.headlineLarge),
          const SizedBox(height: 6),
          Text('Everything you\'ve checked, saved on this phone. Long-press to rename or delete.',
              style: t.bodyLarge?.copyWith(color: GColors.inkSoft)),
          const SizedBox(height: 20),
          if (items.isEmpty)
            const SoftCard(
              child: Column(children: [
                SizedBox(height: 10),
                HopDots(size: 14),
                SizedBox(height: 22),
                Text('No checks yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                SizedBox(height: 4),
                Text('Scan, upload, paste or link something to get started.',
                    textAlign: TextAlign.center, style: TextStyle(color: GColors.inkSoft)),
                SizedBox(height: 10),
              ]),
            )
          else
            for (final r in items)
              HistoryTile(
                result: r,
                onTap: () => Flows.open(context, r),
                onLongPress: () => _actions(context, state, r),
              ),
        ],
      ),
    );
  }
}
