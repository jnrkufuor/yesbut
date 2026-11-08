import 'package:flutter/foundation.dart';

import '../models/analysis.dart';
import '../services/analysis/claude_analyzer.dart';
import '../services/analysis/context_profile.dart';
import '../services/analysis/offline_translator.dart';
import '../services/analysis/rule_based_analyzer.dart';
import '../services/catalog_repository.dart';
import '../i18n/translations.dart';
import '../services/storage.dart';

class AppState extends ChangeNotifier {
  AppState(this._storage);

  /// Whole-app language (translated on the phone).
  final i18n = Translations();

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
    await i18n.setLanguage(_settings.resultLanguage);
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
    await i18n.setLanguage(s.resultLanguage);
    notifyListeners();
    await _storage.saveSettings(s);
  }

  /// Runs the preferred engine and falls back to offline if AI fails, so
  /// the user always gets an answer.
  /// The AI engine is switched off for now; everything runs on the phone.
  static const aiEnabled = false;

  Future<AnalysisResult> analyze(ContractInput input) async {
    final offline = await RuleBasedAnalyzer.load();
    final lang = ContextProfiler.detectLanguage(input.text);
    final langName = ContextProfiler.languageNames[lang] ?? 'another language';

    // Not English? Translate it on the phone first (works offline once the
    // language pack is downloaded). If we can't, say so instead of guessing.
    var work = input;
    String? note;
    if (lang != 'en') {
      if (!OfflineTranslator.supports(lang)) throw UnsupportedLanguageException(langName);
      try {
        work = input.copyWith(text: await OfflineTranslator.translate(input.text, lang, 'en'));
        note = 'Translated from $langName on your phone. Quotes are translated too, so check the original for exact wording.';
      } on TranslationUnavailable {
        throw UnsupportedLanguageException(langName, needsDownload: true);
      }
    }

    final profile = ContextProfiler.profile(work);
    work = work.copyWith(dealType: profile.dealType, industry: profile.industry);
    AnalysisResult result;
    if (aiEnabled && _settings.aiReady) {
      try {
        result = await ClaudeAnalyzer(
          apiKey: _settings.apiKey.trim(),
          model: _settings.model.trim(),
          endpoint: _settings.endpoint.trim(),
        ).analyze(work);
      } catch (e) {
        result = await offline.analyze(work);
      }
    } else {
      result = await offline.analyze(work);
    }
    result = result.copyWith(
      note: note,
      dealType: profile.dealType,
      industry: profile.industry,
      audience: result.audience ?? profile.audience,
      otherParty: result.otherParty ?? profile.otherParty,
      summary: result.summary ?? profile.summary,
      language: lang,
    );

    // Results stay stored in English; the app-wide translator shows them in
    // the app language (so switching language later re-translates history).
    final dateNote = _dateNote(input.pageDate);
    if (dateNote != null) {
      result = result.copyWith(note: result.note == null ? dateNote : '$dateNote ${result.note}');
    }
    _save(result);
    return result;
  }

  Future<AnalysisResult> _translateResult(AnalysisResult r, String to) async {
    final f = r.findings;
    final items = <String>[
      ...r.tldr,
      for (final x in f) x.title,
      for (final x in f) x.plain,
      for (final k in r.keyFacts) k.value,
      ...r.questions,
      r.summary ?? '',
      r.audience ?? '',
      r.otherParty ?? '',
    ];
    final t = await OfflineTranslator.translateAll(items, 'en', to);
    var i = 0;
    List<String> take(int n) {
      final out = t.sublist(i, i + n);
      i += n;
      return out;
    }

    final tldr = take(r.tldr.length);
    final titles = take(f.length);
    final plains = take(f.length);
    final facts = take(r.keyFacts.length);
    final qs = take(r.questions.length);
    final rest = take(3);
    return r.copyWith(
      tldr: tldr,
      findings: [
        for (var k = 0; k < f.length; k++)
          Finding(title: titles[k], plain: plains[k], severity: f[k].severity, category: f[k].category, quote: f[k].quote),
      ],
      keyFacts: [for (var k = 0; k < r.keyFacts.length; k++) KeyFact(r.keyFacts[k].label, facts[k])],
      questions: qs,
      summary: rest[0].isEmpty ? null : rest[0],
      audience: rest[1].isEmpty ? null : rest[1],
      otherParty: rest[2].isEmpty ? null : rest[2],
    );
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
