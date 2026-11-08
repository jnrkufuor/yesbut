import 'package:html/dom.dart' as dom;

/// Facts we can read off a web page besides its text: a friendly site name,
/// the page title, the brand color it declares, and when it says it was
/// last updated.
class PageMeta {
  final String siteName;
  final String pageTitle;
  final String? themeColor; // "#RRGGBB"
  const PageMeta({required this.siteName, required this.pageTitle, this.themeColor});

  static PageMeta fromDocument(dom.Document doc, Uri uri) {
    String? meta(String attr, String name) {
      for (final el in doc.querySelectorAll('meta[$attr]')) {
        if ((el.attributes[attr] ?? '').toLowerCase() == name) {
          final c = (el.attributes['content'] ?? '').trim();
          if (c.isNotEmpty) return c;
        }
      }
      return null;
    }

    final rawTitle = (doc.querySelector('title')?.text ?? '').trim();
    final site = meta('property', 'og:site_name') ??
        meta('name', 'application-name') ??
        meta('name', 'apple-mobile-web-app-title') ??
        siteFromHost(uri.host);
    return PageMeta(
      siteName: _tidySite(site, uri.host),
      pageTitle: rawTitle,
      themeColor: _hex(meta('name', 'theme-color') ?? meta('name', 'msapplication-tilecolor')),
    );
  }

  /// "help.netflix.com" -> "Netflix", "www.bbc.co.uk" -> "Bbc".
  static String siteFromHost(String host) {
    final parts = host.toLowerCase().split('.').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return host;
    const sld = {'co', 'com', 'org', 'net', 'gov', 'ac', 'edu'};
    var i = parts.length - 2;
    if (i > 0 && sld.contains(parts[i]) && parts.last.length == 2) i -= 1;
    final name = parts[i.clamp(0, parts.length - 1)];
    return name.isEmpty ? host : name[0].toUpperCase() + name.substring(1);
  }

  static String _tidySite(String s, String host) {
    var t = s.split(RegExp(r'\s[|\-–—:]\s')).first.trim();
    if (t.length > 32 || t.isEmpty) t = siteFromHost(host);
    return t;
  }

  static String? _hex(String? c) {
    if (c == null) return null;
    final m = RegExp(r'#([0-9a-fA-F]{6}|[0-9a-fA-F]{3})\b').firstMatch(c);
    if (m == null) return null;
    var h = m.group(1)!;
    if (h.length == 3) h = h.split('').map((x) => '$x$x').join();
    final lower = h.toLowerCase();
    // White / near-white theme colors aren't a brand color.
    if (lower == 'ffffff' || lower == 'fefefe' || lower == 'fafafa') return null;
    return '#${h.toUpperCase()}';
  }

  /// A short label for what kind of legal page this is.
  static String kindOf(String title, String path) {
    final s = '${title.toLowerCase()} ${path.toLowerCase()}';
    if (s.contains('privacy')) return 'Privacy Policy';
    if (s.contains('cookie')) return 'Cookie Policy';
    if (s.contains('subscriber')) return 'Subscriber Agreement';
    if (s.contains('end-user') || s.contains('end user') || s.contains('eula')) return 'User Agreement';
    if (s.contains('terms of use') || s.contains('termsofuse') || s.contains('terms-of-use')) return 'Terms of Use';
    if (s.contains('terms of service') || s.contains('terms-of-service') || s.contains('/tos')) return 'Terms of Service';
    if (s.contains('conditions')) return 'Terms & Conditions';
    if (s.contains('terms')) return 'Terms';
    if (s.contains('agreement')) return 'Agreement';
    if (s.contains('refund')) return 'Refund Policy';
    return 'Legal page';
  }

  static const _months = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
    'jul': 7, 'aug': 8, 'sep': 9, 'sept': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };

  /// Finds a "Last updated / Effective" date near the top of the text.
  static DateTime? findUpdatedDate(String text) {
    final head = text.length > 8000 ? text.substring(0, 8000) : text;
    const cue = r'(?:last\s+(?:updated|modified|revised|changed)|updated(?:\s+on)?|effective(?:\s+(?:date|as\s+of|from|on))?|revised(?:\s+on)?|version\s+date|date\s+of\s+last\s+revision)';
    const mon = r'(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|june?|july?|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)\.?';
    final patterns = <RegExp>[
      RegExp('$cue[^\\n\\d]{0,24}$mon\\s+(\\d{1,2})(?:st|nd|rd|th)?,?\\s+(\\d{4})', caseSensitive: false),
      RegExp('$cue[^\\n\\d]{0,24}(\\d{1,2})(?:st|nd|rd|th)?\\s+$mon,?\\s+(\\d{4})', caseSensitive: false),
      RegExp('$cue[^\\n\\d]{0,24}(\\d{4})-(\\d{1,2})-(\\d{1,2})', caseSensitive: false),
      RegExp('$cue[^\\n\\d]{0,24}(\\d{1,2})[/.](\\d{1,2})[/.](\\d{4})', caseSensitive: false),
      RegExp('$cue[^\\n\\d]{0,24}$mon,?\\s+(\\d{4})', caseSensitive: false),
    ];
    for (var p = 0; p < patterns.length; p++) {
      final m = patterns[p].firstMatch(head);
      if (m == null) continue;
      DateTime? d;
      try {
        switch (p) {
          case 0:
            d = DateTime(int.parse(m.group(3)!), _mon(m.group(1)!), int.parse(m.group(2)!));
          case 1:
            d = DateTime(int.parse(m.group(3)!), _mon(m.group(2)!), int.parse(m.group(1)!));
          case 2:
            d = DateTime(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
          case 3:
            // Ambiguous; assume US month/day unless the first number can't be a month.
            final a = int.parse(m.group(1)!), b = int.parse(m.group(2)!);
            d = a > 12 ? DateTime(int.parse(m.group(3)!), b, a) : DateTime(int.parse(m.group(3)!), a, b);
          case 4:
            d = DateTime(int.parse(m.group(2)!), _mon(m.group(1)!), 1);
        }
      } catch (_) {
        d = null;
      }
      if (d != null && d.year >= 1995 && d.isBefore(DateTime.now().add(const Duration(days: 400)))) {
        return d;
      }
    }
    return null;
  }

  static int _mon(String s) {
    final k = s.toLowerCase().replaceAll('.', '');
    return _months[k.length >= 4 && k.startsWith('sept') ? 'sept' : k.substring(0, 3)] ?? 1;
  }

  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  static String formatMonth(DateTime d) => '${_monthNames[d.month - 1]} ${d.year}';

  /// Older than ~14 months is worth flagging.
  static bool isStale(DateTime d) => DateTime.now().difference(d).inDays > 425;
}
