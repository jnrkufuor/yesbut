import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/analysis/offline_translator.dart';

/// Whole-app translation, done on the phone by a translation model (Google
/// ML Kit). Every string shown through our [Text] widget is looked up here;
/// unseen strings are batched, translated in the background and cached, then
/// the UI rebuilds in the new language. Works offline after the first
/// download of each language.
class Translations extends ChangeNotifier {
  String _lang = 'en';
  String get lang => _lang;

  final Map<String, Map<String, String>> _cache = {};
  final Set<String> _pending = {};
  Timer? _flush;
  Timer? _save;
  bool _busy = false;

  Future<void> setLanguage(String lang) async {
    if (lang == _lang) return;
    _lang = lang;
    if (lang != 'en' && !_cache.containsKey(lang)) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('i18n_$lang');
        _cache[lang] = raw == null ? {} : Map<String, String>.from(jsonDecode(raw) as Map);
      } catch (_) {
        _cache[lang] = {};
      }
    }
    notifyListeners();
  }

  bool get _idle => _pending.isEmpty && !_busy && _flush == null;

  /// Resolves once every string on screen has been translated (or after
  /// [max]). Used by the language screen so the app has really switched
  /// before it closes.
  Future<void> settle({Duration max = const Duration(seconds: 12)}) async {
    final end = DateTime.now().add(max);
    var calm = 0;
    while (DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      calm = _idle ? calm + 1 : 0;
      if (calm >= 3) return; // idle across a few frames: nothing new queued
    }
  }

  static final _letters = RegExp(r'[A-Za-z]{2,}');
  static final _urlish = RegExp(r'(://|www\.|^\S+\.[a-z]{2,}(/\S*)?$)', caseSensitive: false);

  static bool worthTranslating(String s) =>
      s.length < 600 && _letters.hasMatch(s) && !_urlish.hasMatch(s.trim());

  String tr(String raw) {
    if (_lang == 'en' || !worthTranslating(raw)) return raw;
    // Translate the words, keep the spaces around them ("Make it " + "yours").
    final s = raw.trim();
    final lead = raw.substring(0, raw.indexOf(s));
    final tail = raw.substring(raw.indexOf(s) + s.length);
    final hit = _cache[_lang]?[s];
    if (hit != null) return '$lead$hit$tail';
    _pending.add(s);
    _flush ??= Timer(const Duration(milliseconds: 120), _translatePending);
    return raw;
  }

  bool has(String s) => _lang == 'en' || _cache[_lang]?.containsKey(s.trim()) == true;

  /// Translate a whole list up front (all the app's UI copy) so screens open
  /// already in the new language instead of flashing English first.
  Future<void> warm(Iterable<String> strings) async {
    final lang = _lang;
    if (lang == 'en') return;
    final map = _cache.putIfAbsent(lang, () => {});
    final todo = strings.map((e) => e.trim()).where((e) => worthTranslating(e) && !map.containsKey(e)).toSet().toList();
    for (var i = 0; i < todo.length; i += 40) {
      if (lang != _lang) return; // switched again meanwhile
      final batch = todo.sublist(i, (i + 40).clamp(0, todo.length));
      try {
        final out = await OfflineTranslator.translateAll(batch, 'en', lang);
        for (var k = 0; k < batch.length; k++) {
          map[batch[k]] = out[k];
        }
      } catch (_) {
        return; // no language pack yet: the on-demand path takes over
      }
    }
    _scheduleSave(lang);
    notifyListeners();
  }

  Future<void> _translatePending() async {
    _flush = null;
    if (_busy || _pending.isEmpty) return;
    _busy = true;
    final lang = _lang;
    final batch = _pending.take(60).toList();
    _pending.removeAll(batch);
    try {
      final out = await OfflineTranslator.translateAll(batch, 'en', lang);
      final map = _cache.putIfAbsent(lang, () => {});
      for (var i = 0; i < batch.length; i++) {
        map[batch[i]] = out[i];
      }
      if (lang == _lang) notifyListeners();
      _scheduleSave(lang);
    } catch (_) {
      // No language pack yet (offline on first use): stay in English.
    } finally {
      _busy = false;
      if (_pending.isNotEmpty) _flush ??= Timer(const Duration(milliseconds: 60), _translatePending);
    }
  }

  void _scheduleSave(String lang) {
    _save?.cancel();
    _save = Timer(const Duration(seconds: 2), () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('i18n_$lang', jsonEncode(_cache[lang] ?? {}));
      } catch (_) {}
    });
  }
}
