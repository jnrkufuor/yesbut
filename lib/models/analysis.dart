// Core data model for a contract analysis.
//
// Everything here is plain Dart + JSON so the same model can be produced by
// the on-device rule engine, by an AI provider, or by a future backend.

enum Severity { redFlag, headsUp, goodNews }

extension SeverityX on Severity {
  String get label => switch (this) {
        Severity.redFlag => 'Red flag',
        Severity.headsUp => 'Heads up',
        Severity.goodNews => 'Good news',
      };

  String get key => switch (this) {
        Severity.redFlag => 'red_flag',
        Severity.headsUp => 'heads_up',
        Severity.goodNews => 'good_news',
      };

  static Severity parse(String? raw) {
    final v = (raw ?? '').toLowerCase().replaceAll(RegExp(r'[\s\-]'), '_');
    if (v.contains('red') || v == 'high' || v == 'danger') {
      return Severity.redFlag;
    }
    if (v.contains('good') || v == 'positive' || v == 'low') {
      return Severity.goodNews;
    }
    return Severity.headsUp;
  }
}

class Finding {
  final String title;
  final String plain; // the "dumbed down" explanation
  final String? quote; // excerpt of the original text
  final Severity severity;
  final String category;

  const Finding({
    required this.title,
    required this.plain,
    required this.severity,
    required this.category,
    this.quote,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'plain': plain,
        'quote': quote,
        'severity': severity.key,
        'category': category,
      };

  factory Finding.fromJson(Map<String, dynamic> j) => Finding(
        title: (j['title'] ?? '').toString(),
        plain: (j['plain'] ?? j['explanation'] ?? '').toString(),
        quote: j['quote']?.toString(),
        severity: SeverityX.parse(j['severity']?.toString()),
        category: (j['category'] ?? 'General').toString(),
      );
}

class JargonTerm {
  final String term;
  final String meaning;
  const JargonTerm(this.term, this.meaning);

  Map<String, dynamic> toJson() => {'term': term, 'meaning': meaning};
  factory JargonTerm.fromJson(Map<String, dynamic> j) =>
      JargonTerm((j['term'] ?? '').toString(), (j['meaning'] ?? '').toString());
}

class KeyFact {
  final String label; // e.g. "Cancel"
  final String value; // e.g. "Anytime, effective end of billing period"
  const KeyFact(this.label, this.value);

  Map<String, dynamic> toJson() => {'label': label, 'value': value};
  factory KeyFact.fromJson(Map<String, dynamic> j) =>
      KeyFact((j['label'] ?? '').toString(), (j['value'] ?? '').toString());
}

/// One "what matters for this kind of deal" check.
class FocusItem {
  final String label;
  final String why;
  final bool found;
  final String? excerpt;
  const FocusItem({required this.label, required this.why, required this.found, this.excerpt});

  Map<String, dynamic> toJson() => {'label': label, 'why': why, 'found': found, 'excerpt': excerpt};
  factory FocusItem.fromJson(Map<String, dynamic> j) => FocusItem(
        label: (j['label'] ?? '').toString(),
        why: (j['why'] ?? '').toString(),
        found: j['found'] == true,
        excerpt: j['excerpt']?.toString(),
      );
}

enum SourceKind { paste, link, scan, file, library }

extension SourceKindX on SourceKind {
  String get label => switch (this) {
        SourceKind.paste => 'Pasted text',
        SourceKind.link => 'Web link',
        SourceKind.scan => 'Scanned',
        SourceKind.file => 'File',
        SourceKind.library => 'Library',
      };
}

class AnalysisResult {
  final String id;
  final String title;
  final SourceKind sourceKind;
  final String? sourceRef; // URL or filename
  final DateTime analyzedAt;
  final String engine; // "Offline" or "AI · <model>"
  final int score; // 0–100, higher = fairer to you
  final List<String> tldr;
  final List<Finding> findings;
  final List<JargonTerm> jargon;
  final List<KeyFact> keyFacts;
  final List<String> questions; // questions to ask before signing
  final int wordCount;
  final String text; // original text (trimmed for storage)
  final String? note; // e.g. "AI unavailable, used offline engine"
  final String dealType; // "shopping", "rideshare"…
  final String industry; // "beauty", "gaming"…
  final String? audience; // who the terms speak to
  final String? otherParty; // the other side also mentioned
  final String? summary; // one-line "what this is"
  final String language; // detected document language code
  final List<FocusItem> focus;

  const AnalysisResult({
    required this.id,
    required this.title,
    required this.sourceKind,
    required this.analyzedAt,
    required this.engine,
    required this.score,
    required this.tldr,
    required this.findings,
    required this.jargon,
    required this.keyFacts,
    required this.questions,
    required this.wordCount,
    required this.text,
    this.sourceRef,
    this.note,
    this.dealType = 'general',
    this.industry = 'general',
    this.audience,
    this.otherParty,
    this.summary,
    this.language = 'en',
    this.focus = const [],
  });

  int get readMinutes => (wordCount / 238).ceil().clamp(1, 9999).toInt();

  List<Finding> bySeverity(Severity s) =>
      findings.where((f) => f.severity == s).toList();

  int count(Severity s) => findings.where((f) => f.severity == s).length;

  String get verdict {
    if (score >= 75) return 'Pretty fair';
    if (score >= 50) return 'Read carefully';
    if (score >= 30) return 'Lots of gotchas';
    return 'Yikes';
  }

  AnalysisResult copyWith({
    String? title,
    String? note,
    String? dealType,
    String? industry,
    String? audience,
    String? otherParty,
    String? summary,
    String? language,
    List<FocusItem>? focus,
    List<String>? tldr,
    List<Finding>? findings,
    List<KeyFact>? keyFacts,
    List<String>? questions,
    String? text,
  }) =>
      AnalysisResult(
        id: id,
        title: title ?? this.title,
        sourceKind: sourceKind,
        sourceRef: sourceRef,
        analyzedAt: analyzedAt,
        engine: engine,
        score: score,
        tldr: tldr ?? this.tldr,
        findings: findings ?? this.findings,
        jargon: jargon,
        keyFacts: keyFacts ?? this.keyFacts,
        questions: questions ?? this.questions,
        wordCount: wordCount,
        text: text ?? this.text,
        note: note ?? this.note,
        dealType: dealType ?? this.dealType,
        industry: industry ?? this.industry,
        audience: audience ?? this.audience,
        otherParty: otherParty ?? this.otherParty,
        summary: summary ?? this.summary,
        language: language ?? this.language,
        focus: focus ?? this.focus,
      );

  String toShareText() {
    final b = StringBuffer()
      ..writeln('YesBut check: $title')
      ..writeln('Fairness score: $score/100 · $verdict')
      ..writeln();
    if (tldr.isNotEmpty) {
      b.writeln('TL;DR');
      for (final t in tldr) {
        b.writeln('• $t');
      }
      b.writeln();
    }
    for (final s in Severity.values) {
      final list = bySeverity(s);
      if (list.isEmpty) continue;
      b.writeln('${s.label.toUpperCase()} (${list.length})');
      for (final f in list) {
        b.writeln('• ${f.title} — ${f.plain}');
      }
      b.writeln();
    }
    b.writeln('Not legal advice. Checked with YesBut.');
    return b.toString();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'sourceKind': sourceKind.name,
        'sourceRef': sourceRef,
        'analyzedAt': analyzedAt.toIso8601String(),
        'engine': engine,
        'score': score,
        'tldr': tldr,
        'findings': findings.map((f) => f.toJson()).toList(),
        'jargon': jargon.map((j) => j.toJson()).toList(),
        'keyFacts': keyFacts.map((k) => k.toJson()).toList(),
        'questions': questions,
        'wordCount': wordCount,
        'text': text,
        'note': note,
        'dealType': dealType,
        'industry': industry,
        'audience': audience,
        'otherParty': otherParty,
        'summary': summary,
        'language': language,
        'focus': focus.map((f) => f.toJson()).toList(),
      };

  factory AnalysisResult.fromJson(Map<String, dynamic> j) {
    List<T> list<T>(String k, T Function(Map<String, dynamic>) f) =>
        ((j[k] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => f(Map<String, dynamic>.from(e)))
            .toList();
    List<String> strings(String k) =>
        ((j[k] as List?) ?? const []).map((e) => e.toString()).toList();

    return AnalysisResult(
      id: (j['id'] ?? '').toString(),
      title: (j['title'] ?? 'Untitled').toString(),
      sourceKind: SourceKind.values.firstWhere(
        (s) => s.name == j['sourceKind'],
        orElse: () => SourceKind.paste,
      ),
      sourceRef: j['sourceRef']?.toString(),
      analyzedAt:
          DateTime.tryParse((j['analyzedAt'] ?? '').toString()) ?? DateTime.now(),
      engine: (j['engine'] ?? 'Offline').toString(),
      score: (j['score'] is num) ? (j['score'] as num).round() : 50,
      tldr: strings('tldr'),
      findings: list('findings', Finding.fromJson),
      jargon: list('jargon', JargonTerm.fromJson),
      keyFacts: list('keyFacts', KeyFact.fromJson),
      questions: strings('questions'),
      wordCount: (j['wordCount'] is num) ? (j['wordCount'] as num).round() : 0,
      text: (j['text'] ?? '').toString(),
      note: j['note']?.toString(),
      dealType: (j['dealType'] ?? 'general').toString(),
      industry: (j['industry'] ?? 'general').toString(),
      audience: j['audience']?.toString(),
      otherParty: j['otherParty']?.toString(),
      summary: j['summary']?.toString(),
      language: (j['language'] ?? 'en').toString(),
      focus: list('focus', FocusItem.fromJson),
    );
  }
}

/// What the user handed us, before analysis.
class ContractInput {
  final String text;
  final String title;
  final SourceKind kind;
  final String? ref;
  /// "Last updated" date found on the page itself, if any.
  final DateTime? pageDate;
  /// What kind of deal this is ("shopping", "rideshare"…); tunes the criteria.
  final String dealType;
  final String industry;
  /// Marked sensitive by the user: read on the phone only, text not kept.
  final bool sensitive;
  const ContractInput({
    required this.text,
    required this.title,
    required this.kind,
    this.ref,
    this.pageDate,
    this.dealType = 'general',
    this.industry = 'general',
    this.sensitive = false,
  });

  ContractInput copyWith({String? text, String? dealType, String? industry}) => ContractInput(
        text: text ?? this.text,
        title: title,
        kind: kind,
        ref: ref,
        pageDate: pageDate,
        dealType: dealType ?? this.dealType,
        industry: industry ?? this.industry,
        sensitive: sensitive,
      );
}
