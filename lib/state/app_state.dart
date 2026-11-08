import 'package:flutter/foundation.dart';

import '../models/analysis.dart';
import '../services/analysis/claude_analyzer.dart';
import '../services/analysis/context_profile.dart';
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
    final profile = ContextProfiler.profile(input);
    final langName = ContextProfiler.languageNames[profile.language] ?? 'another language';
    final english = profile.language == 'en';
    AnalysisResult result;
    if (_settings.aiReady) {
      try {
        result = await ClaudeAnalyzer(
          apiKey: _settings.apiKey.trim(),
          model: _settings.model.trim(),
          endpoint: _settings.endpoint.trim(),
          outputLanguage: ContextProfiler.languageNames[_settings.resultLanguage] ?? 'English',
        ).analyze(input);
        if (!english) {
          result = result.copyWith(note: 'Translated from $langName by the AI engine.');
        }
      } catch (e) {
        // The offline reader can't read other languages: say so, don't guess.
        if (!english) throw UnsupportedLanguageException(langName);
        result = (await offline.analyze(input)).copyWith(
          note: 'AI check unavailable ($e). Showing the offline check instead.',
        );
      }
    } else {
      if (!english) throw UnsupportedLanguageException(langName);
      result = await offline.analyze(input);
      if (_settings.resultLanguage != 'en') {
        result = result.copyWith(note: 'Results in other languages need the AI engine (Settings). Showing English.');
      }
    }
    result = result.copyWith(
      dealType: profile.dealType,
      audience: result.audience ?? profile.audience,
      otherParty: result.otherParty ?? profile.otherParty,
      summary: result.summary ?? profile.summary,
      language: profile.language,
      focus: result.focus.isNotEmpty ? result.focus : profile.focus,
    );
    final dateNote = _dateNote(input.pageDate);
    if (dateNote != null) {
      result = result.copyWith(note: result.note == null ? dateNote : '$dateNote ${result.note}');
    }
    _save(result);
    return result;
  }

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  /// "These terms were last updated March 2025." (+ a nudge if it's old).
  static String? _dateNote(DateTime? d) {
    if (d == null) return null;
    final when = '${_months[d.month - 1]} ${d.year}';
    final old = DateTime.now().difference(d).inDays > 425;
    return old
        ? 'These terms say they were last updated in $when. That’s over a year ago, so there may be a newer version.'
        : 'These terms were last updated in $when.';
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

  /// How many checks were made within [within] (null = all of them).
  int countWithin(Duration? within) {
    if (within == null) return _history.length;
    final cut = DateTime.now().subtract(within);
    return _history.where((h) => h.analyzedAt.isAfter(cut)).length;
  }

  Future<void> clearHistory({Duration? within}) async {
    if (within != null) {
      final cut = DateTime.now().subtract(within);
      _history.removeWhere((h) => h.analyzedAt.isAfter(cut));
      notifyListeners();
      await _storage.saveHistory(_history);
      return;
    }
    _history.clear();
    notifyListeners();
    await _storage.saveHistory(_history);
  }
}
