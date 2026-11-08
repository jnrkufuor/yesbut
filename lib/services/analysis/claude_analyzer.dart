import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/analysis.dart';
import 'analyzer.dart';

/// Uses Anthropic's Messages API to read the contract like a sharp friend
/// with a law degree would.
///
/// For a production release, point [endpoint] at your own backend that holds
/// the API key (so it never ships inside the app) and forwards the request.
class ClaudeAnalyzer implements ContractAnalyzer {
  ClaudeAnalyzer({
    required this.apiKey,
    this.model = 'claude-sonnet-5-5',
    this.endpoint = 'https://api.anthropic.com/v1/messages',
    this.outputLanguage = 'English',
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Language every piece of text in the answer should be written in.
  final String outputLanguage;

  final String apiKey;
  final String model;
  final String endpoint;
  final http.Client _client;

  static const _maxChars = 180000;

  @override
  String get engineName => 'AI · $model';

  static const _system = '''
You are YesBut, an assistant that explains contracts and terms & conditions to regular people.
Read the document and respond with ONLY a JSON object (no markdown fences, no commentary) using this exact shape:
{
  "title": "short name for the document, e.g. 'Netflix Terms of Use'",
  "summary": "one sentence: what this document is and what service it covers",
  "audience": "who these terms apply to, e.g. 'riders booking trips (not drivers)'",
  "score": 0-100 integer, how fair this is to the person signing (100 = very fair),
  "tldr": ["3-5 short plain-English bullets of what matters most"],
  "key_facts": [{"label": "Cancel|Renewal|Price|Refunds|Disputes|Commitment|Data|...", "value": "short answer"}],
  "findings": [
    {"title": "short punchy headline, max 7 words",
     "plain": "1-2 sentences, 8th-grade reading level, what it means for ME",
     "quote": "short exact excerpt from the document that supports this",
     "severity": "red_flag | heads_up | good_news",
     "category": "Money | Your rights | Your data | Commitment | General"}
  ],
  "jargon": [{"term": "legal term used in the doc", "meaning": "plain meaning"}],
  "questions": ["questions the person should ask before signing"]
}
Focus on gotchas: auto-renewal, cancellation hurdles, fees, price changes, refunds, arbitration/class-action waivers, liability caps, indemnity, data sharing/selling, content licenses, AI training, unilateral changes, account termination, lock-in terms, penalties, deposits, personal guarantees, non-competes.
Also include genuinely good-for-the-user clauses as good_news.
Order findings red_flag first. Be specific to THIS document; never invent clauses that are not there.
Write for a busy person. No legalese. This is not legal advice.
The document may be in any language: read it in its own language, but quote excerpts in the original language.''';

  @override
  Future<AnalysisResult> analyze(ContractInput input) async {
    var text = input.text;
    if (text.length > _maxChars) text = text.substring(0, _maxChars);

    final res = await _client
        .post(
          Uri.parse(endpoint),
          headers: {
            'content-type': 'application/json',
            'x-api-key': apiKey,
            'anthropic-version': '2023-06-01',
          },
          body: jsonEncode({
            'model': model,
            'max_tokens': 4096,
            'system': '$_system\nWrite every title, explanation, bullet, fact and question in $outputLanguage.',
            'messages': [
              {
                'role': 'user',
                'content':
                    'Document title (may be a guess): ${input.title}\n\n<document>\n$text\n</document>',
              }
            ],
          }),
        )
        .timeout(const Duration(seconds: 120));

    if (res.statusCode != 200) {
      String msg = 'AI request failed (${res.statusCode}).';
      try {
        final e = jsonDecode(utf8.decode(res.bodyBytes));
        final m = (e is Map && e['error'] is Map) ? e['error']['message'] : null;
        if (m != null) msg = 'AI: $m';
      } catch (_) {}
      throw AnalysisException(msg);
    }

    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final content = (body['content'] as List?) ?? const [];
    final raw = content
        .whereType<Map>()
        .where((c) => c['type'] == 'text')
        .map((c) => c['text'].toString())
        .join();

    final json = _extractJson(raw);
    if (json == null) throw AnalysisException('AI returned an unreadable answer.');

    final findings = ((json['findings'] as List?) ?? const [])
        .whereType<Map>()
        .map((f) => Finding.fromJson(Map<String, dynamic>.from(f)))
        .toList()
      ..sort((a, b) => a.severity.index.compareTo(b.severity.index));

    List<String> strings(String k) =>
        ((json[k] as List?) ?? const []).map((e) => e.toString()).toList();

    final aiTitle = json['title']?.toString().trim();
    return AnalysisResult(
      id: newId(),
      title: (input.kind == SourceKind.library || aiTitle == null || aiTitle.isEmpty)
          ? input.title
          : aiTitle,
      sourceKind: input.kind,
      sourceRef: input.ref,
      analyzedAt: DateTime.now(),
      engine: engineName,
      score: (json['score'] is num)
          ? (json['score'] as num).round().clamp(0, 100).toInt()
          : 50,
      tldr: strings('tldr'),
      findings: findings,
      jargon: ((json['jargon'] as List?) ?? const [])
          .whereType<Map>()
          .map((j) => JargonTerm.fromJson(Map<String, dynamic>.from(j)))
          .toList(),
      keyFacts: ((json['key_facts'] as List?) ?? const [])
          .whereType<Map>()
          .map((j) => KeyFact.fromJson(Map<String, dynamic>.from(j)))
          .toList(),
      questions: strings('questions'),
      wordCount: countWords(input.text),
      text: trimForStorage(input.text),
      summary: json['summary']?.toString(),
      audience: json['audience']?.toString(),
      note: input.text.length > _maxChars
          ? 'Very long document — AI read the first ${_maxChars ~/ 1000}k characters.'
          : null,
    );
  }

  static Map<String, dynamic>? _extractJson(String raw) {
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start == -1 || end <= start) return null;
    try {
      final v = jsonDecode(raw.substring(start, end + 1));
      return v is Map<String, dynamic> ? v : null;
    } catch (_) {
      return null;
    }
  }
}
