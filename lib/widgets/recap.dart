import 'package:flutter/material.dart' hide Text;
import '../i18n/text.dart';

import '../models/analysis.dart';
import '../services/analysis/context_profile.dart';
import '../theme/app_theme.dart';
import 'loopy.dart';

/// "Your recap" on History: what kinds of terms you look at, the red flags
/// that keep coming up for you, and where to be most careful next time.
class RecapCard extends StatelessWidget {
  const RecapCard({super.key, required this.history});
  final List<AnalysisResult> history;

  /// Red-flag themes we can recognise from any reader's wording.
  static final _themes = <(String, RegExp)>[
    ('Auto-renewal', RegExp(r'renew|recurring|auto-?ship|keeps charging', caseSensitive: false)),
    ('Hard to cancel', RegExp(r'cancel|notice|lock-?in|minimum term|early termination', caseSensitive: false)),
    ('No refunds', RegExp(r'refund|money back|non-?refundable|return', caseSensitive: false)),
    ('Price changes', RegExp(r'price|fee|charge|cost|interest', caseSensitive: false)),
    ('No day in court', RegExp(r'arbitrat|class action|jury|waive|court|dispute', caseSensitive: false)),
    ('Your data', RegExp(r'data|privacy|track|share|sell|location|biometric|cookie', caseSensitive: false)),
    ('Your content', RegExp(r'content|licen[cs]e|photos|posts|ai training|ownership', caseSensitive: false)),
    ('Account bans', RegExp(r'suspend|terminat|ban|close your account|disable', caseSensitive: false)),
    ('Their liability', RegExp(r'liab|indemn|as is|warrant|responsib', caseSensitive: false)),
    ('Changing terms', RegExp(r'change (these|the) terms|modif|update.*terms|without notice', caseSensitive: false)),
  ];

  static String themeOf(Finding f) {
    final text = '${f.title} ${f.plain}';
    for (final (name, re) in _themes) {
      if (re.hasMatch(text)) return name;
    }
    return f.category.isEmpty ? 'Other' : f.category;
  }

  static String kindOf(AnalysisResult r) {
    final ind = ContextProfiler.industryLabel(r.industry);
    if (ind.isNotEmpty) return ind[0].toUpperCase() + ind.substring(1);
    final t = ContextProfiler.describeType(r.dealType);
    if (r.dealType == 'general' || t == 'an agreement') return 'Other';
    final clean = t.replaceFirst(RegExp(r'^(an?|the) '), '');
    return clean[0].toUpperCase() + clean.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final h = history;
    final avg = (h.map((r) => r.score).reduce((a, b) => a + b) / h.length).round();
    final reds = h.expand((r) => r.findings.where((f) => f.severity == Severity.redFlag).map((f) => (r, f))).toList();

    // What you look at.
    final kinds = <String, int>{};
    for (final r in h) {
      kinds.update(kindOf(r), (n) => n + 1, ifAbsent: () => 1);
    }
    final topKinds = (kinds.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(4).toList();

    // Red flags that keep coming up, and where.
    final themes = <String, Set<String>>{};
    for (final (r, f) in reds) {
      themes.putIfAbsent(themeOf(f), () => {}).add(r.title.split(' · ').first);
    }
    final topThemes = (themes.entries.toList()..sort((a, b) => b.value.length.compareTo(a.value.length))).take(3).toList();
    final toughest = [...h]..sort((a, b) => a.score.compareTo(b.score));

    const label = TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: GColors.inkSoft);
    final avgColor = GColors.forScore(avg);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(30), border: Border.all(color: GColors.line, width: 1)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const BrandAsterisk(size: 14),
          const SizedBox(width: 8),
          Text.rich(
            TextSpan(children: [
              const TextSpan(text: 'Your '),
              TextSpan(text: 'recap', style: AppTheme.serifOf(const TextStyle(fontSize: 21))),
            ]),
            style: const TextStyle(fontFamily: AppTheme.display, fontSize: 21, fontWeight: FontWeight.w700, letterSpacing: -0.5),
          ),
        ]),
        const SizedBox(height: 14),
        // Three numbers at a glance.
        Row(children: [
          _Stat(value: '${h.length}', label: h.length == 1 ? 'check' : 'checks'),
          _Stat(value: '$avg', label: 'average score', dot: avgColor),
          _Stat(value: '${reds.length}', label: reds.length == 1 ? 'red flag' : 'red flags', dot: GColors.red),
        ]),
        const SizedBox(height: 16),
        const Text('YOU MOSTLY LOOK AT', style: label),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final k in topKinds)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(99), border: Border.all(color: GColors.line, width: 1)),
              child: Text('${k.key} · ${k.value}', style: const TextStyle(fontSize: 13)),
            ),
        ]),
        if (topThemes.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('BE MOST CAREFUL WITH', style: label),
          const SizedBox(height: 8),
          for (final t in topThemes)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 9,
                  height: 9,
                  margin: const EdgeInsets.only(top: 6, right: 10),
                  decoration: const BoxDecoration(color: GColors.red, shape: BoxShape.circle),
                ),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t.key, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    Text(
                      'Came up in ${t.value.length} of your checks: ${t.value.take(3).join(', ')}${t.value.length > 3 ? '…' : ''}',
                      style: const TextStyle(fontSize: 13, height: 1.4, color: GColors.inkSoft),
                    ),
                  ]),
                ),
              ]),
            ),
          Text(
            'Look for ${_list(topThemes.map((t) => t.key.toLowerCase()).toList())} first the next time you sign up for something.',
            style: const TextStyle(fontSize: 13.5, height: 1.45),
          ),
        ],
        if (h.length > 1) ...[
          const SizedBox(height: 12),
          Text('Toughest so far: ${toughest.first.title} (${toughest.first.score}).',
              style: const TextStyle(fontSize: 12.5, color: GColors.inkSoft)),
        ],
      ]),
    );
  }

  static String _list(List<String> xs) => xs.length <= 1
      ? xs.join()
      : '${xs.sublist(0, xs.length - 1).join(', ')} and ${xs.last}';
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.dot});
  final String value;
  final String label;
  final Color? dot;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (dot != null) ...[
              Container(width: 9, height: 9, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
              const SizedBox(width: 6),
            ],
            Text(value,
                translate: false,
                style: const TextStyle(fontFamily: AppTheme.display, fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -1, height: 1)),
          ]),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12, color: GColors.inkSoft)),
        ]),
      );
}
