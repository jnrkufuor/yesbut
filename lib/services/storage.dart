import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/analysis.dart';

enum EngineChoice { offline, claude }

class AppSettings {
  final EngineChoice engine;
  final String apiKey;
  final String model;
  final String endpoint;

  const AppSettings({
    this.engine = EngineChoice.offline,
    this.apiKey = '',
    this.model = 'claude-sonnet-5-5',
    this.endpoint = 'https://api.anthropic.com/v1/messages',
  });

  bool get aiReady => engine == EngineChoice.claude && apiKey.trim().isNotEmpty;

  AppSettings copyWith({
    EngineChoice? engine,
    String? apiKey,
    String? model,
    String? endpoint,
  }) =>
      AppSettings(
        engine: engine ?? this.engine,
        apiKey: apiKey ?? this.apiKey,
        model: model ?? this.model,
        endpoint: endpoint ?? this.endpoint,
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
      engine: _prefs.getString(_engineKey) == 'claude'
          ? EngineChoice.claude
          : EngineChoice.offline,
      apiKey: _prefs.getString(_apiKeyKey) ?? '',
      model: _prefs.getString(_modelKey) ?? d.model,
      endpoint: _prefs.getString(_endpointKey) ?? d.endpoint,
    );
  }

  Future<void> saveSettings(AppSettings s) async {
    await _prefs.setString(_engineKey, s.engine.name);
    await _prefs.setString(_apiKeyKey, s.apiKey);
    await _prefs.setString(_modelKey, s.model);
    await _prefs.setString(_endpointKey, s.endpoint);
  }

  bool get onboarded => _prefs.getBool(_onboardedKey) ?? false;
  Future<void> setOnboarded() => _prefs.setBool(_onboardedKey, true);
}
