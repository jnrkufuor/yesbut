import 'package:flutter/foundation.dart';

import '../models/analysis.dart';
import '../services/analysis/ai_prompt.dart';
import '../services/analysis/context_profile.dart';
import '../services/analysis/deepseek_analyzer.dart';
import '../services/analysis/gemini_analyzer.dart';
import '../services/analysis/offline_translator.dart';
import '../services/analysis/rule_based_analyzer.dart';
import '../services/catalog_repository.dart';
import '../i18n/translations.dart';
import '../services/storage.dart';
import '../services/watch_service.dart';

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

  // ---------------------------------------------------------------- watch list
  List<WatchItem> _watch = [];
  List<WatchItem> get watchlist => List.unmodifiable(_watch);
  bool _checkingWatch = false;
  bool get checkingWatch => _checkingWatch;

  bool isWatching(String? url) => url != null && _watch.any((w) => w.url == url);

  Future<void> watch(AnalysisResult r) async {
    final url = r.sourceRef;
    if (url == null || isWatching(url)) return;
    _watch.insert(0, WatchItem(url: url, title: r.title, addedAt: DateTime.now(), score: r.score, lastChecked: DateTime.now()));
    notifyListeners();
    await WatchService.save(_watch);
    await WatchService.askPermission();
    await WatchService.scheduleBackground();
  }

  Future<void> unwatch(String url) async {
    _watch.removeWhere((w) => w.url == url);
    notifyListeners();
    await WatchService.save(_watch);
  }

  /// Re-check everything you watch now (Live tab pull-to-refresh / open).
  Future<int> refreshWatch() async {
    if (_checkingWatch || _watch.isEmpty) return 0;
    _checkingWatch = true;
    notifyListeners();
    final (updated, changed) = await WatchService.checkAll(_watch);
    _watch = updated;
    _checkingWatch = false;
    notifyListeners();
    await WatchService.save(_watch);
    return changed.length;
  }
  AppSettings get settings => _settings;
  bool get onboarded => _onboarded;

  Future<void> init() async {
    await _storage.init();
    _history = _storage.loadHistory();
    _settings = _storage.loadSettings();
    await i18n.setLanguage(_settings.resultLanguage);
    _onboarded = _storage.onboarded;
    _watch = await WatchService.load();
    if (_watch.isNotEmpty) WatchService.scheduleBackground();
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

  /// AI readers available in this build, in the order to try them.
  static Map<EngineChoice, ({String name, bool available, Future<AnalysisResult> Function(ContractInput) run})> get readers => {
        EngineChoice.gemini: (name: 'Gemini', available: GeminiAnalyzer.available, run: (i) => GeminiAnalyzer().analyze(i)),
        EngineChoice.deepseek: (name: 'DeepSeek', available: DeepSeekAnalyzer.available, run: (i) => DeepSeekAnalyzer().analyze(i)),
      };

  /// Chosen reader first, then the other AI, then the phone. Returns the
  /// result and a note explaining any fallback.
  Future<(AnalysisResult, String?)> _read(ContractInput work, RuleBasedAnalyzer offline) async {
    final choice = _settings.engine;
    if (choice == EngineChoice.offline) return (await offline.analyze(work), null);
    final order = [choice, ...readers.keys.where((k) => k != choice)];
    final misses = <String>[];
    for (final k in order) {
      final r = readers[k];
      if (r == null) continue;
      if (!r.available) {
        if (k == choice) misses.add('${r.name} isn’t set up in this build');
        continue;
      }
      try {
        final res = await r.run(work);
        final note = misses.isEmpty ? null : '${misses.join('; ')}, so ${r.name} read this instead.';
        return (res, note);
      } catch (e) {
        misses.add('${r.name} couldn’t answer (${AiPrompt.reasonFor(e)})');
      }
    }
    final res = await offline.analyze(work);
    return (res, misses.isEmpty ? null : '${misses.join('; ')}, so this is the offline check on your phone.');
  }

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
    final result0 = await _read(work, offline);
    var result = result0.$1;
    if (result0.$2 != null) note = note == null ? result0.$2 : '${result0.$2} $note';
    result = result.copyWith(
      note: note ?? result.note,
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
    final i = _watch.indexWhere((w) => w.url == r.sourceRef);
    if (i != -1) {
      _watch[i] = WatchItem(
        url: _watch[i].url,
        title: _watch[i].title,
        addedAt: _watch[i].addedAt,
        lastChecked: DateTime.now(),
        hash: _watch[i].hash,
        pageDate: _watch[i].pageDate,
        score: r.score,
        changed: false,
      );
      WatchService.save(_watch);
    }
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
