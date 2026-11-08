import 'dart:async';

import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import 'page_meta.dart';
import 'web_fetcher.dart';

/// One legal page we found for a company.
class TermsCandidate {
  final String url;
  final String host;
  final String siteName;
  final String kind; // "Terms of Use", "Privacy Policy"…
  final String? themeColor;
  final DateTime? updated;
  final int score;
  final bool scriptBuilt; // came back mostly empty: may need a retry

  const TermsCandidate({
    required this.url,
    required this.host,
    required this.siteName,
    required this.kind,
    required this.score,
    this.themeColor,
    this.updated,
    this.scriptBuilt = false,
  });

  String get title => '$siteName · $kind';
  bool get stale => updated != null && PageMeta.isStale(updated!);
}

enum FinderStage { searching, checking, dating, done }

class FinderProgress {
  final FinderStage stage;
  final int checked;
  final int total;
  const FinderProgress(this.stage, {this.checked = 0, this.total = 0});
}

/// Sniffs out a company's terms pages without any API key:
///   1. a web search (DuckDuckGo's HTML results) for "<query> terms of service",
///   2. the company's homepage footer links (Terms, Legal, Privacy…),
///   3. the usual addresses (/terms, /legal, /tos…).
/// Every candidate is fetched, scored for "looks like a legal page", and its
/// "Last updated" date is read straight from the text.
class TermsFinder {
  TermsFinder({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  static const _ua =
      'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36';
  static const _headers = {
    'User-Agent': _ua,
    'Accept': 'text/html,application/xhtml+xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
  };

  static final _legalWord = RegExp(
      r'terms|conditions|legal|tos\b|agreement|privacy|policy|eula|user-agreement|subscriber',
      caseSensitive: false);

  static const _commonPaths = [
    '/terms', '/terms-of-service', '/terms-of-use', '/legal/terms', '/tos', '/legal', '/policies/terms',
  ];

  /// [lang] is the app language: we search in it and prefer pages in it.
  Future<List<TermsCandidate>> find(String query, {String lang = 'en', void Function(FinderProgress)? onProgress}) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    onProgress?.call(const FinderProgress(FinderStage.searching));

    final urls = <String>[];
    String? domain = _domainFromQuery(q);

    // 1. Web search.
    final found = await _search('$q ${_termsWord[lang] ?? 'terms of service'}', lang);
    if (domain == null && found.isNotEmpty) domain = _pickDomain(q, found);
    domain ??= '${q.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}.com';
    final base = _registrable(domain);
    for (final u in found) {
      final h = Uri.tryParse(u)?.host ?? '';
      if (_registrable(h) == base) urls.add(u);
    }

    // 2. Homepage footer links.
    urls.addAll(await _homepageLegalLinks(domain));

    // 3. Usual suspects.
    for (final p in _commonPaths) {
      urls.add('https://$domain$p');
    }

    // Dedupe, keep it to a sensible number of fetches.
    final seen = <String>{};
    final unique = <String>[];
    for (final u in urls) {
      final key = _norm(u);
      if (key != null && seen.add(key)) unique.add(u);
    }
    final toCheck = unique.take(10).toList();

    var done = 0;
    onProgress?.call(FinderProgress(FinderStage.checking, total: toCheck.length));
    final results = await Future.wait(toCheck.map((u) async {
      final c = await _inspect(u, base);
      done++;
      onProgress?.call(FinderProgress(FinderStage.checking, checked: done, total: toCheck.length));
      return c;
    }));

    onProgress?.call(const FinderProgress(FinderStage.dating));
    // Same final URL can come from several starting points (redirects).
    final byUrl = <String, TermsCandidate>{};
    for (final c in results.whereType<TermsCandidate>()) {
      final k = _norm(c.url) ?? c.url;
      final prev = byUrl[k];
      if (prev == null || c.score > prev.score) byUrl[k] = c;
    }
    final list = byUrl.values.where((c) => c.score >= 4).toList()
      ..sort((a, b) {
        // Terms first, then privacy, then the rest; within that by score.
        int rank(TermsCandidate c) => c.kind.startsWith('Terms') || c.kind.contains('Agreement')
            ? 0
            : (c.kind == 'Privacy Policy' ? 1 : 2);
        final r = rank(a).compareTo(rank(b));
        return r != 0 ? r : b.score.compareTo(a.score);
      });
    onProgress?.call(const FinderProgress(FinderStage.done));
    return list.take(6).toList();
  }

  // ---------------------------------------------------------------------------

  static const _termsWord = {
    'en': 'terms of service',
    'fr': 'conditions générales d’utilisation',
    'es': 'términos y condiciones',
    'de': 'AGB Nutzungsbedingungen',
    'pt': 'termos de uso',
    'it': 'termini e condizioni',
  };
  static const _region = {'fr': 'fr-fr', 'es': 'es-es', 'de': 'de-de', 'pt': 'br-pt', 'it': 'it-it'};

  Future<List<String>> _search(String q, String lang) async {
    try {
      final params = {'q': q, if (_region[lang] != null) 'kl': _region[lang]!};
      final uri = Uri.https('html.duckduckgo.com', '/html/', params);
      final res = await _client
          .get(uri, headers: {..._headers, 'Accept-Language': '$lang,en;q=0.6'})
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return const [];
      final doc = html_parser.parse(WebFetcher.decode(res));
      final out = <String>[];
      for (final a in doc.querySelectorAll('a.result__a')) {
        final href = a.attributes['href'] ?? '';
        final real = _unwrapDdg(href);
        if (real != null && !real.contains('duckduckgo.com')) out.add(real);
        if (out.length >= 10) break;
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  static String? _unwrapDdg(String href) {
    var h = href;
    if (h.startsWith('//')) h = 'https:$h';
    final u = Uri.tryParse(h);
    if (u == null) return null;
    final inner = u.queryParameters['uddg'];
    if (inner != null && inner.startsWith('http')) return inner;
    return h.startsWith('http') ? h : null;
  }

  Future<List<String>> _homepageLegalLinks(String domain) async {
    try {
      final uri = Uri.https(domain, '/');
      final res = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 10));
      if (res.statusCode >= 400) return const [];
      final doc = html_parser.parse(WebFetcher.decode(res));
      final base = _registrable(domain);
      final out = <String>[];
      for (final a in doc.querySelectorAll('a[href]')) {
        final text = a.text.trim();
        final href = a.attributes['href'] ?? '';
        if (!_legalWord.hasMatch(text) && !_legalWord.hasMatch(href)) continue;
        final resolved = uri.resolve(href);
        if (!resolved.scheme.startsWith('http')) continue;
        if (_registrable(resolved.host) != base) continue;
        out.add(resolved.toString());
        if (out.length >= 8) break;
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  Future<TermsCandidate?> _inspect(String url, String base) async {
    try {
      final uri = Uri.parse(url);
      final res = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 12));
      if (res.statusCode >= 400) return null;
      // Where we actually landed after redirects (http >= 1.2 exposes it).
      final Object r = res;
      final finalUri = r is http.BaseResponseWithUrl ? r.url : uri;
      if (_registrable(finalUri.host) != base) return null;
      final doc = html_parser.parse(WebFetcher.decode(res));
      final meta = PageMeta.fromDocument(doc, finalUri);
      final text = WebFetcher.extractText(doc);
      final words = text.split(RegExp(r'\s+')).length;
      final kind = PageMeta.kindOf(meta.pageTitle, finalUri.path);

      var score = 0;
      final lower = text.toLowerCase();
      for (final w in const [
        'agreement', 'governing law', 'arbitration', 'liability', 'warrant', 'terminate', 'termination',
        'you agree', 'these terms', 'indemn', 'personal information', 'subscription', 'dispute',
      ]) {
        if (lower.contains(w)) score += 1;
      }
      final path = finalUri.path.toLowerCase();
      if (RegExp(r'terms|tos|legal|agreement|conditions').hasMatch(path)) score += 4;
      if (path.contains('privacy')) score += 2;
      if (kind != 'Legal page') score += 2;
      final scriptBuilt = words < 150;
      if (scriptBuilt) score -= 3;
      if (path == '/' || path.isEmpty) score -= 6; // homepages aren't terms

      return TermsCandidate(
        url: finalUri.toString(),
        host: finalUri.host,
        siteName: meta.siteName,
        kind: kind,
        themeColor: meta.themeColor,
        updated: PageMeta.findUpdatedDate(text),
        score: score,
        scriptBuilt: scriptBuilt,
      );
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------

  static String? _domainFromQuery(String q) {
    if (q.contains(' ') || !q.contains('.')) return null;
    try {
      return WebFetcher.normalize(q).host.toLowerCase();
    } catch (_) {
      return null;
    }
  }

  /// Most likely official domain among search results: one whose name
  /// contains the query's letters, else the first result.
  static String _pickDomain(String q, List<String> urls) {
    final token = q.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    for (final u in urls) {
      final h = Uri.tryParse(u)?.host.toLowerCase() ?? '';
      if (token.isNotEmpty && _registrable(h).replaceAll(RegExp(r'[^a-z0-9]'), '').contains(token)) {
        return h;
      }
    }
    return Uri.tryParse(urls.first)?.host.toLowerCase() ?? '$token.com';
  }

  /// "help.netflix.com" -> "netflix.com", "www.bbc.co.uk" -> "bbc.co.uk".
  static String _registrable(String host) {
    final parts = host.toLowerCase().split('.').where((p) => p.isNotEmpty).toList();
    if (parts.length <= 2) return parts.join('.');
    const sld = {'co', 'com', 'org', 'net', 'gov', 'ac', 'edu'};
    final n = sld.contains(parts[parts.length - 2]) && parts.last.length == 2 ? 3 : 2;
    return parts.sublist(parts.length - n).join('.');
  }

  static String? _norm(String u) {
    final uri = Uri.tryParse(u);
    if (uri == null || uri.host.isEmpty) return null;
    var p = uri.path;
    if (p.endsWith('/') && p.length > 1) p = p.substring(0, p.length - 1);
    return '${uri.host.replaceFirst('www.', '')}$p'.toLowerCase();
  }
}
