import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/analysis.dart';
import 'ai_prompt.dart';
import 'analyzer.dart';

/// Reads terms with Anthropic's Claude, using the person's own API key
/// (entered in Settings, stored only on the phone).
class ClaudeAnalyzer implements ContractAnalyzer {
  ClaudeAnalyzer({
    required this.apiKey,
    this.model = 'claude-sonnet-5-5',
    this.endpoint = 'https://api.anthropic.com/v1/messages',
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String apiKey;
  final String model;
  final String endpoint;
  final http.Client _client;

  @override
  String get engineName => 'Claude · $model';

  @override
  Future<AnalysisResult> analyze(ContractInput input) async {
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
            'temperature': 0.2,
            'system': AiPrompt.system(input),
            'messages': [
              {'role': 'user', 'content': AiPrompt.user(input)},
            ],
          }),
        )
        .timeout(const Duration(seconds: 60));
    if (res.statusCode != 200) throw AiFailure(AiPrompt.reasonForStatus(res.statusCode, res.body));
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final raw = ((body['content'] as List?) ?? const [])
        .whereType<Map>()
        .where((b) => b['type'] == 'text')
        .map((b) => b['text'].toString())
        .join();
    return AiPrompt.parse(raw, input, engineName);
  }
}
