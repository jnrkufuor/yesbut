import 'package:google_mlkit_translation/google_mlkit_translation.dart';

/// On-device translation (Google ML Kit). The first time a language is used
/// its pack (~30 MB) downloads; after that it works fully offline.
class OfflineTranslator {
  static TranslateLanguage? _lang(String code) => switch (code) {
        'en' => TranslateLanguage.english,
        'fr' => TranslateLanguage.french,
        'es' => TranslateLanguage.spanish,
        'de' => TranslateLanguage.german,
        'pt' => TranslateLanguage.portuguese,
        'it' => TranslateLanguage.italian,
        _ => null,
      };

  static bool supports(String code) => _lang(code) != null;

  static Future<void> _ensure(TranslateLanguage l) async {
    final mm = OnDeviceTranslatorModelManager();
    if (!await mm.isModelDownloaded(l.bcpCode)) {
      final ok = await mm.downloadModel(l.bcpCode, isWifiRequired: false);
      if (!ok) throw TranslationUnavailable();
    }
  }

  /// Translates [text] in paragraph-sized chunks (long docs are capped).
  static Future<String> translate(String text, String from, String to) async {
    final out = await translateAll([text.length > 60000 ? text.substring(0, 60000) : text], from, to, chunk: true);
    return out.first;
  }

  static Future<List<String>> translateAll(List<String> items, String from, String to, {bool chunk = false}) async {
    final src = _lang(from), dst = _lang(to);
    if (src == null || dst == null) throw TranslationUnavailable();
    if (src == dst) return items;
    try {
      await _ensure(src);
      await _ensure(dst);
    } catch (_) {
      throw TranslationUnavailable();
    }
    final t = OnDeviceTranslator(sourceLanguage: src, targetLanguage: dst);
    try {
      final result = <String>[];
      for (final item in items) {
        if (item.trim().isEmpty) {
          result.add(item);
          continue;
        }
        if (!chunk) {
          result.add(await t.translateText(item));
          continue;
        }
        final buf = StringBuffer();
        for (final part in _chunks(item)) {
          buf.writeln(await t.translateText(part));
        }
        result.add(buf.toString());
      }
      return result;
    } finally {
      await t.close();
    }
  }

  static Iterable<String> _chunks(String text) sync* {
    final paras = text.split(RegExp(r'\n+'));
    final buf = StringBuffer();
    for (final p in paras) {
      if (buf.length + p.length > 900 && buf.isNotEmpty) {
        yield buf.toString();
        buf.clear();
      }
      buf.writeln(p);
    }
    if (buf.isNotEmpty) yield buf.toString();
  }
}

class TranslationUnavailable implements Exception {}
