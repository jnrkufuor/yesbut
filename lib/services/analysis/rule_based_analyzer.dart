import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../models/analysis.dart';
import 'analyzer.dart';

class _Rule {
  final String id;
  final String category;
  final Severity severity;
  final String title;
  final String plain;
  final String? ask;
  final List<String>? fact;
  final List<RegExp> patterns;

  _Rule.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        category = j['category'] as String,
        severity = SeverityX.parse(j['severity'] as String?),
        title = j['title'] as String,
        plain = j['plain'] as String,
        ask = j['ask'] as String?,
        fact = (j['fact'] as List?)?.map((e) => e.toString()).toList(),
        patterns = (j['patterns'] as List)
            .map((p) => RegExp(p as String, caseSensitive: false))
            .toList();
}

class _Jargon {
  final String term;
  final String meaning;
  final RegExp match;
  _Jargon.fromJson(Map<String, dynamic> j)
      : term = j['term'] as String,
        meaning = j['meaning'] as String,
        match = RegExp(j['match'] as String, caseSensitive: false);
}

/// Fast, private, offline analyzer driven by `assets/rules.json`.
///
/// It never sends text anywhere. It spots known clause patterns, pulls the
/// sentence that triggered each one, and explains it in plain English.
class RuleBasedAnalyzer implements ContractAnalyzer {
  RuleBasedAnalyzer._(this._rules, this._jargon);

  final List<_Rule> _rules;
  final List<_Jargon> _jargon;

  static RuleBasedAnalyzer? _cached;

  static Future<RuleBasedAnalyzer> load() async {
    if (_cached != null) return _cached!;
    final raw = await rootBundle.loadString('assets/rules.json');
    _cached = RuleBasedAnalyzer.fromJsonString(raw);
    return _cached!;
  }

  factory RuleBasedAnalyzer.fromJsonString(String raw) {
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final rules = (data['rules'] as List)
        .map((r) => _Rule.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
    final jargon = (data['jargon'] as List)
        .map((r) => _Jargon.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
    return RuleBasedAnalyzer._(rules, jargon);
  }

  @override
  String get engineName => 'Offline';

  static final _sentenceSplit = RegExp(r'(?<=[.!?;:])\s+(?=[A-Z0-9("“])|\n+');

  @override
  Future<AnalysisResult> analyze(ContractInput input) async {
    final text = input.text.replaceAll('\r', '');
    final sentences = text
        .split(_sentenceSplit)
        .map((s) => s.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((s) => s.length > 3)
        .toList();

    final findings = <Finding>[];
    final hitIds = <String>{};
    final facts = <String, String>{};
    final questions = <String>[];

    for (final rule in _rules) {
      String? quote;
      var hits = 0;
      for (final s in sentences) {
        if (rule.patterns.any((p) => p.hasMatch(s))) {
          hits++;
          quote ??= _excerpt(s, rule.patterns);
        }
      }
      if (hits == 0) continue;
      hitIds.add(rule.id);
      findings.add(Finding(
        title: rule.title,
        plain: hits > 2 ? '${rule.plain} (Mentioned $hits times.)' : rule.plain,
        quote: quote,
        severity: rule.severity,
        category: rule.category,
      ));
      if (rule.fact != null && rule.fact!.length == 2) {
        final label = rule.fact![0];
        // Red flags win over good news for the same fact (e.g. Cancel).
        if (!facts.containsKey(label) || rule.severity == Severity.redFlag) {
          facts[label] = rule.fact![1];
        }
      }
      if (rule.ask != null && rule.severity != Severity.goodNews) {
        questions.add(rule.ask!);
      }
    }

    // Cancel-anytime contradicts a notice requirement; keep the honest one.
    if (hitIds.contains('cancel_anytime') && hitIds.contains('cancel_notice')) {
      facts['Cancel'] = 'Anytime, but check the notice period';
    }
    if (hitIds.contains('arbitration') && hitIds.contains('arb_opt_out')) {
      facts['Disputes'] = 'Arbitration (you can opt out)';
    }

    findings.sort((a, b) => a.severity.index.compareTo(b.severity.index));

    final jargon = <JargonTerm>[
      for (final j in _jargon)
        if (j.match.hasMatch(text)) JargonTerm(j.term, j.meaning),
    ];

    final words = countWords(text);
    final red = findings.where((f) => f.severity == Severity.redFlag).length;
    final heads = findings.where((f) => f.severity == Severity.headsUp).length;
    final good = findings.where((f) => f.severity == Severity.goodNews).length;
    final score = (100 - red * 11 - heads * 4 + good * 5).clamp(5, 98).toInt();

    final tldr = <String>[];
    final minutes = (words / 238).ceil();
    if (findings.isEmpty) {
      tldr.add(words < 60
          ? 'That was short — paste or scan the full terms for a real check.'
          : 'No common gotchas detected. Still skim for anything specific to you.');
    } else {
      tldr.add('Found $red red flag${red == 1 ? '' : 's'}, '
          '$heads heads-up${heads == 1 ? '' : 's'} and '
          '$good good thing${good == 1 ? '' : 's'} '
          'in about $minutes min of reading.');
      for (final f
          in findings.where((f) => f.severity == Severity.redFlag).take(3)) {
        tldr.add('${f.title}. ${_firstSentence(f.plain)}');
      }
      final g = findings.where((f) => f.severity == Severity.goodNews);
      if (g.isNotEmpty) tldr.add('On the plus side: ${g.first.title.toLowerCase()}.');
    }

    return AnalysisResult(
      id: newId(),
      title: input.title,
      sourceKind: input.kind,
      sourceRef: input.ref,
      analyzedAt: DateTime.now(),
      engine: engineName,
      score: score,
      tldr: tldr,
      findings: findings,
      jargon: jargon,
      keyFacts: facts.entries.map((e) => KeyFact(e.key, e.value)).toList(),
      questions: questions.take(6).toList(),
      wordCount: words,
      text: trimForStorage(text),
    );
  }

  static String _firstSentence(String s) {
    final i = s.indexOf(RegExp(r'[.!?](\s|$)'));
    return i == -1 ? s : s.substring(0, i + 1);
  }

  /// Return a readable window of the sentence around the first match.
  static String _excerpt(String s, List<RegExp> patterns) {
    const max = 280;
    if (s.length <= max) return s;
    var at = 0;
    for (final p in patterns) {
      final m = p.firstMatch(s);
      if (m != null) {
        at = m.start;
        break;
      }
    }
    int start = (at - 100).clamp(0, s.length).toInt();
    final int end = (start + max).clamp(0, s.length).toInt();
    if (end - start < max) start = (end - max).clamp(0, s.length).toInt();
    final head = start > 0 ? '…' : '';
    final tail = end < s.length ? '…' : '';
    return '$head${s.substring(start, end).trim()}$tail';
  }
}
