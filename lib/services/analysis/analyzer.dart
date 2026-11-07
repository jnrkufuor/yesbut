import '../../models/analysis.dart';

/// Anything that can turn contract text into an [AnalysisResult].
///
/// Add new engines (a backend API, another LLM, an on-device model) by
/// implementing this and registering it in [AnalyzerRegistry].
abstract class ContractAnalyzer {
  String get engineName;
  Future<AnalysisResult> analyze(ContractInput input);
}

class AnalysisException implements Exception {
  final String message;
  AnalysisException(this.message);
  @override
  String toString() => message;
}

String newId() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);

int countWords(String text) =>
    RegExp(r"[A-Za-z0-9À-ɏ'’]+").allMatches(text).length;

/// Keep stored copies of the original text bounded.
String trimForStorage(String text, {int max = 60000}) =>
    text.length <= max ? text : '${text.substring(0, max)}\n\n[…trimmed]';
