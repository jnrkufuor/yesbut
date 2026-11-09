import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/analysis.dart';

/// Which reader checks your terms. AI readers fall back to each other, then
/// to the phone, so you always get an answer.
enum EngineChoice { offline, gemini, deepseek, claude }

class AppSettings {
  final EngineChoice engine;
  final String apiKey;
  final String model;
  final String endpoint;
  final String resultLanguage; // language results are written in (AI engine)
  final bool largerText;
  final double textScale; // 0.85 … 1.4
  final bool sounds;
  final bool haptics;
  final bool boldText;
  final bool reduceMotion;

  const AppSettings({
    this.engine = EngineChoice.deepseek,
    this.apiKey = '',
    this.model = 'claude-sonnet-5-5',
    this.endpoint = 'https://api.anthropic.com/v1/messages',
    this.resultLanguage = 'en',
    this.largerText = false,
    this.textScale = 1.0,
    this.sounds = true,
    this.haptics = true,
    this.boldText = false,
    this.reduceMotion = false,
  });


  AppSettings copyWith({
    EngineChoice? engine,
    String? apiKey,
    String? model,
    String? endpoint,
    String? resultLanguage,
    bool? largerText,
    double? textScale,
    bool? sounds,
    bool? haptics,
    bool? boldText,
    bool? reduceMotion,
  }) =>
      AppSettings(
        engine: engine ?? this.engine,
        apiKey: apiKey ?? this.apiKey,
        model: model ?? this.model,
        endpoint: endpoint ?? this.endpoint,
        resultLanguage: resultLanguage ?? this.resultLanguage,
        largerText: largerText ?? this.largerText,
        textScale: textScale ?? this.textScale,
        sounds: sounds ?? this.sounds,
        haptics: haptics ?? this.haptics,
        boldText: boldText ?? this.boldText,
        reduceMotion: reduceMotion ?? this.reduceMotion,
      );
}

/// Local persistence. Swap for a database or cloud sync later without
/// touching the UI — only [AppState] talks to this.
class Storage {
  static const _historyKey = 'history_v1';
  static const _engineKey = 'engine';
  static const _apiKeyKey = 'api_key';
  static const _modelKey = 'model';
  static const _endpointKey = 'endpoint';
  static const _onboardedKey = 'onboarded';
  static const maxHistory = 50;

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  List<AnalysisResult> loadHistory() {
    final raw = _prefs.getString(_historyKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .whereType<Map>()
          .map((m) => AnalysisResult.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveHistory(List<AnalysisResult> items) => _prefs.setString(
        _historyKey,
        jsonEncode(items.take(maxHistory).map((e) => e.toJson()).toList()),
      );

  AppSettings loadSettings() {
    const d = AppSettings();
    return AppSettings(
      engine: switch (_prefs.getString('reader_v3')) {
        'offline' => EngineChoice.offline,
        'gemini' => EngineChoice.gemini,
        'claude' => EngineChoice.claude,
        _ => EngineChoice.deepseek,
      },
      apiKey: _prefs.getString(_apiKeyKey) ?? '',
      model: _prefs.getString(_modelKey) ?? d.model,
      endpoint: _prefs.getString(_endpointKey) ?? d.endpoint,
      resultLanguage: _prefs.getString('result_language') ?? 'en',
      largerText: _prefs.getBool('a11y_larger') ?? false,
      textScale: _prefs.getDouble('a11y_scale') ?? ((_prefs.getBool('a11y_larger') ?? false) ? 1.2 : 1.0),
      sounds: _prefs.getBool('a11y_sounds') ?? true,
      haptics: _prefs.getBool('a11y_haptics') ?? true,
      boldText: _prefs.getBool('a11y_bold') ?? false,
      reduceMotion: _prefs.getBool('a11y_motion') ?? false,
    );
  }

  Future<void> saveSettings(AppSettings s) async {
    await _prefs.setString('reader_v3', s.engine.name);
    await _prefs.setString(_apiKeyKey, s.apiKey);
    await _prefs.setString(_modelKey, s.model);
    await _prefs.setString(_endpointKey, s.endpoint);
    await _prefs.setString('result_language', s.resultLanguage);
    await _prefs.setBool('a11y_larger', s.largerText);
    await _prefs.setDouble('a11y_scale', s.textScale);
    await _prefs.setBool('a11y_sounds', s.sounds);
    await _prefs.setBool('a11y_haptics', s.haptics);
    await _prefs.setBool('a11y_bold', s.boldText);
    await _prefs.setBool('a11y_motion', s.reduceMotion);
  }

  bool get onboarded => _prefs.getBool(_onboardedKey) ?? false;
  Future<void> setOnboarded() => _prefs.setBool(_onboardedKey, true);
}
