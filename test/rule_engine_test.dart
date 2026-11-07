import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yesbut/models/analysis.dart';
import 'package:yesbut/services/analysis/rule_based_analyzer.dart';

void main() {
  final engine = RuleBasedAnalyzer.fromJsonString(
      File('assets/rules.json').readAsStringSync());

  test('spots the classic subscription gotchas', () async {
    final text = File('test/fixtures_sample.txt').readAsStringSync();
    final r = await engine.analyze(
        ContractInput(text: text, title: 'Sample', kind: SourceKind.paste));
    final titles = r.findings.map((f) => f.title).toSet();

    expect(titles, contains('It renews on its own'));
    expect(titles, contains('No refunds'));
    expect(titles, contains('You can\'t take them to court'));
    expect(titles, contains('No joining a class action'));
    expect(titles, contains('They can use your stuff'));
    expect(titles, contains('Your data gets shared'));
    expect(titles, contains('You can opt out of arbitration'));
    expect(r.count(Severity.redFlag), greaterThan(5));
    expect(r.score, lessThan(40));
    expect(r.findings.first.severity, Severity.redFlag);
    expect(r.jargon.map((j) => j.term), contains('Indemnify'));
  });

  test('round-trips through JSON', () async {
    final r = await engine.analyze(const ContractInput(
        text: 'You may cancel at any time. We offer a full refund within 14 days.',
        title: 'Nice',
        kind: SourceKind.paste));
    final back = AnalysisResult.fromJson(r.toJson());
    expect(back.findings.length, r.findings.length);
    expect(back.score, r.score);
    expect(back.count(Severity.goodNews), greaterThan(0));
  });
}
