import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/analysis.dart';
import 'ai_prompt.dart';
import 'analyzer.dart';

/// Reads terms with DeepSeek (open-weights model) through OpenRouter, which
/// hosts free versions of it. Key comes from the build
/// (`--dart-define=OPENROUTER_API_KEY=…`).
class DeepSeekAnalyzer implements ContractAnalyzer {
  DeepSeekAnalyzer({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  static const apiKey = String.fromEnvironment('OPENROUTER_API_KEY');
  static bool get available => apiKey.isNotEmpty;

  static const _base = 'https://openrouter.ai/api/v1';
  static const _fallbacks = [
    'deepseek/deepseek-v4-flash:free',
    'deepseek/deepseek-chat-v3.1:free',
    'deepseek/deepseek-chat-v3-0324:free',
  ];
  static List<String>? _models;
  static bool _noReasoningParam = false;

  @override
  String get engineName => 'DeepSeek · ${(_models?.first ?? 'v4 flash').replaceFirst('deepseek/', '')}';

  /// Free DeepSeek models OpenRouter offers right now, newest first. The free
  /// line-up changes, so we ask (falling back to known names).
  Future<List<String>> _pickModels() async {
    if (_models != null) return _models!;
    try {
      final res = await _client.get(Uri.parse('$_base/models')).timeout(const Duration(seconds: 10));
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final ids = ((data['data'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => (m['id'] ?? '').toString())
          .where((id) => id.startsWith('deepseek/') && id.endsWith(':free') && !RegExp(r'qwen|llama|distill|prover|ocr').hasMatch(id))
          .toList();
      int rank(String id) {
        var r = 0;
        final v = RegExp(r'v(\d+(?:\.\d+)?)').firstMatch(id);
        if (v != null) r += (double.parse(v.group(1)!) * 100).round();
        if (id.contains('flash') || id.contains('chat')) r += 40; // fast, no long thinking
        if (RegExp(r'-r\d|reason').hasMatch(id)) r -= 60; // slow thinkers
        return r;
      }

      ids.sort((a, b) => rank(b).compareTo(rank(a)));
      _models = [...ids.take(3), ..._fallbacks.where((f) => !ids.contains(f))];
    } catch (_) {
      _models = [..._fallbacks];
    }
    return _models!;
  }

  Future<http.Response> _post(String model, ContractInput input, {required bool reasoningOff}) => _client
      .post(
        Uri.parse('$_base/chat/completions'),
        headers: {
          'content-type': 'application/json',
          'authorization': 'Bearer $apiKey',
          'x-title': 'Yes,But',
        },
        body: jsonEncode({
          'model': model,
          'messages': [
            {'role': 'system', 'content': AiPrompt.system(input)},
            {'role': 'user', 'content': AiPrompt.user(input)},
          ],
          'temperature': 0.2,
          'max_tokens': 4096,
          'response_format': {'type': 'json_object'},
          if (reasoningOff) 'reasoning': {'enabled': false},
        }),
      )
      .timeout(const Duration(seconds: 60));

  @override
  Future<AnalysisResult> analyze(ContractInput input) async {
    final models = await _pickModels();
    AiFailure? last;
    for (final model in models.take(3)) {
      var res = await _post(model, input, reasoningOff: !_noReasoningParam);
      if (res.statusCode == 400 && !_noReasoningParam) {
        _noReasoningParam = true;
        res = await _post(model, input, reasoningOff: false);
      }
      if (res.statusCode == 404 || res.statusCode == 402) {
        last = AiFailure(AiPrompt.reasonForStatus(res.statusCode, res.body));
        continue; // that free model went away; try the next one
      }
      if (res.statusCode != 200) throw AiFailure(AiPrompt.reasonForStatus(res.statusCode, res.body));
      final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      if (body['error'] is Map) {
        final code = ((body['error'] as Map)['code'] as num?)?.toInt() ?? 500;
        throw AiFailure(AiPrompt.reasonForStatus(code, jsonEncode(body['error'])));
      }
      final choices = body['choices'] as List?;
      final raw = (((choices?.firstOrNull as Map?)?['message'] as Map?)?['content'] ?? '').toString();
      _models = [model, ...models.where((m) => m != model)]; // remember the one that worked
      return AiPrompt.parse(raw, input, engineName);
    }
    throw last ?? AiFailure('no free DeepSeek model is available right now');
  }
}
