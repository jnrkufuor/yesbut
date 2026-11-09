import 'package:flutter/material.dart' hide Text;
import '../i18n/text.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/watch_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'common.dart';

Widget _sheetTitle(String lead, String serif) {
  const base = TextStyle(
    fontFamily: AppTheme.display,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.8,
    height: 1.1,
    color: GColors.ink,
  );
  return Text.rich(TextSpan(children: [
    TextSpan(text: lead),
    TextSpan(text: serif, style: AppTheme.serifOf(base)),
  ]), style: base);
}

Future<T?> _sheet<T>(BuildContext context, Widget Function(BuildContext) builder) =>
    showModalBottomSheet<T>(
      context: context,
      backgroundColor: GColors.white,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: builder(ctx),
        ),
      ),
    );

/// "Leave this page?" — shown on back / back-swipe.
Future<bool> confirmLeave(BuildContext context, {String? message, bool exitApp = false}) async {
  final ok = await _sheet<bool>(
    context,
    (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sheetTitle(exitApp ? 'Leave ' : 'Leave this ', exitApp ? 'Yes,But?' : 'page?'),
      const SizedBox(height: 8),
      Text(
        message ?? (exitApp ? 'Your checks stay saved on this phone.' : 'You can always come back to it.'),
        style: const TextStyle(fontSize: 15, height: 1.45, color: GColors.inkSoft),
      ),
      const SizedBox(height: 22),
      BigButton(label: 'Stay', color: GColors.ink, onTap: () => Navigator.pop(ctx, false)),
      const SizedBox(height: 8),
      // Quiet on purpose: outlined in red, so Stay is the obvious choice.
      Pressable(
        onTap: () => Navigator.pop(ctx, true),
        child: Container(
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: GColors.red, width: 1),
          ),
          child: const Text('Leave', style: TextStyle(color: GColors.red, fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ),
    ]),
  );
  return ok ?? false;
}

/// Wraps a page so system back / back-swipe asks before leaving.
class LeaveGuard extends StatelessWidget {
  const LeaveGuard({super.key, required this.child, this.message, this.exitApp = false});
  final Widget child;
  final String? message;
  final bool exitApp;

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          final nav = Navigator.of(context);
          if (await confirmLeave(context, message: message, exitApp: exitApp)) {
            if (exitApp) {
              SystemNavigator.pop();
            } else if (nav.canPop()) {
              nav.pop();
            }
          }
        },
        child: child,
      );
}

/// Per-item watch settings: how often to check it, or stop watching.
Future<void> showWatchSettings(BuildContext context, WatchItem item) async {
  final state = context.read<AppState>();
  final general = WatchService.frequencies[state.watchEvery] ?? 'Every 3 months';
  int? pick = item.everyDays;
  final stop = await _sheet<bool>(
    context,
    (ctx) => StatefulBuilder(builder: (ctx, set) {
      final options = <int?, String>{null: 'Same as the rest ($general)', ...WatchService.frequencies};
      return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sheetTitle('', 'Watching'),
        const SizedBox(height: 2),
        Text(item.title,
            style: const TextStyle(fontFamily: AppTheme.display, fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: -0.4)),
        const SizedBox(height: 18),
        Row(children: [
          const Expanded(
            child: Text('Check for changes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
          PopupMenuButton<int?>(
            color: GColors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: GColors.line)),
            onSelected: (d) {
              set(() => pick = d);
              state.setItemEvery(item.url, d);
            },
            itemBuilder: (_) => [
              for (final e in options.entries)
                PopupMenuItem<int?>(
                  value: e.key,
                  child: Row(children: [
                    Expanded(child: Text(e.value, style: const TextStyle(fontSize: 14))),
                    if (e.key == pick) const Icon(Icons.check_rounded, size: 18),
                  ]),
                ),
            ],
            child: Container(
              height: 36,
              padding: const EdgeInsets.fromLTRB(13, 0, 8, 0),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(99), border: Border.all(color: GColors.ink, width: 1)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(pick == null ? 'Default' : options[pick]!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const Icon(Icons.expand_more_rounded, size: 18),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        Text(
          pick == null ? 'Uses your general setting on the Live page ($general).' : 'Its own schedule, separate from the rest.',
          style: const TextStyle(fontSize: 12.5, height: 1.4, color: GColors.inkSoft),
        ),
        const SizedBox(height: 22),
        BigButton(label: 'Done', color: GColors.ink, onTap: () => Navigator.pop(ctx, false)),
        const SizedBox(height: 8),
        Pressable(
          onTap: () => Navigator.pop(ctx, true),
          child: Container(
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(99), border: Border.all(color: GColors.red, width: 1)),
            child: const Text('Stop watching', style: TextStyle(color: GColors.red, fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ]);
    }),
  );
  if (stop == true) {
    await state.unwatch(item.url);
    if (context.mounted) showToast(context, 'Stopped watching.');
  }
}

/// Reading again with the same reader rarely changes much: check first.
Future<bool> confirmReread(BuildContext context, String reader) async {
  final ok = await _sheet<bool>(
    context,
    (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sheetTitle('Read it ', 'again?'),
      const SizedBox(height: 8),
      Text(
        reader == 'On your phone'
            ? 'Your phone already read this one, so the result will probably be the same.'
            : '$reader already read this one, so the result will probably be the same. '
                'To get a second opinion, pick a different reader first.',
        style: const TextStyle(fontSize: 15, height: 1.45, color: GColors.inkSoft),
      ),
      const SizedBox(height: 22),
      BigButton(label: 'Keep this result', color: GColors.ink, onTap: () => Navigator.pop(ctx, false)),
      const SizedBox(height: 8),
      Pressable(
        onTap: () => Navigator.pop(ctx, true),
        child: Container(
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(99), border: Border.all(color: GColors.ink, width: 1)),
          child: const Text('Read it again anyway', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ),
    ]),
  );
  return ok ?? false;
}

/// Confirm deleting a single check.
Future<bool> confirmDeleteOne(BuildContext context, String title) async {
  final ok = await _sheet<bool>(
    context,
    (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sheetTitle('Delete this ', 'check?'),
      const SizedBox(height: 8),
      Text('“$title” will be removed from this phone. This can’t be undone.',
          style: const TextStyle(fontSize: 15, height: 1.45, color: GColors.inkSoft)),
      const SizedBox(height: 22),
      BigButton(label: 'Delete', color: GColors.red, onTap: () => Navigator.pop(ctx, true)),
      const SizedBox(height: 8),
      BigButton(label: 'Keep it', color: GColors.ink, onTap: () => Navigator.pop(ctx, false)),
    ]),
  );
  return ok ?? false;
}

/// Clear history for a time range, with a tick-to-confirm.
Future<void> showClearHistorySheet(BuildContext context) async {
  final state = context.read<AppState>();
  final ranges = <(String, Duration?)>[
    ('Last hour', const Duration(hours: 1)),
    ('Last 6 hours', const Duration(hours: 6)),
    ('Last 24 hours', const Duration(hours: 24)),
    ('Last 7 days', const Duration(days: 7)),
    ('Everything', null),
  ];
  var pick = 2;
  var ticked = false;
  final ok = await _sheet<bool>(
    context,
    (ctx) => StatefulBuilder(builder: (ctx, set) {
      final n = state.countWithin(ranges[pick].$2);
      return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sheetTitle('Clear your ', 'history'),
        const SizedBox(height: 8),
        const Text('Pick how far back to delete.',
            style: TextStyle(fontSize: 15, height: 1.45, color: GColors.inkSoft)),
        const SizedBox(height: 16),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (var i = 0; i < ranges.length; i++)
            Pressable(
              onTap: () => set(() => pick = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: pick == i ? GColors.ink : GColors.white,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: GColors.ink, width: 1),
                ),
                child: Text(ranges[i].$1,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: pick == i ? FontWeight.w600 : FontWeight.w400,
                      color: pick == i ? GColors.white : GColors.ink,
                    )),
              ),
            ),
        ]),
        const SizedBox(height: 18),
        Pressable(
          scale: 0.99,
          onTap: () => set(() => ticked = !ticked),
          child: Row(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: ticked ? GColors.ink : GColors.white,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: GColors.ink, width: 1),
              ),
              child: ticked ? const Icon(Icons.check_rounded, size: 17, color: GColors.white) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                n == 0
                    ? 'There’s nothing saved in this time.'
                    : n == 1
                        ? 'I understand this removes one saved check for good.'
                        : 'I understand this removes $n saved checks for good.',
                style: const TextStyle(fontSize: 14, height: 1.35),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 20),
        BigButton(
          label: n == 0 ? 'Nothing to delete' : 'Delete',
          color: GColors.red,
          onTap: ticked && n > 0 ? () => Navigator.pop(ctx, true) : null,
        ),
        const SizedBox(height: 8),
        BigButton(label: 'Cancel', color: GColors.ink, onTap: () => Navigator.pop(ctx, false)),
      ]);
    }),
  );
  // Read the final pick after the sheet closes.
  if (ok == true) {
    await state.clearHistory(within: ranges[pick].$2);
    if (context.mounted) showToast(context, 'History cleared.');
  }
}
