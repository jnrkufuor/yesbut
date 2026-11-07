import 'dart:convert';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

class FetchedPage {
  final String title;
  final String text;
  final String url;
  const FetchedPage(this.title, this.text, this.url);
}

class FetchException implements Exception {
  final String message;
  FetchException(this.message);
  @override
  String toString() => message;
}

/// Downloads a terms page and turns its HTML into clean readable text.
class WebFetcher {
  WebFetcher({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  static const _blockTags = {
    'p', 'div', 'section', 'article', 'li', 'ul', 'ol', 'h1', 'h2', 'h3',
    'h4', 'h5', 'h6', 'tr', 'table', 'br', 'blockquote', 'dd', 'dt', 'pre',
  };
  static const _dropTags = [
    'script', 'style', 'noscript', 'svg', 'nav', 'header', 'footer', 'form',
    'iframe', 'button', 'template', 'aside',
  ];

  static Uri normalize(String input) {
    var s = input.trim();
    if (!s.startsWith(RegExp(r'https?://', caseSensitive: false))) {
      s = 'https://$s';
    }
    final uri = Uri.tryParse(s);
    if (uri == null || uri.host.isEmpty || !uri.host.contains('.')) {
      throw FetchException('That doesn\'t look like a web address.');
    }
    return uri;
  }

  Future<FetchedPage> fetch(String url) async {
    final uri = normalize(url);
    http.Response res;
    try {
      res = await _client.get(uri, headers: {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,text/plain;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
      }).timeout(const Duration(seconds: 25));
    } catch (_) {
      throw FetchException(
          'Couldn\'t reach that page. Check your connection or the link.');
    }
    if (res.statusCode >= 400) {
      throw FetchException(
          'The site said no (error ${res.statusCode}). Try opening it in your browser and pasting the text instead.');
    }

    final body = _decode(res);
    final type = res.headers['content-type'] ?? '';
    if (type.contains('text/plain')) {
      return FetchedPage(uri.host, body, uri.toString());
    }

    final doc = html_parser.parse(body);
    final title = (doc.querySelector('title')?.text ?? '').trim();
    for (final tag in _dropTags) {
      for (final el in doc.querySelectorAll(tag)) {
        el.remove();
      }
    }
    final root = doc.querySelector('main') ??
        doc.querySelector('article') ??
        doc.querySelector('[role=main]') ??
        doc.body;
    final buf = StringBuffer();
    if (root != null) _walk(root, buf);
    final text = buf
        .toString()
        .replaceAll(RegExp(r'[ \t ]+'), ' ')
        .replaceAll(RegExp(r' *\n *'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    if (text.split(RegExp(r'\s+')).length < 150) {
      throw FetchException(
          'This page loads its text with scripts, so we couldn\'t read it directly. Open it in your browser, select all, copy, and use "Paste text".');
    }
    return FetchedPage(
      title.isEmpty ? uri.host : title,
      text,
      uri.toString(),
    );
  }

  static String _decode(http.Response res) {
    try {
      return utf8.decode(res.bodyBytes);
    } catch (_) {
      return latin1.decode(res.bodyBytes);
    }
  }

  static void _walk(dom.Node node, StringBuffer out) {
    if (node is dom.Text) {
      out.write(node.text);
      return;
    }
    if (node is! dom.Element) return;
    final tag = node.localName ?? '';
    final block = _blockTags.contains(tag);
    if (block) out.write('\n');
    if (tag == 'li') out.write('• ');
    for (final child in node.nodes) {
      _walk(child, out);
    }
    if (block) out.write('\n');
  }
}
