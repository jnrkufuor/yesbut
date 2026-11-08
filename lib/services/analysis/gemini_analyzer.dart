import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/analysis.dart';
import 'ai_prompt.dart';
import 'analyzer.dart';

/// Reads terms with Google's Gemini on the free tier of the Gemini API. The
/// key comes from the build (`--dart-define=GEMINI_API_KEY=…`).
/// Speed: uses a "lite" flash model with thinking switched off, and sends a
/// shortened document (see [AiPrompt.shorten]).
class GeminiAnalyzer implements ContractAnalyzer {
  GeminiAnalyzer({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  static const apiKey = String.fromEnvironment('GEMINI_API_KEY');
  static bool get available => apiKey.isNotEmpty;

  static const _base = 'https://generativelanguage.googleapis.com/v1beta';
  static String? _model;
  static int _style = 0; // which request shape this model accepts (see _post)

  @override
  String get engineName => 'Gemini · ${_model ?? 'flash'}';

  /// Fastest current text model for this key: newest stable flash-lite,
  /// then flash. Names change over time, so we ask instead of hard-coding.
  Future<String> _pickModel() async {
    if (_model != null) return _model!;
    try {
      final res = await _client
          .get(Uri.parse('$_base/models?key=$apiKey&pageSize=200'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) throw AiFailure(AiPrompt.reasonForStatus(res.statusCode, res.body));
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final names = ((data['models'] as List?) ?? const [])
          .whereType<Map>()
          .where((m) => ((m['supportedGenerationMethods'] as List?) ?? const []).contains('generateContent'))
          .map((m) => (m['name'] ?? '').toString().replaceFirst('models/', ''))
          .where((n) =>
              n.contains('gemini') &&
              n.contains('flash') &&
              !RegExp(r'image|tts|audio|live|thinking|embedding|vision|computer').hasMatch(n))
          .toList();
      int rank(String n) {
        var r = 0;
        final v = RegExp(r'gemini-(\d+(?:\.\d+)?)').firstMatch(n);
        if (v != null) r += (double.parse(v.group(1)!) * 100).round();
        if (n.contains('lite')) r += 60; // fastest
        if (n.contains('preview') || n.contains('exp')) r -= 80;
        if (RegExp(r'-\d{3}$|-\d{2}-\d{4}$').hasMatch(n)) r -= 3; // pinned snapshots
        return r;
      }

      names.sort((a, b) => rank(b).compareTo(rank(a)));
      _model = names.isNotEmpty ? names.first : 'gemini-flash-lite-latest';
    } on AiFailure {
      rethrow;
    } catch (_) {
      _model = 'gemini-flash-lite-latest';
    }
    return _model!;
  }

  /// Request shapes, fastest first. Models differ in what they accept
  /// (older ones want a thinking budget, newer ones a thinking level, some
  /// neither), so on "invalid argument" we step down to the next shape.
  static const _styles = 4;
  Map<String, dynamic> _config(int style) => {
        'temperature': 0.2,
        if (style < 3) 'responseMimeType': 'application/json',
        if (style == 0) 'thinkingConfig': {'thinkingBudget': 0},
        if (style == 1) 'thinkingConfig': {'thinkingLevel': 'low'},
      };

  Future<http.Response> _post(String model, ContractInput input, int style) => _client
      .post(
        Uri.parse('$_base/models/$model:generateContent?key=$apiKey'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({
          'systemInstruction': {
            'parts': [
              {'text': AiPrompt.system(input)}
            ]
          },
          'contents': [
            {
              'role': 'user',
              'parts': [
                {'text': AiPrompt.user(input)}
              ]
            }
          ],
          'generationConfig': _config(style),
        }),
      )
      .timeout(const Duration(seconds: 45));

  @override
  Future<AnalysisResult> analyze(ContractInput input) async {
    var model = await _pickModel();
    var res = await _post(model, input, _style);
    while (res.statusCode == 400 && _style < _styles - 1) {
      _style++;
      res = await _post(model, input, _style);
    }
    if (res.statusCode == 400 || res.statusCode == 404) {
      // This model won't take it at all; try the stable fast aliases.
      for (final alt in ['gemini-flash-lite-latest', 'gemini-flash-latest', 'gemini-2.5-flash-lite']) {
        if (alt == model) continue;
        for (var st = 0; st < _styles; st++) {
          res = await _post(alt, input, st);
          if (res.statusCode != 400) break;
        }
        if (res.statusCode == 200) {
          _model = model = alt;
          break;
        }
      }
    }
    if (res.statusCode != 200) throw AiFailure(AiPrompt.reasonForStatus(res.statusCode, res.body));
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final cands = body['candidates'] as List?;
    if (cands == null || cands.isEmpty) throw AiFailure('it declined to answer');
    final parts = ((cands.first as Map)['content'] as Map?)?['parts'] as List?;
    final raw = parts?.map((p) => (p as Map)['text'] ?? '').join() ?? '';
    return AiPrompt.parse(raw, input, engineName);
  }
}
