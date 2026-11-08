import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/analysis.dart';
import 'analyzer.dart';
import 'context_profile.dart';

/// Reads terms with Google's Gemini models on the free tier of the Gemini
/// API. The key comes from the build (`--dart-define=GEMINI_API_KEY=…`), so
/// it never sits in the source code. Each document is judged against a
/// scoring guide for its own deal type and industry.
class GeminiAnalyzer implements ContractAnalyzer {
  GeminiAnalyzer({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  static const apiKey = String.fromEnvironment('GEMINI_API_KEY');
  static bool get available => apiKey.isNotEmpty;

  static const _base = 'https://generativelanguage.googleapis.com/v1beta';
  static String? _model; // picked once from the models the key can use
  static const _maxChars = 120000;

  @override
  String get engineName => 'AI · ${_model ?? 'Gemini'}';

  /// Choose the best fast text model available to this key (names change
  /// over time, so we ask instead of hard-coding one).
  Future<String> _pickModel() async {
    if (_model != null) return _model!;
    try {
      final res = await _client
          .get(Uri.parse('$_base/models?key=$apiKey&pageSize=200'))
          .timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final names = ((data['models'] as List?) ?? const [])
          .whereType<Map>()
          .where((m) => ((m['supportedGenerationMethods'] as List?) ?? const []).contains('generateContent'))
          .map((m) => (m['name'] ?? '').toString().replaceFirst('models/', ''))
          .where((n) =>
              n.contains('gemini') &&
              n.contains('flash') &&
              !RegExp(r'image|tts|audio|live|thinking-exp|embedding|vision').hasMatch(n))
          .toList();
      int rank(String n) {
        var r = 0;
        final v = RegExp(r'gemini-(\d+(?:\.\d+)?)').firstMatch(n);
        if (v != null) r += (double.parse(v.group(1)!) * 100).round();
        if (n.contains('lite')) r -= 15;
        if (n.contains('preview') || n.contains('exp')) r -= 30;
        if (n.endsWith('latest')) r += 5;
        return r;
      }

      names.sort((a, b) => rank(b).compareTo(rank(a)));
      _model = names.isNotEmpty ? names.first : 'gemini-flash-latest';
    } catch (_) {
      _model = 'gemini-flash-latest';
    }
    return _model!;
  }

  static String _guide(ContractInput input) {
    final type = ContextProfiler.describeType(input.dealType);
    final ind = ContextProfiler.industryLabel(input.industry);
    final indNote = ContextProfiler.industryNote(input.industry);
    return '''
This document looks like the terms for $type${ind.isEmpty ? '' : ' in $ind'}.
Judge it the way a regular customer of that kind of service would, not as a generic contract.
${ContextProfiler.weightingNote(input.dealType)} $indNote
Pull out the clauses that matter most for THIS kind of service and industry (for example: for beauty, reactions/patch tests, returns of opened products, auto-ship; for games, virtual currency and bans; for food delivery, allergens, missing orders and fees). Generic boilerplate (liability caps, arbitration) still counts, but do not let it crowd out what is specific to this service.''';
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
Order findings red_flag first. 5-12 findings. Never invent clauses that are not in the text. Write in English.''';

  @override
  Future<AnalysisResult> analyze(ContractInput input) async {
    final model = await _pickModel();
    var text = input.text;
    if (text.length > _maxChars) text = text.substring(0, _maxChars);
    final res = await _client
        .post(
          Uri.parse('$_base/models/$model:generateContent?key=$apiKey'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode({
            'systemInstruction': {
              'parts': [
                {'text': 'You are Yes,But, a friend who reads terms and conditions for regular people.\n${_guide(input)}\n$_schema'}
              ]
            },
            'contents': [
              {
                'role': 'user',
                'parts': [
                  {'text': 'Title (may be a guess): ${input.title}\n\n<document>\n$text\n</document>'}
                ]
              }
            ],
            'generationConfig': {'responseMimeType': 'application/json', 'temperature': 0.2},
          }),
        )
        .timeout(const Duration(seconds: 60));
    if (res.statusCode != 200) {
      throw AnalysisException('AI unavailable (${res.statusCode}).');
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final parts = (((body['candidates'] as List?)?.first as Map?)?['content'] as Map?)?['parts'] as List?;
    final raw = parts?.map((p) => (p as Map)['text'] ?? '').join() ?? '';
    final s = raw.indexOf('{'), e = raw.lastIndexOf('}');
    if (s == -1 || e <= s) throw AnalysisException('AI returned an unreadable answer.');
    final json = jsonDecode(raw.substring(s, e + 1)) as Map<String, dynamic>;

    List<String> strings(String k) => ((json[k] as List?) ?? const []).map((x) => x.toString()).toList();
    List<T> list<T>(String k, T Function(Map<String, dynamic>) f) =>
        ((json[k] as List?) ?? const []).whereType<Map>().map((m) => f(Map<String, dynamic>.from(m))).toList();

    final findings = list('findings', Finding.fromJson)..sort((a, b) => a.severity.index.compareTo(b.severity.index));
    final aiTitle = json['title']?.toString().trim();
    return AnalysisResult(
      id: newId(),
      title: (input.kind == SourceKind.library || input.kind == SourceKind.link || aiTitle == null || aiTitle.isEmpty)
          ? input.title
          : aiTitle,
      sourceKind: input.kind,
      sourceRef: input.ref,
      analyzedAt: DateTime.now(),
      engine: engineName,
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
