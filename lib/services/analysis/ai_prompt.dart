import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../models/analysis.dart';
import 'analyzer.dart';
import 'context_profile.dart';

/// Thrown by an AI reader with a short, human reason ("over its free limit").
class AiFailure implements Exception {
  AiFailure(this.reason);
  final String reason;
  @override
  String toString() => reason;
}

/// What every AI reader shares: the brief, a shortened document, and turning
/// the model's JSON back into a result.
class AiPrompt {
  /// Characters sent to the model. Long terms are cut down to the parts that
  /// matter (money, cancelling, data, disputes…) so answers come back fast.
  static const budget = 36000;

  static String reasonFor(Object e) {
    if (e is AiFailure) return e.reason;
    if (e is TimeoutException) return 'it took too long';
    if (e is SocketException || e is HandshakeException) return 'no internet connection';
    return 'something went wrong';
  }

  static String reasonForStatus(int code, String body) {
    if (code == 429) return 'it’s over its free limit right now';
    if (code == 401 || code == 403) return 'its key was refused';
    if (code == 402) return 'the free version isn’t available right now';
    if (code == 404) return 'that model isn’t available';
    if (code >= 500) return 'its servers are busy';
    final m = RegExp(r'"message"\s*:\s*"([^"]{0,90})').firstMatch(body);
    return m != null ? 'it said “${m.group(1)}”' : 'it returned an error ($code)';
  }

  static String system(ContractInput input) {
    final type = ContextProfiler.describeType(input.dealType);
    final ind = ContextProfiler.industryLabel(input.industry);
    final indNote = ContextProfiler.industryNote(input.industry);
    return '''
You are Yes,But, a friend who reads terms and conditions for regular people.
This document looks like the terms for $type${ind.isEmpty ? '' : ' in $ind'}.
Judge it the way a regular customer of that kind of service would, not as a generic contract.
${ContextProfiler.weightingNote(input.dealType)} $indNote
Pull out the clauses that matter most for THIS kind of service and industry (for example: for beauty, reactions/patch tests, returns of opened products, auto-ship; for games, virtual currency and bans; for food delivery, allergens, missing orders and fees). Generic boilerplate (liability caps, arbitration) still counts, but do not let it crowd out what is specific to this service.
$_schema''';
  }

  static const _schema = '''
Respond with ONLY a JSON object, no markdown, using exactly this shape:
{
  "title": "short name, e.g. 'Netflix Terms of Use'",
  "summary": "one plain sentence a 12-year-old understands: whose rules these are and for what",
  "audience": "who these terms apply to in plain words, e.g. 'people booking rides (drivers have separate terms)'",
  "score": 0-100 integer, how fair to the customer (100 = very fair), using the guide above,
  "tldr": ["first item: one-line overall summary", "then 2-4 short bullets of what matters most"],
  "key_facts": [{"label": "Cancel|Renewal|Price|Refunds|Returns|Disputes|Data|...", "value": "short answer"}],
  "findings": [
    {"title": "short punchy headline, max 7 words",
     "plain": "1-2 sentences, everyday words, what it means for ME",
     "quote": "short EXACT excerpt copied from the document",
     "severity": "red_flag | heads_up | good_news",
     "category": "Money | Your rights | Your data | Commitment | General"}
  ],
  "jargon": [{"term": "legal word used in the doc", "meaning": "plain meaning"}],
  "questions": ["things to ask or check before agreeing"]
}
Order findings red_flag first. 5-12 findings. Never invent clauses that are not in the text. Write in English. Be quick and direct.''';

  static String user(ContractInput input) =>
      'Title (may be a guess): ${input.title}\n\n<document>\n${shorten(input.text)}\n</document>';

  static final _important = RegExp(
    r'fee|charge|price|pay|bill|subscri|renew|cancel|terminat|refund|return|trial|auto|'
    r'arbitrat|class action|waive|jury|liab|indemn|warrant|dispute|govern|court|'
    r'data|personal|privacy|share|sell|third part|track|cookie|location|biometric|'
    r'license|content|own|intellectual|suspend|ban|account|change|modif|notice|'
    r'penalt|interest|late|deposit|minimum|lock|exclusiv|non-compete|confidential',
    caseSensitive: false,
  );

  /// Keep the start (who/what), then the paragraphs that hit the most
  /// important words, in their original order, up to [budget] characters.
  static String shorten(String text) {
    if (text.length <= budget) return text;
    final paras = text.split(RegExp(r'\n\s*\n|\n(?=\s*\d+[\.\)]\s)')).where((p) => p.trim().isNotEmpty).toList();
    const head = 5000;
    final keep = <int>{};
    var used = 0;
    for (var i = 0; i < paras.length && used < head; i++) {
      keep.add(i);
      used += paras[i].length;
    }
    final ranked = [
      for (var i = 0; i < paras.length; i++)
        if (!keep.contains(i)) (i, _important.allMatches(paras[i]).length / (1 + paras[i].length / 400)),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    for (final (i, score) in ranked) {
      if (score <= 0) break;
      final len = paras[i].length > 3000 ? 3000 : paras[i].length;
      if (used + len > budget) continue;
      keep.add(i);
      used += len;
    }
    final out = (keep.toList()..sort()).map((i) {
      final p = paras[i];
      return p.length > 3000 ? '${p.substring(0, 3000)}…' : p;
    });
    return out.join('\n\n');
  }

  static AnalysisResult parse(String raw, ContractInput input, String engine) {
    final s = raw.indexOf('{'), e = raw.lastIndexOf('}');
    if (s == -1 || e <= s) throw AiFailure('its answer was unreadable');
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(raw.substring(s, e + 1)) as Map<String, dynamic>;
    } catch (_) {
      throw AiFailure('its answer was unreadable');
    }

    List<String> strings(String k) => ((json[k] as List?) ?? const []).map((x) => x.toString()).toList();
    List<T> list<T>(String k, T Function(Map<String, dynamic>) f) =>
        ((json[k] as List?) ?? const []).whereType<Map>().map((m) => f(Map<String, dynamic>.from(m))).toList();

    final findings = list('findings', Finding.fromJson)..sort((a, b) => a.severity.index.compareTo(b.severity.index));
    if (findings.isEmpty) throw AiFailure('it found nothing to report');
    final aiTitle = json['title']?.toString().trim();
    return AnalysisResult(
      id: newId(),
      title: (input.kind == SourceKind.library || input.kind == SourceKind.link || aiTitle == null || aiTitle.isEmpty)
          ? input.title
          : aiTitle,
      sourceKind: input.kind,
      sourceRef: input.ref,
      analyzedAt: DateTime.now(),
      engine: engine,
      score: (json['score'] is num) ? (json['score'] as num).round().clamp(0, 100).toInt() : 50,
      tldr: strings('tldr'),
      findings: findings,
      jargon: list('jargon', JargonTerm.fromJson),
      keyFacts: list('key_facts', KeyFact.fromJson),
      questions: strings('questions'),
      wordCount: countWords(input.text),
      text: trimForStorage(input.text),
      summary: json['summary']?.toString(),
      audience: json['audience']?.toString(),
    );
  }
}
