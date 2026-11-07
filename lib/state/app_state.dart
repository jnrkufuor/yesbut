import 'package:flutter/foundation.dart';

import '../models/analysis.dart';
import '../services/analysis/claude_analyzer.dart';
import '../services/analysis/rule_based_analyzer.dart';
import '../services/catalog_repository.dart';
import '../services/storage.dart';

class AppState extends ChangeNotifier {
  AppState(this._storage);

  final Storage _storage;
  final catalog = CatalogRepository();

  List<AnalysisResult> _history = [];
  AppSettings _settings = const AppSettings();
  bool _onboarded = true;

  List<AnalysisResult> get history => List.unmodifiable(_history);
  AppSettings get settings => _settings;
  bool get onboarded => _onboarded;

  Future<void> init() async {
    await _storage.init();
    _history = _storage.loadHistory();
    _settings = _storage.loadSettings();
    _onboarded = _storage.onboarded;
    await RuleBasedAnalyzer.load();
    await catalog.load();
  }

  Future<void> finishOnboarding() async {
    _onboarded = true;
    notifyListeners();
    await _storage.setOnboarded();
  }

  Future<void> updateSettings(AppSettings s) async {
    _settings = s;
    notifyListeners();
    await _storage.saveSettings(s);
  }

  /// Runs the preferred engine and falls back to offline if AI fails, so
  /// the user always gets an answer.
  Future<AnalysisResult> analyze(ContractInput input) async {
    final offline = await RuleBasedAnalyzer.load();
    AnalysisResult result;
    if (_settings.aiReady) {
      try {
        result = await ClaudeAnalyzer(
          apiKey: _settings.apiKey.trim(),
          model: _settings.model.trim(),
          endpoint: _settings.endpoint.trim(),
        ).analyze(input);
      } catch (e) {
        result = (await offline.analyze(input)).copyWith(
          note: 'AI check unavailable ($e). Showing the offline check instead.',
        );
      }
    } else {
      result = await offline.analyze(input);
    }
    _save(result);
    return result;
  }

  /// Most recent saved check for a library item, if any.
  AnalysisResult? cachedFor(String url) {
    for (final h in _history) {
      if (h.sourceRef == url) return h;
    }
    return null;
  }

  void _save(AnalysisResult r) {
    _history.removeWhere(
        (h) => h.sourceRef != null && h.sourceRef == r.sourceRef);
    _history.insert(0, r);
    notifyListeners();
    _storage.saveHistory(_history);
  }

  Future<void> rename(String id, String title) async {
    final i = _history.indexWhere((h) => h.id == id);
    if (i == -1) return;
    _history[i] = _history[i].copyWith(title: title);
    notifyListeners();
    await _storage.saveHistory(_history);
  }

  Future<void> delete(String id) async {
    _history.removeWhere((h) => h.id == id);
    notifyListeners();
    await _storage.saveHistory(_history);
  }

  Future<void> clearHistory() async {
    _history.clear();
    notifyListeners();
    await _storage.saveHistory(_history);
  }
}
