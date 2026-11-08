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

  _Rule._(this.id, this.category, this.severity, this.title, this.plain, this.ask, this.fact, this.patterns);

  _Rule withSeverity(Severity s) => _Rule._(id, category, s, title, plain, ask, fact, patterns);

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

    final type = input.dealType;
    final tweaks = _tweaks[type] ?? const <String, (String?, double)>{};
    final skip = _skip[type] ?? const <String>{};
    final weights = <Finding, double>{};
    final rules = [..._rules.where((r) => !skip.contains(r.id)), ...(_extra[type] ?? const <_Rule>[])];

    for (final base in rules) {
      final tw = tweaks[base.id];
      final rule = tw?.$1 == null ? base : base.withSeverity(SeverityX.parse(tw!.$1));
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
      final finding = Finding(
        title: rule.title,
        plain: hits > 2 ? '${rule.plain} (Mentioned $hits times.)' : rule.plain,
        quote: quote,
        severity: rule.severity,
        category: rule.category,
      );
      findings.add(finding);
      weights[finding] = tw?.$2 ?? 1.0;
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
    // Same criteria for everyone, but each flag is weighted by how much it
    // matters for this kind of deal (e.g. refunds matter more for a shop).
    var penalty = 0.0;
    for (final f in findings) {
      final w = weights[f] ?? 1.0;
      penalty += switch (f.severity) {
        Severity.redFlag => 11 * w,
        Severity.headsUp => 4 * w,
        Severity.goodNews => -5 * w,
      };
    }
    final score = (100 - penalty).round().clamp(5, 98).toInt();

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


// ---------------------------------------------------------------------------
// Category tuning. The criteria (rules) are shared; per deal type we change
// how much a flag weighs, sometimes how serious it is, drop flags that don't
// apply, and add a few flags only that kind of deal has.

typedef _Tweak = (String?, double); // (severity override, weight)

const Map<String, Map<String, _Tweak>> _tweaks = {
  'shopping': {
    'no_refunds': ('red_flag', 1.5), 'refund_ok': (null, 1.5), 'extra_fees': (null, 1.3),
    'price_change': (null, 1.2), 'auto_renewal': (null, 0.7), 'content_license': (null, 0.5), 'ai_training': (null, 0.5),
  },
  'subscription': {
    'auto_renewal': (null, 1.5), 'cancel_notice': ('red_flag', 1.3), 'cancel_anytime': (null, 1.5),
    'price_change': ('red_flag', 1.0), 'free_trial': (null, 1.3), 'no_refunds': ('red_flag', 1.0),
  },
  'rideshare': {
    'liability_cap': (null, 1.3), 'indemnify': (null, 1.2), 'arbitration': (null, 1.3), 'extra_fees': (null, 1.4),
    'tracking': (null, 1.3), 'data_sharing': (null, 1.2), 'auto_renewal': (null, 0.6),
  },
  'social': {
    'content_license': ('red_flag', 1.4), 'ai_training': ('red_flag', 1.4), 'data_sharing': (null, 1.3),
    'tracking': (null, 1.2), 'monitoring': (null, 1.3), 'termination_by_them': (null, 1.3), 'auto_renewal': (null, 0.5),
  },
  'lodging': {
    'no_refunds': ('red_flag', 1.4), 'extra_fees': (null, 1.4), 'deposit': (null, 1.2), 'termination_by_them': (null, 1.2),
  },
  'rental': {
    'deposit': (null, 1.4), 'personal_guarantee': ('red_flag', 1.3), 'termination_fee': ('red_flag', 1.4),
    'min_term': (null, 1.2), 'unilateral_changes': (null, 1.3), 'tracking': (null, 0.5), 'data_sharing': (null, 0.6),
  },
  'insurance': {
    'unilateral_changes': (null, 1.3), 'termination_by_them': ('red_flag', 1.4), 'arbitration': (null, 1.2), 'data_sharing': (null, 1.2),
  },
  'finance': {
    'extra_fees': ('red_flag', 1.5), 'price_change': ('red_flag', 1.3), 'arbitration': (null, 1.3),
    'data_sharing': (null, 1.3), 'termination_by_them': (null, 1.2),
  },
  'gym': {
    'cancel_notice': ('red_flag', 1.5), 'min_term': ('red_flag', 1.4), 'termination_fee': (null, 1.4),
    'auto_renewal': (null, 1.3), 'liability_cap': (null, 1.3), 'as_is': (null, 1.2),
  },
  'software': {
    'data_retention': (null, 1.3), 'ai_training': (null, 1.2), 'liability_cap': (null, 1.2), 'price_change': (null, 1.2),
  },
  'phone': {
    'termination_fee': ('red_flag', 1.5), 'min_term': (null, 1.3), 'price_change': ('red_flag', 1.3), 'extra_fees': (null, 1.3),
  },
};

/// Flags that don't make sense for a kind of deal.
const Map<String, Set<String>> _skip = {
  'shopping': {'min_term', 'personal_guarantee', 'non_compete', 'deposit'},
  'social': {'deposit', 'personal_guarantee', 'non_compete', 'min_term'},
  'rental': {'content_license', 'ai_training', 'free_trial'},
  'insurance': {'content_license', 'ai_training', 'free_trial'},
  'gym': {'content_license', 'ai_training'},
  'rideshare': {'deposit', 'min_term', 'personal_guarantee'},
};

_Rule _r(String id, String cat, String sev, String title, String plain, List<String> pats, {String? ask}) =>
    _Rule.fromJson({'id': id, 'category': cat, 'severity': sev, 'title': title, 'plain': plain, 'ask': ask, 'patterns': pats});

/// Flags only some kinds of deal have.
final Map<String, List<_Rule>> _extra = {
  'shopping': [
    _r('shop_short_return', 'Money', 'heads_up', 'Short window to return',
        'You only get a couple of weeks to send things back. Check the date before you open the box.',
        [r'within (7|10|14|15) days? (of|after|from) (delivery|receipt|purchase)'],
        ask: 'Exactly how many days do I have to return something?'),
    _r('shop_return_shipping', 'Money', 'heads_up', 'You pay to send it back',
        'Return shipping comes out of your pocket, which can eat into any refund.',
        [r'return shipping (costs?|fees?|charges?)', r'(customer|you) (is|are) responsible for (the )?(cost of )?return shipping']),
    _r('shop_final_sale', 'Money', 'heads_up', 'Some items can’t be returned',
        'Sale, clearance or personal items may be final sale. No take-backs.',
        [r'final sale', r'non-?returnable', r'cannot be returned']),
    _r('shop_restocking', 'Money', 'red_flag', 'Restocking fee',
        'They keep a cut of your refund just for taking the item back.',
        [r'restocking fee']),
  ],
  'rideshare': [
    _r('ride_surge', 'Money', 'heads_up', 'Prices jump when it’s busy',
        'Fares can go up a lot at busy times. Check the price before you confirm.',
        [r'surge', r'dynamic pric', r'demand[- ]based pric']),
    _r('ride_cancel_fee', 'Money', 'heads_up', 'Fees for cancelling a trip',
        'Cancel too late or don’t show up and you get charged.',
        [r'cancell?ation fee', r'no-?show fee']),
    _r('ride_not_employer', 'Your rights', 'heads_up', 'Drivers aren’t their staff',
        'They say drivers are independent. If something goes wrong, the company may say it isn’t responsible.',
        [r'independent (contractor|third[- ]party)', r'not a (transportation|delivery) (provider|carrier|company)']),
    _r('ride_damage_fee', 'Money', 'heads_up', 'Cleaning and damage fees',
        'Make a mess or damage the car and they can charge your card.',
        [r'cleaning fee', r'damage fee', r'damage to (a|the) vehicle']),
  ],
  'rental': [
    _r('rent_entry', 'Your rights', 'heads_up', 'The landlord can come in',
        'They can enter your place, sometimes with little notice.',
        [r'enter the (premises|unit|property)', r'right of entry']),
    _r('rent_late_fee', 'Money', 'heads_up', 'Late rent costs extra',
        'Pay late and there’s a fee on top.',
        [r'late (fee|charge|payment fee)']),
  ],
  'gym': [
    _r('gym_cancel_hard', 'Commitment', 'red_flag', 'Cancelling is a hassle',
        'You may have to cancel in person, in writing or by mail. Not just a button.',
        [r'cancel.{0,40}(in person|by (certified |registered )?mail|in writing)']),
  ],
  'insurance': [
    _r('ins_exclusions', 'Money', 'heads_up', 'Things they won’t cover',
        'There’s a list of situations they won’t pay for. Read it before you need to claim.',
        [r'not covered', r'exclusions?\b']),
  ],
  'finance': [
    _r('fin_overdraft', 'Money', 'red_flag', 'Overdraft fees',
        'Go below zero and they charge you, sometimes again and again.',
        [r'overdraft fee']),
    _r('fin_variable_rate', 'Money', 'heads_up', 'Your rate can change',
        'The interest rate isn’t fixed, so what you pay can go up.',
        [r'variable (rate|apr|interest)']),
  ],
  'phone': [
    _r('phone_throttle', 'Commitment', 'heads_up', 'They can slow your data',
        'After a certain amount of data, speeds can drop a lot.',
        [r'throttl', r'reduced speeds?', r'deprioriti']),
  ],
};
