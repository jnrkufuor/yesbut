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

  AnalysisResult copyWith({String? title, String? note}) => AnalysisResult(
        id: id,
        title: title ?? this.title,
        sourceKind: sourceKind,
        sourceRef: sourceRef,
        analyzedAt: analyzedAt,
        engine: engine,
        score: score,
        tldr: tldr,
        findings: findings,
        jargon: jargon,
        keyFacts: keyFacts,
        questions: questions,
        wordCount: wordCount,
        text: text,
        note: note ?? this.note,
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
  const ContractInput({
    required this.text,
    required this.title,
    required this.kind,
    this.ref,
    this.pageDate,
  });
}
